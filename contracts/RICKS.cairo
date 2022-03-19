%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import (
    assert_not_zero, assert_not_equal, assert_le, assert_lt, unsigned_div_rem)
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check, uint256_eq)
from openzeppelin.token.ERC721.interfaces.IERC721_Metadata import IERC721_Metadata
from openzeppelin.token.ERC721.interfaces.IERC721 import IERC721
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp

from openzeppelin.token.erc20.library import (
    ERC20_name, ERC20_symbol, ERC20_totalSupply, ERC20_decimals, ERC20_balanceOf, ERC20_allowance,
    ERC20_initializer, ERC20_approve, ERC20_increaseAllowance, ERC20_decreaseAllowance,
    ERC20_transfer, ERC20_transferFrom, ERC20_mint, ERC20_burn)

# from openzeppelin.token.ERC20.ERC20 import (
#     ERC20_name, ERC20_symbol, ERC20_totalSupply, ERC20_decimals, ERC20_balanceOf, ERC20_allowance,
#     ERC20_mint, ERC20_initializer, ERC20_approve, ERC20_increaseAllowance, ERC20_decreaseAllowance,
#     ERC20_transfer, ERC20_transferFrom)

# @view
# func weth() -> (address : felt):
#     # to be changed
#     return (0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
# end

# @view
# func stakingPool() -> (address : felt):
#     # to be changed
#     return (0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2)
# end

# -----------------------------------
# -------- ERC721 INFORMATION --------
# -----------------------------------

# the ERC721 token address being fractionalized
@storage_var
func token_address() -> (address : felt):
end

@storage_var
func token_id() -> (id : felt):
end

@storage_var
func staking_contract() -> (contract : felt):
end

@storage_var
func reward_contract() -> (contract : felt):
end

@storage_var
func staking_pool_contract() -> (contract : felt):
end

@storage_var
func auction_end_time() -> (time : felt):
end

@storage_var
func auction_interval() -> (interval : felt):
end

@storage_var
func min_bid_increase() -> (increase : felt):
end

@storage_var
func auction_length() -> (length : felt):
end

@storage_var
func current_price() -> (price : felt):
end

@storage_var
func winning_address() -> (address : felt):
end

@storage_var
func token_amount_for_auction() -> (amount : felt):
end

namespace AuctionState:
    const EMPTY = 1
    const INACTIVE = 2
    const ACTIVE = 3
    const FINALYZED = 3
end

@storage_var
func auction_state() -> (state : felt):
end

# @storage_var
# func auction_state() -> (auction_state : AuctionState):
# end

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
func daily_inflationary_rate() -> (rate : felt):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        name : felt, symbol : felt, decimals : felt, initial_supply : Uint256, recipient : felt,
        _token : felt, _id : felt, _daily_inflation_rate : felt, _staking_contract : felt,
        _staking_pool_contract : felt, _reward_contract : felt):
    ERC20_initializer(name, symbol, decimals)
    ERC20_mint(recipient, initial_supply)

    token_address.write(value=_token)
    token_id.write(value=_id)
    staking_contract.write(_staking_contract)
    staking_pool_contract.write(_staking_pool_contract)

    assert_not_equal(_daily_inflation_rate, 0)

    daily_inflationary_rate.write(_daily_inflation_rate)
    reward_contract.write(_reward_contract)
    auction_state.write(AuctionState.EMPTY)

    auction_length.write(10800)  # 3 hours
    auction_interval.write(86400)
    min_bid_increase.write(50)

    return ()
end

@external
func activate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(bid : felt) -> ():
    let action_state : felt = auction_state.read()
    assert action_state = AuctionState.INACTIVE

    let block_time_stamp : felt = get_block_timestamp()
    let _auction_end_time : felt = auction_end_time.read()
    let _auction_interval : felt = auction_interval.read()
    let end_time = _auction_end_time + _auction_interval

    assert_le(end_time, block_time_stamp)
    assert_not_zero(bid)

    let _daily_inflationary_rate : felt = daily_inflationary_rate.read()
    let _total_supply : felt = ERC20_totalSupply()

    let inflation_per_day = _daily_inflationary_rate * _total_supply
    let inflation_seconds_for_auction = block_time_stamp - _auction_end_time
    let (inflation_per_second : felt, _) = unsigned_div_rem(inflation_per_day, 86400000)

    let inflation_amount : felt = inflation_seconds_for_auction * inflation_per_second
    let _auction_length : felt = auction_length.read()
    assert_not_zero(inflation_amount)

    token_amount_for_auction.write(value=inflation_amount)
    auction_end_time.write(value=(block_time_stamp + _auction_length))
    auction_state.write(value=AuctionState.ACTIVE)

    let _get_caller_address : felt = get_caller_address()
    current_price.write(value=bid)
    winning_address.write(value=_get_caller_address)

    return ()
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
