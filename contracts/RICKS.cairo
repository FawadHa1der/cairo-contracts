%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import (
    assert_not_zero, assert_not_equal, assert_le, assert_lt, unsigned_div_rem, assert_nn)
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check, uint256_eq)
from openzeppelin.token.erc721.interfaces.IERC721 import IERC721
from openzeppelin.token.erc721.interfaces.IERC721_Receiver import IERC721_Receiver
from starkware.starknet.common.syscalls import (
    get_block_number, get_block_timestamp, get_contract_address)

from openzeppelin.token.erc20.library import (
    ERC20_name, ERC20_symbol, ERC20_totalSupply, ERC20_decimals, ERC20_balanceOf, ERC20_allowance,
    ERC20_initializer, ERC20_approve, ERC20_increaseAllowance, ERC20_decreaseAllowance,
    ERC20_transfer, ERC20_transferFrom, ERC20_mint, ERC20_burn)

from contracts.IStakingPool import IStakingPool
from openzeppelin.token.ERC20.interfaces.IERC20 import IERC20
from openzeppelin.utils.constants import TRUE, FALSE
from openzeppelin.introspection.ERC165 import ERC165_supports_interface, ERC165_register_interface

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

# same as weth
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
func initial_supply() -> (supply : felt):
end

@view
func view_initial_supply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        supply : felt):
    let _initial_supply : felt = initial_supply.read()
    return (_initial_supply)
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

@view
func view_winning_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        address : felt):
    let _winning_address : felt = winning_address.read()
    return (_winning_address)
end

@storage_var
func token_amount_for_auction() -> (amount : felt):
end

@view
func view_token_amount_for_auction{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (amount : felt):
    let _token_amount_for_auction : felt = token_amount_for_auction.read()
    return (_token_amount_for_auction)
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

@view
func view_auction_state{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        auction_state : felt):
    let _auction_state : felt = auction_state.read()
    return (_auction_state)
end

@storage_var
func most_recent_prices(i : felt) -> (res : felt):
end

@storage_var
func no_of_auctions() -> (no : felt):
end

@storage_var
func final_buyout_price_per_token() -> (res : felt):
end

@view
func view_final_buyout_price_per_token{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (price : felt):
    let _final_buyout_price_per_token : felt = final_buyout_price_per_token.read()
    return (_final_buyout_price_per_token)
end

@storage_var
func daily_inflationary_rate() -> (rate : felt):
end
const AUCTION_SIZE = 5

@view
func onERC721Received(
        operator : felt, _from : felt, tokenId : Uint256, data_len : felt, data : felt*) -> (
        selector : felt):
    # ERC721_RECEIVER_ID = 0x150b7a02
    return (0x150b7a02)
end

@view
func supportsInterface{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        interfaceId : felt) -> (success : felt):
    let (success) = ERC165_supports_interface(interfaceId)
    return (success)
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        name : felt, symbol : felt, decimals : felt, _initial_supply : felt,
        _daily_inflation_rate : felt, _auction_length : felt, _auction_interval : felt,
        _min_bid_increase : felt, _staking_pool_contract : felt, _reward_contract : felt):
    # let decimals_256 : Uint256 = Uint256(decimals, 0)
    ERC20_initializer(name, symbol, decimals)

    staking_pool_contract.write(_staking_pool_contract)
    let ricks_contract_address : felt = get_contract_address()
    IStakingPool.pool_initialize(_staking_pool_contract, ricks_contract_address, _reward_contract)

    assert_not_equal(_daily_inflation_rate, 0)

    daily_inflationary_rate.write(_daily_inflation_rate)
    reward_contract.write(_reward_contract)
    auction_state.write(AuctionState.EMPTY)
    initial_supply.write(_initial_supply)

    auction_length.write(_auction_length)  # 10800 = 3 hours
    auction_interval.write(_auction_interval)  # 1 day = 86400
    min_bid_increase.write(_min_bid_increase)  # min_bid_increase could be 50

    # ERC721_RECEIVER_ID = 0x150b7a02
    ERC165_register_interface(0x150b7a02)

    return ()
end

@external
func activate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _token : felt, _token_id : felt) -> (success : felt):
    let action_state : felt = auction_state.read()
    assert action_state = AuctionState.EMPTY

    assert_not_zero(_token * _token_id)
    token_address.write(value=_token)
    token_id.write(value=_token_id)

    let caller_address : felt = get_caller_address()
    let _token_address : felt = token_address.read()
    let contract_address : felt = get_contract_address()
    let _token_id : felt = token_id.read()

    let _token_id_256 : Uint256 = Uint256(_token_id, 0)

    IERC721.transferFrom(
        contract_address=_token_address,
        _from=caller_address,
        to=contract_address,
        tokenId=_token_id_256)

    let block_time_stamp : felt = get_block_timestamp()
    let _initial_supply : felt = initial_supply.read()
    auction_end_time.write(block_time_stamp)

    auction_state.write(AuctionState.INACTIVE)

    assert_not_zero(_initial_supply)
    let _initial_supply_256 : Uint256 = Uint256(_initial_supply, 0)
    ERC20_mint(caller_address, _initial_supply_256)

    return (TRUE)
