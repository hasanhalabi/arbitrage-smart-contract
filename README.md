# Building My First Blockchain Arbitrage Bot: A Journey with ChatGPT
Hey there! 👋 I’m not a native English speaker, so yeah, I asked ChatGPT to help me write this piece of content. But don’t worry—I’m still the one driving this article, giving ChatGPT the keys to the kingdom. Think of it as a collaboration between human intuition and AI smarts.

## From 15 Years of Coding to My First Blockchain Adventure

Coming from a place where income opportunities are limited, I thought, “Hey, why not build something that can generate income within minimum monitoring using my existing development skills?” 

I’ve been writing code for over 15 years now, but stepping into the blockchain world was a whole new ballgame for me. Solidity, EVMs, and decentralized exchanges? Seriously, my brain was doing somersaults! I decided to take the plunge and build something meaningful with it— **An Arbitrage Bot**. And yes, I roped in ChatGPT again to guide me through writing that bot.

Let me tell you, it wasn’t like those instant magic tricks you see in YouTube spam videos. This journey took me over two weeks of intense learning, trial and error, and lots of coffee and smoked Hookah. And believe me, there were moments when I just wanted to throw my laptop out the window. But hey, nothing worth doing is easy, right?

## My Learning Path: YouTube Tutorials and a Bit of Hustle

Like many of us, I prefer a hands-on approach to learning. I didn’t dive straight into reading dense documentation. Instead, I binge-watched a ton of free YouTube tutorials, built something (often broken at first), and learned by doing. 

While on this quest, I encountered a mountain of scams and spam on YouTube. It was like swimming in a sea of misinformation! But I also found some legendary ideas that really sparked my interest. After solid research and sifting through the noise, I was convinced: building an arbitrage bot was the way to go. Why? Simple:

1. It was the easiest starting point.
2. It allowed me to use flash loans—a perfect fit for someone on a tight budget.

## The Frustration: Meaningless Variable Names and the Uniswap Mystery

One of the trickiest parts was wrestling with the seemingly meaningless names in the documentation. For example, I needed to take a flash loan from Uniswap V3. The docs told me to provide a fee, token0, token1… Seriously? I just wanted a flash loan of 100 USDC. Why did I need to fill in token0 and token1? And what’s this about setting the fee when the lender should decide that? 🤷

After countless discussions with ChatGPT, deep dives into forums, and endless scrolling through Uniswap’s pools section, the pieces started to click. I learned that the pool is actually a pair of two tokens bundled with a fee. It wasn’t a straightforward path, but every “aha!” moment made it all worthwhile.

## Designing the Arbitrage Bot: Split Responsibilities

When designing the bot, I split it into two main parts:

1. Smart Contract: The heavy lifter that executes the actual trades on the blockchain.
2. NodeJS Backend: A monitoring system that scans decentralized exchanges (DEXes) for arbitrage opportunities, and call the smart contract whenever it finds a good one.

At this stage, I’ve finished the smart contract part. 🎉 Yay me!

## Calling All Solidity Developers: I Need Your Help!

Now, here’s where you come in. I’m reaching out to the Solidity developer community for a favor: please review and audit my smart contract code. I know the community is full of seasoned pros who can spot issues I might have missed. Your feedback would be invaluable and greatly appreciated.

## What’s Next?

I’ll keep updating the GitHub repository with all the latest progress on my arbitrage bot. When it’s fully complete, I’ll make sure to publish the latest stable version. My hope is that other developers embarking on a similar journey will find this repository a great starting point.

So, if you’re interested in blockchain, arbitrage, or just want to see how a 15-year coding veteran stumbles his way through the world of smart contracts, stick around! Feel free to drop your comments, suggestions, or even critiques. 

Happy coding! 🚀🤓

*P.S.: Yes, I used ChatGPT to draft this, but every word echoes my personal learning curve and quirks. So, thanks for reading my story!*
