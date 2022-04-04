# RICKS

## Introduction


An implementation of [RICKS](https://www.paradigm.xyz/2021/10/ricks/) in starknet cairo, an NFT primitive by [@_Dave__White_](https://twitter.com/_Dave__White_), [@andy8052](https://twitter.com/andy8052) and [@danrobinson](https://twitter.com/danrobinson). RICKS aims to solve the reconstitution problem -- how do we design a fractionalization mechanism that ensures a pathway to recovering the underlying asset? 

Help taken from ([https://github.com/FrankieIsLost/RICKS]) implementation in solidity.

## Implementation Notes

There are a few differences between the present implementation and the original mechanism design: 
###  The Reward/Bid currency
For now I have ERC20 Reward token at the currency to use in bidding. We can pass in the WETH address.
### The Buyout 

The original paper proposes a lottery buyout. When a majority owner triggers the buyout mechanism, they initiate a coin flip. With a 50% chance, they win all outstanding shares. And with a 50% chance, they pay every other owner the amount of shares required to double their positions. While this is EV fair, it has a few problems. Minority owners might feel like they were not properly compensated for their RICKS in the event of a loss, and majority owners might be reluctant to trigger the process given risk-aversion. 

This implementation uses a deterministic buyout process, which works as follows: First, the average price per shard of the past 5 buyouts is used to determine an implied valuation. Then, to trigger a buyout, an interested party must pay other owners a premium above this implied valuation. The premium scales quadratically with the unowned supply of RICKS, to disuade buyouts from minority owners. There's a lot of room to tune the premium function here. After the buyout process is completed, remaining shard holders are able to redeem those shards for their payout. 

### The Auction 

This implementation uses an on-demand auction system, where anyone can trigger an auction given a certain minimum amount of time has elapsed since the last auction. The amout of shards issued is based on the amount of time elapsed between auctions, and is tunable through an inflation rate parameter. 

### Staking

The RICKS contract deploys a staking pool on creation. Proceeds of the auction are paid to the staking pool. Any owner of RICKS can stake their shards in the pool. Proceeds from the auction are paid proportionally by staking weight at time of distribution into the pool. Staking pool implementation is based on [Scalable Reward Distribution on the Ethereum Blockchain](https://uploads-ssl.webflow.com/5ad71ffeb79acc67c8bcdaba/5ad8d1193a40977462982470_scalable-reward-distribution-paper.pdf)


### Main Files
[Ricks](https://github.com/FawadHa1der/cairo-contracts/blob/main/contracts/RICKS.cairo)
[Pool](https://github.com/FawadHa1der/cairo-contracts/blob/main/contracts/StakingPool.cairo)
[Pool Tests](https://github.com/FawadHa1der/cairo-contracts/blob/main/tests/test_stakingpool.py)
[ricks Tests](https://github.com/FawadHa1der/cairo-contracts/blob/main/tests/test_ricks.py)

### Testing and Building Files
You can run tests by running 'pytest'
Compile/Build by running 'nile compile'


### Deployment Intructions

refer to [Deployment file](https://github.com/FawadHa1der/cairo-contracts/blob/main/deploy/deploy.py)   
Steps
Make mutiple accounts in Argentx wallet to simulate different bidders bidding on the shard of NFTs
Mint 1000000 Test tokens in every account your Argentx wallet.
Compile/Build using the command 'nile compile' from project root directory
Deploy by running 'nile run deploy/deploy.py --network goerli'. This will deploy the staking contract and the main ricks contract on the goerli network and return you the addresses.
Give approval/allowance to the ricks contract for all your TEST tokens, since there is no native currency we will have to simulate the payments via this test token
using https://goerli.voyager.online/ mint a new token with TokenID = 54387 (or update the TOKEN_ID below)
Give approval to the ricks contract for the new minted token.
On the ricks contract call the 'activate' method and give it the erc721 contract address and the ID that you are fractionalyzing.
Now you can start the auction with a start_auction with a bid amount.
Any other account/user can also bid by calling the 'bid' method.
Any user can end the bidding by calling end_auction.
Who ever is the winner will get new 'RICKS' token and which will be deposited in staking contract.
Losing bids will have their bid refunded.
Any users can buyout other shards at any point by paying a premium propeortional to his unowned fraction of the total supply


### Build Environment.
Built with python3.7 and cairo-lang.0.7.0 and Nile 0.4.0
