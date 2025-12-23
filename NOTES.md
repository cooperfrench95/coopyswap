# Simple AMM Implementation

The goal is to create an interface like Uniswap V2. 

## User Stories

* As a user of CoopySwap, I want to be able to create a liquidity pool between two ERC20s.
* As a user of CoopySwap, I want to be able to create a liquidity pool between ETH and an ERC20.
* As a user of CoopySwap, I want to be able to perform a swap between two tokens on a liquidity pool.
* As a user of CoopySwap, I expect the current price of each token in the liquidity pool to adjust automatically based on the contents of the liquidity pool.
* As a user of CoopySwap, I want to be able to provide liquidity to a liquidity pool.
* As a user of CoopySwap, I should be given an NFT representing my proportion of holdings within the LP when I provide liquidity.
* As a user of CoopySwap, I should be able to turn in the NFT representation of my LP holdings in exchange for withdrawing my liquidity from the pool
* As a user of CoopySwap, I should receive fee benefits when I turn in my NFT in addition to my liquidity.

## Technical Requirements

* Contract that creates LP and handles withdrawals & deposits to that LP as well as the associated NFTs.
* Contract representing an LP itself, manages internal LP state and fee collection

## Areas to focus on

* Integer/Fixed point arithmetic (really not sinking in. Need more practice with these zeroes)
* Try creating nice helpful representations or abstractions over the math

## Roadmap

* Add withdrawLiquidity function (must hand in NFT and burn it)
* Add fee support (new contract that stores and manages fees)
* Add unit tests
* Deploy to testnet
* Add frontend?