end

@external
func start_auction{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        bid : felt) -> (success : felt):
    let action_state : felt = auction_state.read()
    assert action_state = AuctionState.INACTIVE

    let block_time_stamp : felt = get_block_timestamp()
    let _auction_end_time : felt = auction_end_time.read()
    let _auction_interval : felt = auction_interval.read()
    let end_time : felt = _auction_end_time + _auction_interval

    with_attr error_message("cannot start auction yet"):
        assert_le(end_time, block_time_stamp)
    end

    assert_not_zero(bid)

    let _daily_inflationary_rate : felt = daily_inflationary_rate.read()
    let _total_supply_256 : Uint256 = ERC20_totalSupply()
    let _total_supply : felt = _total_supply_256.low
    # let _total_supply : felt =

    let inflation_per_day : felt = _daily_inflationary_rate * _total_supply
    let inflation_seconds_for_auction : felt = block_time_stamp - _auction_end_time
    let inflation_for_seconds : felt = inflation_per_day * inflation_seconds_for_auction
    let (inflation_amount : felt, _) = unsigned_div_rem(inflation_for_seconds, 86400000)

    # let inflation_amount : felt = inflation_seconds_for_auction * inflation_per_second
    let _auction_length : felt = auction_length.read()
    assert_not_zero(inflation_amount)

    token_amount_for_auction.write(inflation_amount)
    auction_end_time.write(block_time_stamp + _auction_length)
    auction_state.write(AuctionState.ACTIVE)

    let _get_caller_address : felt = get_caller_address()
    current_price.write(value=bid)
    winning_address.write(value=_get_caller_address)

    let caller_address : felt = get_caller_address()
    let _reward_token : felt = reward_contract.read()
    let ricks_contract_address : felt = get_contract_address()
    let bid_256 : Uint256 = Uint256(bid, 0)

    IERC20.transferFrom(
        contract_address=_reward_token,
        sender=caller_address,
        recipient=ricks_contract_address,
        amount=bid_256)

    return (TRUE)
end

