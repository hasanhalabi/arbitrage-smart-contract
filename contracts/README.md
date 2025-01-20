# Diving into My First Arbitrage Smart Contract Journey 🚀

Hey fellow developers! Grab a coffee, sit back, and let’s dive into the nitty-gritty of building an arbitrage smart contract. I’ll walk you through the trading logic I set out to implement, the hurdles I faced, and how I used ChatGPT (yes, that trusty AI) to help me along the way. This journey is filled with “aha!” moments, head-scratching mysteries, and a bit of humor. So, let’s get started!

## The Trading Logic: What Am I Building Here?

Before we get into the messy details, here’s the high-level overview of how my arbitrage bot will work:
### 1.	Opportunity Hunting:
A Node.js backend scans Uniswap V3-compatible DEXes (think Uniswap, Sushiswap, PancakeSwap AMM V3, WAGMI, Solidly V3, etc.) to spot arbitrage opportunities. The goal? To execute one arbitrage trade per minute or so.
### 2.	Liquidity Check:
When an opportunity arises, the backend looks for a USDC/WETH pool with enough liquidity—I’ve set a starting limit of 1,000 USDC. Why USDC/WETH? It’s simple: USDC is a stablecoin I relate to, and WETH is the gateway to endless possibilities!
### 3.	Calling the Smart Contract:
The backend triggers the smart contract to begin the arbitrage. I always use USDC as the base coin (e.g., USDC/DAI, USDC/WETH) because, well, I’m comfy with it.
### 4.	Smart Contract Parameters:
The smart contract takes a few parameters:
* Trading token (DAI, WETH, etc.)
* Amount of USDC to trade
* Loan pool fee
* The DEX to buy from
* The DEX to sell to
(And other parameters you can find detailed in the code comments.)
### 5.	Flash Loan & Trade Execution:
* The contract requests a flash loan for the given amount.
* It then uses the loan to buy the specified token from one DEX.
* Immediately after, it sells that token on another DEX.
### 6.	Profit Check:
If the returned USDC from the sale covers the loan and fee, the transaction is profitable, and the contract pays back the loan with interest. If not? The whole transaction reverts like a bad investment, and nothing gets committed to the blockchain.

Sound straightforward? Well, it’s easier said than done! Let me share the rollercoaster of building this beast.

## The Rollercoaster Journey: From Frustration to Enlightenment

### 1. Early Steps and Remix.io Woes

My first thought was to store some USDC tokens in the contract. This part went relatively smoothly. I was coding away on Remix Ethereum IDE, only to later realize that relying solely on Remix was a huge mistake.

### 2. The Flash Loan Head-Scratcher

After figuring out how to store tokens, I dove into flash loans. Uniswap V3 docs had a complete sample, which I eagerly copied. But bam! Compiler errors due to a Solidity version conflict:

```
pragma solidity =0.7.6;
pragma abicoder v2;
```

The Uniswap V3 sample was locked to Solidity v0.7.6, but it depended on OpenZeppelin libraries built for v0.8.0. My head hurt—how could a v0.7.6 library import v0.8.0 code? I spent two days wrestling with this conundrum.

### 3. Breaking Free from Remix: Building My Local Environment

The aha moment came when I realized Remix always pulls the latest library versions. No way to pin the version! So, I ditched Remix, built a local environment using Hardhat, and used Visual Studio Code as my editor. On my MacBook Air M1, setting up Hardhat was a breeze thanks to macOS’s Linux roots. Finally, I managed to import the correct versions of OpenZeppelin and Uniswap V3 libraries.

### 4. Demystifying Flash Loans and Liquidity Pools

Even after solving version issues, flash loans made me scratch my head:
* Question: Why specify two tokens and a fee for a 1,000 USDC loan?
* Answer: I’m not borrowing from a bank but from a liquidity pool of Token A/Token B with a fee. That’s how Uniswap works!

I learned pools are identified by `(Token A, Token B, Fee)`. But then came another puzzle: how to determine which token is token0 vs. token1? The docs say “smaller address goes first,” but Uniswap’s interface shows both USDC/WETH and WETH/USDC as valid pools. I adjusted the code accordingly, even if it felt like bending logic to the will of the Uniswap library.

### 5. Understanding Swaps (Buying and Selling Tokens)

Next, I tackled the buying and selling logic. I stumbled when searching for “buying” and “selling” in Uniswap V3, only to realize the term is “swapping” in blockchain lingo. Yup, you swap one token for another—like trading goods for cash, but in crypto.

Swaps come with confusing parameters like fees and sqrtPriceLimitX96. Even now, I’m still piecing some of that puzzle together.

### 6. Polishing the Code with ChatGPT

Once I finished coding the initial version, I asked ChatGPT to audit it. It found multiple errors and loopholes, suggesting fixes and validating parameters. We worked together to emit helpful events, so the Node.js backend can track smart contract actions.

## The Smart Contract Repository

I’ve just finished a solid version of the smart contract, complete with detailed comments explaining every line. 👉 Check out the latest version of the smart contract here.

Feel free to review the code, critique it, or drop suggestions. I’m all ears! Your feedback will not only help me improve this project but also guide other developers who want to embark on a similar journey.

## Let’s Collaborate!

This project is a work in progress, and I plan to keep updating the GitHub repository with new features and improvements on the arbitrage bot. When it’s complete, the repo will serve as a launching pad for anyone looking to learn and build their own arbitrage bot on the blockchain.

So, if you’ve got tips, tricks, or just a hearty laugh at my expense, hit me up in the comments or open an issue. Let’s learn from each other and make this project better together!

*P.S.: Yes, I used ChatGPT along the way, but every hiccup and revelation is totally my own. Thanks for reading my rollercoaster journey!*
