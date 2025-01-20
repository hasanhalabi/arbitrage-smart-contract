// SPDX-License-Identifier: MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import "@uniswap/v3-core/contracts/interfaces/callback/IUniswapV3FlashCallback.sol";
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/libraries/LowGasSafeMath.sol";

import "@uniswap/v3-periphery/contracts/interfaces/IPeripheryPayments.sol";
import "@uniswap/v3-periphery/contracts/base/PeripheryPayments.sol";
import "@uniswap/v3-periphery/contracts/base/PeripheryImmutableState.sol";
import "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import "@uniswap/v3-periphery/contracts/libraries/CallbackValidation.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

/**
 * @title FlashLoanArbUSDCWETH
 * @notice 
 *   - Borrows USDC from a USDC-WETH Uniswap V3 pool via flash loan
 *   - Buys/sells a different token (`tradeToken`) for potential arbitrage
 *   - Reverts if final USDC < principal + flash fee
 *   - Includes events with a `uint48 tradeId` to track each trade
 */
contract FlashLoanArbUSDCWETH is 
    IUniswapV3FlashCallback,
    PeripheryImmutableState,
    PeripheryPayments
{
    using LowGasSafeMath for uint256;

    /// @notice Owner of this contract
    address public immutable owner;

    /// @notice USDC token address
    address public immutable usdcAddress;
    address public immutable weth9Address;

    /// @notice IERC20 interface for USDC
    IERC20 public immutable usdcToken;

    // -------------------------------------------------------------------------
    //                              Events
    // -------------------------------------------------------------------------

    event UsdcDeposited(address indexed owner, uint256 amount);
    event UsdcWithdrawn(address indexed owner, uint256 amount);

    /// @notice Emitted when a flash loan trade is initiated
    event TradeInitiated(
        uint48 tradeId,
        address indexed owner,
        address indexed tradeToken,
        uint256 flashAmountUsdc,
        uint256 deadlineDelay
    );

    /// @notice Emitted when we receive the flash loan
    event FlashBorrowed(
        uint48 tradeId,
        address pool,
        uint256 amountBorrowed,
        uint256 fee0,
        uint256 fee1
    );

    /// @notice Emitted after a successful buy step
    event BuySucceeded(uint48 tradeId, uint256 tradeTokenAmount);

    /// @notice Emitted if the buy fails
    event BuyFailed(uint48 tradeId, string reason);

    /// @notice Emitted after a successful sell step
    event SellSucceeded(uint48 tradeId, uint256 finalUsdc);

    /// @notice Emitted if the sell fails
    event SellFailed(uint48 tradeId, string reason);

    /// @notice Emitted after a profitable trade completes
    event TradeCompleted(uint48 tradeId, uint256 finalUsdc, uint256 amountOwed);

    /// @notice Emitted if the trade is not profitable
    event TradeRevertedDueToLoss(uint48 tradeId, uint256 finalUsdc, uint256 amountOwed);

    /**
     * @param _usdc   Address of the USDC token
     * @param _factory Uniswap V3 factory
     * @param _WETH9  WETH9 contract
     */
    constructor(
        address _usdc,
        address _factory,
        address _WETH9
    )
        PeripheryImmutableState(_factory, _WETH9)
    {
        owner = msg.sender;
        usdcAddress = _usdc;
        weth9Address = _WETH9;
        usdcToken = IERC20(_usdc);
    }

    // -------------------------------------------------------------------------
    //                      BASIC USDC DEPOSIT / WITHDRAW
    // -------------------------------------------------------------------------

    /**
     * @notice Deposit USDC into this contract
     * @param amount Amount of USDC to deposit
     */
    function depositUSDC(uint256 amount) external {
        require(msg.sender == owner, "Only owner can deposit");
        require(amount > 0, "Amount must be > 0");

        pay(usdcAddress, msg.sender, address(this), amount);
        emit UsdcDeposited(msg.sender, amount);
    }

    /**
     * @notice Withdraw USDC from this contract
     * @param amount Amount of USDC to withdraw
     */
    function withdrawUSDC(uint256 amount) external {
        require(msg.sender == owner, "Only owner can withdraw");
        require(amount > 0, "Withdraw must be > 0");

        TransferHelper.safeApprove(usdcAddress, msg.sender, amount);
        pay(usdcAddress, address(this), msg.sender, amount);
        emit UsdcWithdrawn(msg.sender, amount);
    }

    /**
     * @notice Check how many USDC tokens are held by this contract
     * @return The current USDC balance
     */
    function contractUsdcBalance() external view returns (uint256) {
        return usdcToken.balanceOf(address(this));
    }

    // -------------------------------------------------------------------------
    //                      FLASH LOAN + ARB LOGIC
    // -------------------------------------------------------------------------

    /**
     * @dev Input parameters for the arbitrage.
     * @param tradeId Off-chain numeric ID for tracking the trade.
     *                  Formated as nnnYYYYMMDDxxxx
     *                  Where
     *                  nnn     is the backend node that is calling the smart contract values from 100 - 280
     *                  YYYY    the year
     *                  MM      the month
     *                  DD      the day
     *                  xxxx    minute in the day when this as example the time 00:00 will be 0000, the time 08:23 will be 0503, the time 16:57 will be 1017, the time 23:59 will be 1439
     */
    struct TradeParams {
        uint48 tradeId;
        address tradeToken;
        ISwapRouter dexBuy;
        ISwapRouter dexSell;
        uint256 flashAmountUsdc;
        uint256 minTradeTokenOut;
        uint24  feeFlashPool;
        uint24  feeBuyPool;
        uint24  feeSellPool;
        uint160 sqrtLimitBuy;
        uint160 sqrtLimitSell;
        uint256 deadlineDelay;
    }

    struct FlashCallbackData {
        uint48 tradeId;
        address borrowedToken;
        uint256 borrowedAmount;
        address tradeToken;
        ISwapRouter dexBuy;
        ISwapRouter dexSell;
        uint256 minTradeTokenOut;
        uint24 feeBuy;
        uint24 feeSell;
        uint160 sqrtLimitBuy;
        uint160 sqrtLimitSell;
        address poolToken0;
        address poolToken1;
        uint256 deadlineDelay;
    }

    /**
     * @notice Initiates a flash loan of USDC from the USDC-WETH pool,
     *         then encodes trade data for the callback.
     * @param params The parameters needed for the flash + trades
     */
    function initTrade(TradeParams calldata params) public {
        require(msg.sender == owner, "Only owner can init trade");

        // --- Step 1: Unpack struct into local variables to avoid stack-too-deep ---
        // uint48 _tradeId = params.tradeId;
        // address _tradeToken = params.tradeToken;
        // ISwapRouter _dexBuy = params.dexBuy;
        // ISwapRouter _dexSell = params.dexSell;
        // uint256 _flashAmountUsdc = params.flashAmountUsdc;
        // uint256 _minTradeTokenOut = params.minTradeTokenOut;
        // uint24  _feeFlashPool = params.feeFlashPool;
        // uint24  _feeBuyPool = params.feeBuyPool;
        // uint24  _feeSellPool = params.feeSellPool;
        // uint160 _sqrtPriceLimitX96Buy = params.sqrtLimitBuy;
        // uint160 _sqrtPriceLimitX96Sell = params.sqrtLimitSell;
        // uint256 _deadlineDelay = params.deadlineDelay;

        // --- Step 2: Basic Checks (no mention of tradeId in revert messages) ---
        require(params.tradeId != 0, "tradeId cannot be zero");
        require(params.tradeToken != usdcAddress, "tradeToken cannot be USDC");
        require(params.tradeToken != address(0), "tradeToken cannot be zero");
        require(params.flashAmountUsdc > 0, "flashAmount must be > 0");

        // --- Step 3: Sort out token0 vs token1 for USDC-WETH
        (address t0, address t1) = (usdcAddress < weth9Address)
            ? (usdcAddress, weth9Address)
            : (weth9Address, usdcAddress);

        // Build pool key
        PoolAddress.PoolKey memory poolKey = PoolAddress.PoolKey({
            token0: t0,
            token1: t1,
            fee: params.feeFlashPool
        });

        address poolAddress_ = PoolAddress.computeAddress(factory, poolKey);

        // Check if the pool code exists
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(poolAddress_)
        }
        require(codeSize > 0, "Pool contract not found");

        IUniswapV3Pool pool = IUniswapV3Pool(poolAddress_);

        // Decide which side is USDC
        uint256 amount0;
        uint256 amount1;
        address borrowedToken;

        if (t0 == usdcAddress) {
            amount0 = params.flashAmountUsdc;
            borrowedToken = t0;
        } else {
            amount1 = params.flashAmountUsdc;
            borrowedToken = t1;
        }

        // Prepare callback data
        FlashCallbackData memory callbackData = FlashCallbackData({
            tradeId: params.tradeId,
            borrowedToken: borrowedToken,
            borrowedAmount: params.flashAmountUsdc,
            tradeToken: params.tradeToken,
            dexBuy: params.dexBuy,
            dexSell: params.dexSell,
            minTradeTokenOut: params.minTradeTokenOut,
            feeBuy: params.feeBuyPool,
            feeSell: params.feeSellPool,
            sqrtLimitBuy: params.sqrtLimitBuy,
            sqrtLimitSell: params.sqrtLimitSell,
            poolToken0: t0,
            poolToken1: t1,
            deadlineDelay: params.deadlineDelay
        });

        // Emit event (includes the tradeId)
        emit TradeInitiated(
            params.tradeId,
            msg.sender,
            params.tradeToken,
            params.flashAmountUsdc,
            params.deadlineDelay
        );

        // Execute the flash
        pool.flash(address(this), amount0, amount1, abi.encode(callbackData));
    }

    /**
     * @notice Callback from Uniswap V3 after it flashes us USDC.
     */
    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external override {
        FlashCallbackData memory decoded = abi.decode(data, (FlashCallbackData));

        // Validate the pool
        PoolAddress.PoolKey memory poolKey = PoolAddress.PoolKey({
            token0: decoded.poolToken0,
            token1: decoded.poolToken1,
            fee: IUniswapV3Pool(msg.sender).fee()
        });
        CallbackValidation.verifyCallback(factory, poolKey);

        emit FlashBorrowed(
            decoded.tradeId,
            msg.sender,
            decoded.borrowedAmount,
            fee0,
            fee1
        );

        // Identify which fee applies to borrowed USDC
        uint256 flashFee = (decoded.borrowedToken == decoded.poolToken0) ? fee0 : fee1;

        // Approve dexBuy to spend borrowed USDC
        TransferHelper.safeApprove(decoded.borrowedToken, address(decoded.dexBuy), decoded.borrowedAmount);

        uint256 tradeDeadline = block.timestamp + decoded.deadlineDelay;
        uint256 tradeTokenAmount;

        // --- BUY STEP ---
        {
            ISwapRouter.ExactInputSingleParams memory buyParams = ISwapRouter.ExactInputSingleParams({
                tokenIn: decoded.borrowedToken,
                tokenOut: decoded.tradeToken,
                fee: decoded.feeBuy,
                recipient: address(this),
                deadline: tradeDeadline,
                amountIn: decoded.borrowedAmount,
                amountOutMinimum: decoded.minTradeTokenOut,
                sqrtPriceLimitX96: decoded.sqrtLimitBuy
            });

            try decoded.dexBuy.exactInputSingle(buyParams) returns (uint256 amountOut) {
                tradeTokenAmount = amountOut;
                emit BuySucceeded(decoded.tradeId, amountOut);
            } catch Error(string memory reason) {
                emit BuyFailed(decoded.tradeId, reason);
                revert("Buy step failed");
            } catch (bytes memory lowLevelData) {
                string memory errorMsg = string(lowLevelData);
                emit BuyFailed(decoded.tradeId, errorMsg);
                revert("Buy step failed (no reason)");
            }
        }

        // Approve dexSell to spend the tradeToken
        TransferHelper.safeApprove(decoded.tradeToken, address(decoded.dexSell), tradeTokenAmount);

        uint256 finalUsdc;

        // --- SELL STEP ---
        {
            ISwapRouter.ExactInputSingleParams memory sellParams = ISwapRouter.ExactInputSingleParams({
                tokenIn: decoded.tradeToken,
                tokenOut: decoded.borrowedToken,
                fee: decoded.feeSell,
                recipient: address(this),
                deadline: tradeDeadline,
                amountIn: tradeTokenAmount,
                amountOutMinimum: decoded.borrowedAmount,
                sqrtPriceLimitX96: decoded.sqrtLimitSell
            });

            try decoded.dexSell.exactInputSingle(sellParams) returns (uint256 amountOut2) {
                finalUsdc = amountOut2;
                emit SellSucceeded(decoded.tradeId, finalUsdc);
            } catch Error(string memory reason2) {
                emit SellFailed(decoded.tradeId, reason2);
                revert("Sell step failed");
            } catch (bytes memory lowLevelData2) {
                string memory errorMsg2 = string(lowLevelData2);
                emit SellFailed(decoded.tradeId, errorMsg2);
                revert("Sell step failed (no reason)");
            }
        }

        // total owed
        uint256 amountOwed = decoded.borrowedAmount.add(flashFee);

        // revert if unprofitable
        if (finalUsdc <= amountOwed) {
            emit TradeRevertedDueToLoss(decoded.tradeId, finalUsdc, amountOwed);
            revert("Unprofitable trade, revert");
        }

        // repay flash
        TransferHelper.safeApprove(decoded.borrowedToken, msg.sender, amountOwed);
        pay(decoded.borrowedToken, address(this), msg.sender, amountOwed);

        emit TradeCompleted(decoded.tradeId, finalUsdc, amountOwed);
    }
}