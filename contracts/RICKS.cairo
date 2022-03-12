%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check, uint256_eq)
# from contracts.utils.String import String_get, String_set
from openzeppelin.token.ERC721.interfaces.IERC721_Metadata import IERC721_Metadata
from openzeppelin.token.ERC721.interfaces.IERC721 import IERC721

from openzeppelin.token.ERC20.ERC20 import (
    ERC20_name, ERC20_symbol, ERC20_totalSupply, ERC20_decimals, ERC20_balanceOf, ERC20_allowance,
    ERC20_mint, ERC20_initializer, ERC20_approve, ERC20_increaseAllowance, ERC20_decreaseAllowance,
    ERC20_transfer, ERC20_transferFrom)

@view
func weth() -> (address : felt):
    # to be changed
    return (0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
end

@view
func stakingPool() -> (address : felt):
    # to be changed
    return (0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
end

# /// -----------------------------------
# /// -------- ERC721 INFORMATION --------
# /// -----------------------------------

# /// @notice the ERC721 token address being fractionalized
@view
func token() -> (address : felt):
    # to be changed
    return (0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
end

@storage_var
func id() -> (token_id : felt):
end

@storage_var
func auction_end_time() -> (end_time : Uint256):
end

@storage_var
func auction_interval() -> (interval : Uint256):
end

@storage_var
func min_bid_increase() -> (min_bid_increase : Uint256):
end

@storage_var
func auction_length() -> (auction_length : Uint256):
end

@storage_var
func winning_address() -> (winning_address : Uint256):
end

@storage_var
func token_ammount_for_auction() -> (auction_amount : Uint256):
end

# You’ll discover that AuctionState.north == 0, AuctionState.south == 1, AuctionState.west == 2, and AuctionState.east == 3.
struct AuctionState:
    member empty : felt
    member inactive : felt
    member active : felt
    member finalized : felt
end

@storage_var
func auction_state() -> (auction_state : AuctionState):
end

# most_recent_prices.write(0, 123)
# most_recent_prices.write(1, 456)
# most_recent_prices.write(2, 789)
# # ...
@storage_var
func most_recent_prices(i : Uint256) -> (res : Uint256):
end

@storage_var
func no_of_auctions() -> (no : Uint256):
end

@storage_var
func final_buyout_price_per_token() -> (res : Uint256):
end

@storage_var
func daily_inflationary_rate() -> (res : Uint256):
end

@storage_var
func initial_supply() -> (res : Uint256):
end

# /// @notice price per token when buyout is completed
# uint256 public finalBuyoutPricePerToken;

# /// @notice weth address
# address public constant weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

# /// @notice staking pool address
# address public stakingPool;

# /// -----------------------------------
# /// -------- ERC721 INFORMATION --------
# /// -----------------------------------

# /// @notice the ERC721 token address being fractionalized
# address public token;

# /// @notice the ERC721 token ID being fractionalized
# uint256 public id;

# /// -------------------------------------
# /// -------- AUCTION INFORMATION --------
# /// -------------------------------------

# /// @notice the unix timestamp end time of auction
# uint256 public auctionEndTime;

# /// @notice minimum amount of time between auctions
# uint256 public auctionInterval;

# /// @notice minimum % increase between bids. 3 decimals, ie. 100 = 10%
# uint256 public minBidIncrease;

# /// @notice the minumum length of auctions
# uint256 public auctionLength;

# /// @notice the current price of the winning Bid during auction
# uint256 public currentPrice;

# /// @notice the current user winning the token auction
# address payable public winning;

# /// @notice the amount of tokens being sold in current auction
# uint256 public tokenAmountForAuction;

# /// @notice possible states for the auction
# enum AuctionState {empty, inactive, active, finalized }

# /// @notice auction's current state
# AuctionState public auctionState;

# /// @notice price per shard for the five most recent auctions
# uint256[5] public mostRecentPrices;

# /// @notice number of auctions that have taken place
# uint256 public numberOfAuctions;

# /// @notice price per token when buyout is completed
# uint256 public finalBuyoutPricePerToken;

# /// -------------------------------------
# /// -------- Inflation Parameters -------
# /// -------------------------------------

# /// @notice rate of daily RICKS issuance. 3 decimals, ie. 100 = 10%
# uint256 public dailyInflationRate;

# /// @notice initial supply of RICKS tokens
# uint256 public initialSupply;

# /// ------------------------
# /// -------- EVENTS --------
# /// ------------------------

# /// @notice An event emitted when an auction is activated
# event Activate(address indexed initiatior);

# /// @notice An event emitted when an auction starts
# event Start(address indexed buyer, uint price);

# /// @notice An event emitted when a bid is made
# event Bid(address indexed buyer, uint price);

# /// @notice An event emitted when an auction is won
# event Won(address indexed buyer, uint price);

# /// @notice An event emitted when someone redeems all tokens for the NFT
# event Redeem(address indexed redeemer);

# /// @notice An event emitted with the price per token required for a buyout
# event BuyoutPricePerToken(address indexed buyer, uint price);