@external
func bid{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(bid : felt) -> (
        success : felt):
    alloc_locals
    let action_state : felt = auction_state.read()
    assert action_state = AuctionState.ACTIVE

    let _block_time_stamp : felt = get_block_timestamp()
    let _auction_end_time : felt = auction_end_time.read()
    assert_le(_block_time_stamp, _auction_end_time)

    let _min_bid_increase : felt = min_bid_increase.read()
    let min_increase_multipler : felt = _min_bid_increase + 1000
    let _current_price : felt = current_price.read()
    let _current_price_256 : Uint256 = Uint256(_current_price, 0)

    with_attr error_message("bid too low"):
        assert_le(_current_price * min_increase_multipler, bid * 1000)
    end

    # If bid is within 15 minutes of auction end, extend auction
    let time_till_auction_ends = _auction_end_time - _block_time_stamp
    const TIME_RANGE = 900  # 15 mins
    let within_15_min : felt = is_le(time_till_auction_ends, TIME_RANGE)

    if within_15_min == TRUE:
        let cur_auction_end_time : felt = auction_end_time.read()
        auction_end_time.write(cur_auction_end_time + TIME_RANGE)
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    else:
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr
    end
    let ricks_contract_address : felt = get_contract_address()
    let _winning_address : felt = winning_address.read()
    let bid_256 : Uint256 = Uint256(bid, 0)
    let caller_address : felt = get_caller_address()
    let _reward_token : felt = reward_contract.read()

    # transfer back to the older winnning address
    IERC20.transfer(
        contract_address=_reward_token, recipient=_winning_address, amount=_current_price_256)

    # move the winning bid amount weth/reward tokens to ricks contract address
    IERC20.transferFrom(
        contract_address=_reward_token,
        sender=caller_address,
        recipient=ricks_contract_address,
        amount=bid_256)

    current_price.write(bid)
    winning_address.write(caller_address)
    return (TRUE)
end

@external
func end_auction{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        success : felt):
    alloc_locals
    let action_state : felt = auction_state.read()
    assert action_state = AuctionState.ACTIVE

    let (local block_time_stamp : felt) = get_block_timestamp()
    let _auction_end_time : felt = auction_end_time.read()
    # %{ print(f'endtime  - data:{ids._auction_end_time} ') %}

    assert_le(_auction_end_time, block_time_stamp)

    let _current_price : felt = current_price.read()
    let _total_amount_for_auction : felt = token_amount_for_auction.read()

    let (most_recent_price : felt, _) = unsigned_div_rem(_current_price, _total_amount_for_auction)
    update_most_recent_prices(AUCTION_SIZE, most_recent_price)

    auction_state.write(AuctionState.INACTIVE)
    auction_end_time.write(block_time_stamp)

    let _no_of_auction : felt = no_of_auctions.read()
    no_of_auctions.write(_no_of_auction + 1)

    let caller_address : felt = get_caller_address()
    let _reward_token : felt = reward_contract.read()
    let ricks_contract_address : felt = get_contract_address()

    let pool_contract_address : felt = staking_pool_contract.read()
    let _current_price_256 = Uint256(_current_price, 0)

    IERC20.approve(
        contract_address=_reward_token, spender=pool_contract_address, amount=_current_price_256)

    IStakingPool.deposit_reward(contract_address=pool_contract_address, amount=_current_price_256)

    let _winning_address : felt = winning_address.read()
    let _total_amount_for_auction_256 : Uint256 = Uint256(_total_amount_for_auction, 0)
    ERC20_mint(_winning_address, _total_amount_for_auction_256)
    return (TRUE)
end

@external
func buyout{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(bid : felt) -> (
        success : felt):
    alloc_locals
    let action_state : felt = auction_state.read()
    assert action_state = AuctionState.INACTIVE

    let _no_of_auction : felt = no_of_auctions.read()

    with_attr error_message("not enough auctions to establish price"):
        assert_le(AUCTION_SIZE, _no_of_auction)
    end

    let caller_address : felt = get_caller_address()
    let price_per_token : felt = buyout_price_per_token(caller_address)
    let _total_supply_256 : Uint256 = ERC20_totalSupply()
    let _total_supply : felt = _total_supply_256.low

    let balance_of_buyer_256 : Uint256 = ERC20_balanceOf(caller_address)
    let balance_of_buyer : felt = balance_of_buyer_256.low

    let unowned_supply : felt = _total_supply - balance_of_buyer
    let total_buyout_cost : felt = price_per_token * unowned_supply
    let ricks_contract_address : felt = get_contract_address()
    let _token_address : felt = token_address.read()

    let _token_id : felt = token_id.read()
    let _token_id_256 : Uint256 = Uint256(_token_id, 0)
    with_attr error_message("not enough to complete buyout"):
        assert_le(total_buyout_cost, bid)
    end
    let balance_of_buyer_256 : Uint256 = Uint256(balance_of_buyer, 0)
    let bid_256 : Uint256 = Uint256(bid, 0)
    let _reward_token : felt = reward_contract.read()
    let ricks_contract_address : felt = get_contract_address()

    IERC20.transferFrom(
        contract_address=_reward_token,
        sender=caller_address,
        recipient=ricks_contract_address,
        amount=bid_256)

    ERC20_burn(caller_address, balance_of_buyer_256)

    final_buyout_price_per_token.write(price_per_token)

    IERC721.transferFrom(
        contract_address=_token_address,
        _from=ricks_contract_address,
        to=caller_address,
        tokenId=_token_id_256)

    auction_state.write(AuctionState.FINALYZED)

    return (TRUE)
end

@external
func buyout_price_per_token{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        buyer_address : felt) -> (price : felt):
    alloc_locals
    let balance_of_buyer_256 : Uint256 = ERC20_balanceOf(buyer_address)
    let balance_of_buyer : felt = balance_of_buyer_256.low

    let _total_supply_256 : Uint256 = ERC20_totalSupply()
    let _total_supply : felt = _total_supply_256.low
    let (owner_supply_ratio : felt, _) = unsigned_div_rem(balance_of_buyer * 1000, _total_supply)
    let unowned_supply_ratio : felt = 1000 - owner_supply_ratio
    let unowned_supply_ratio_power_2 : felt = unowned_supply_ratio * unowned_supply_ratio

    let (unowned_supply_ratio_percent : felt, _) = unsigned_div_rem(
        unowned_supply_ratio_power_2, 100)
    let premium : felt = unowned_supply_ratio_percent + 1000

    let average_price : felt = calculate_average_price()
    let (price_per_token : felt, _) = unsigned_div_rem(premium * average_price, 1000)

    return (price_per_token)
end

@external
func redeem_ricks_for_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        ) -> (success : felt):
    alloc_locals
    let action_state : felt = auction_state.read()
    let caller_address : felt = get_caller_address()
    assert action_state = AuctionState.FINALYZED
    let balance_256 : Uint256 = ERC20_balanceOf(caller_address)
    let balance : felt = balance_256.low
    let _final_buyout_price_per_token : felt = final_buyout_price_per_token.read()
    let payment_due : felt = balance * _final_buyout_price_per_token
    let payment_256 : Uint256 = Uint256(payment_due, 0)
    let _reward_token : felt = reward_contract.read()

    ERC20_burn(caller_address, balance_256)
    IERC20.transfer(contract_address=_reward_token, recipient=caller_address, amount=payment_256)

    return (TRUE)
end

# bad hack, currently arrays are not supported in storage variables
func update_most_recent_prices{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _idx : felt, new_price : felt) -> ():
    if _idx == 0:
        return ()
    end
    # %{ print(f'newprice  - data:{ids.new_price} idx:{ids._idx} ') %}

    let price_for_idx : felt = most_recent_prices.read(_idx)
    most_recent_prices.write(i=_idx, value=new_price)

    update_most_recent_prices(_idx=_idx - 1, new_price=price_for_idx)
    return ()
end

@view
func calculate_average_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        ) -> (average : felt):
    let sum : felt = calculate_sum_price(AUCTION_SIZE)
    let (_average : felt, _) = unsigned_div_rem(sum, AUCTION_SIZE)
    return (_average)
end

@view
func calculate_sum_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        idx : felt) -> (sum : felt):
    if idx == 0:
        # let last_price : felt = most_recent_prices.read(idx)
        return (0)  # we dont use the the zero idx.
    end

    let _sum : felt = calculate_sum_price(idx - 1)
    let price_for_idx : felt = most_recent_prices.read(idx)
    let new_sum : felt = _sum + price_for_idx

    return (new_sum)
end

@view
func name{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (name : felt):
    let (name) = ERC20_name()
    return (name)
end

@view
func symbol{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (symbol : felt):
    let (symbol) = ERC20_symbol()
    return (symbol)
end

@view
func totalSupply{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        totalSupply : Uint256):
    let (totalSupply : Uint256) = ERC20_totalSupply()
    return (totalSupply)
end

@view
func decimals{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        decimals : felt):
    let (decimals) = ERC20_decimals()
    return (decimals)
end

@view
func balanceOf{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account : felt) -> (balance : Uint256):
    let (balance : Uint256) = ERC20_balanceOf(account)
    return (balance)
end

@view
func allowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, spender : felt) -> (remaining : Uint256):
    let (remaining : Uint256) = ERC20_allowance(owner, spender)
    return (remaining)
end

#
# Externals
#

@external
func transfer{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        recipient : felt, amount : Uint256) -> (success : felt):
    ERC20_transfer(recipient, amount)
    return (TRUE)
end

@external
func transferFrom{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        sender : felt, recipient : felt, amount : Uint256) -> (success : felt):
    ERC20_transferFrom(sender, recipient, amount)
    return (TRUE)
end

@external
func approve{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, amount : Uint256) -> (success : felt):
    ERC20_approve(spender, amount)
    return (TRUE)
end

@external
func increaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, added_value : Uint256) -> (success : felt):
    ERC20_increaseAllowance(spender, added_value)
    return (TRUE)
end

@external
func decreaseAllowance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        spender : felt, subtracted_value : Uint256) -> (success : felt):
    ERC20_decreaseAllowance(spender, subtracted_value)
    return (TRUE)
end

@external
func burn{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(amount : Uint256):
    let (owner) = get_caller_address()
    ERC20_burn(owner, amount)
    return ()
end
