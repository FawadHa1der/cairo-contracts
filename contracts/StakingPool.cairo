%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.uint256 import (
    Uint256, uint256_add, uint256_sub, uint256_le, uint256_lt, uint256_check, uint256_eq,
    uint256_mul, uint256_unsigned_div_rem)
# from contracts.utils.String import String_get, String_set
from openzeppelin.token.erc721.interfaces.IERC721 import IERC721
from openzeppelin.token.erc721.interfaces.IERC721_Metadata import IERC721_Metadata
from openzeppelin.token.ERC20.interfaces.IERC20 import IERC20
from starkware.starknet.common.syscalls import get_contract_address
from starkware.starknet.common.syscalls import call_contract, get_caller_address, get_tx_info
from openzeppelin.utils.constants import TRUE, FALSE


@event
func stake_called(user : felt, amount : Uint256):
end

@event
func unstake_called(user : felt, reward_amount : Uint256, stake_amount : Uint256):
end

@event
func deposit_reward_called(user : felt, reward_amount : Uint256):
end

@storage_var
func stakingerc20_address() -> (token_address : felt):
end

@storage_var
func rewarderc20_address() -> (token_address : felt):
end

@storage_var
func total_supply() -> (supply : Uint256):
end

@storage_var
func reward_factor() -> (reward : Uint256):
end

@storage_var
func staked_amounts(user : felt) -> (amount : Uint256):
end

@storage_var
func reward_factor_at_stake_time(user : felt) -> (reward_factor : Uint256):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        _stakingerc20_address : felt, _rewarderc20_address : felt):
    stakingerc20_address.write(_stakingerc20_address)
    rewarderc20_address.write(_rewarderc20_address)
    return ()
end

@view 
func total_supply_staked{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (supply:Uint256):
    let (supply: Uint256) = total_supply.read()
    return (supply)
end

@external
func stake{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(amount : Uint256):

    alloc_locals
    
    let (caller_address) = get_caller_address()
    assert_not_zero(caller_address)

    let (contract_address) = get_contract_address()
    
    # current stake has to be zero or unstake first
    let (current_stake) = staked_amounts.read(user=caller_address)
    let (stake_is_zero) = uint256_eq(current_stake, Uint256(0, 0))
    assert (stake_is_zero) = TRUE

    let (staking_token_address) = stakingerc20_address.read()
    IERC20.transferFrom(
        contract_address=staking_token_address,
        sender=caller_address,
        recipient=contract_address,
        amount=amount)

    staked_amounts.write(user=caller_address, value=amount)

    let (local current_supply : Uint256) = total_supply.read()
    let (local new_supply : Uint256, _) = uint256_add(current_supply, amount)
    let (local current_reward_factor : Uint256) = reward_factor.read()

    total_supply.write(value=new_supply)
    reward_factor_at_stake_time.write(user=caller_address, value=current_reward_factor)
    stake_called.emit(user=caller_address, amount=amount)
    return ()
end

@external
func unstake_claim_rewards{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals
    let (caller_address) = get_caller_address()
    let (local staked_amount : Uint256) = staked_amounts.read(caller_address)
    let (local cur_reward_factor : Uint256) = reward_factor.read()
    let (local _reward_factor_at_stake : Uint256) = reward_factor_at_stake_time.read(
        user=caller_address)
    let (local diff_stake : Uint256) = uint256_sub(cur_reward_factor, _reward_factor_at_stake)
    # let local diff_stake:Uint256
    let (local reward_amount : Uint256, _) = uint256_mul(staked_amount, diff_stake)
    let (total_supply_temp) = total_supply.read()
    # let local stakedAmount: Uint256 =  staked_amounts.read(user=caller_address)
    let (local rem_stake : Uint256, _) = uint256_mul(total_supply_temp, staked_amount)
    total_supply.write(value=rem_stake)
    let zero_as_uint256 : Uint256 = Uint256(0, 0)

    staked_amounts.write(user=caller_address, value=zero_as_uint256)
    let (staking_token_address) = stakingerc20_address.read()
    let (reward_token_address) = rewarderc20_address.read()
    IERC20.transfer(
        contract_address=staking_token_address, recipient=caller_address, amount=staked_amount)
    IERC20.transfer(
        contract_address=reward_token_address, recipient=caller_address, amount=reward_amount)
    unstake_called.emit(
        user=caller_address, reward_amount=reward_amount, stake_amount=staked_amount)

    return ()
end

@external
func deposit_reward{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : Uint256):
    alloc_locals
    let (caller_address) = get_caller_address()
    let (local reward_token_address : felt) = rewarderc20_address.read()
    let (local contract_address) = get_contract_address()

    IERC20.transferFrom(
        contract_address=reward_token_address,
        sender=caller_address,
        recipient=contract_address,
        amount=amount)
    # Instanciating a zero in uint format
    let zero_as_uint256 : Uint256 = Uint256(0, 0)
    let (local cur_total_supply : Uint256) = total_supply.read()
    let (local is_equal) = uint256_eq(cur_total_supply, zero_as_uint256)

    tempvar caller_address = caller_address
    tempvar syscall_ptr = syscall_ptr
    tempvar pedersen_ptr = pedersen_ptr
    tempvar range_check_ptr = range_check_ptr

    if is_equal == 0:
        # tempvar caller_address = caller_address
        tempvar syscall_ptr = syscall_ptr
        tempvar pedersen_ptr = pedersen_ptr
        tempvar range_check_ptr = range_check_ptr

        let (local tmp_reward_factor_inc : Uint256, _) = uint256_unsigned_div_rem(
            amount, cur_total_supply)
        let (local cur_reward : Uint256) = reward_factor.read()
        let (local new_reward : Uint256, _) = uint256_add(tmp_reward_factor_inc, cur_reward)
        reward_factor.write(value=new_reward)
    end
    # tempvar caller_address = caller_address
    # tempvar syscall_ptr = syscall_ptr
    # tempvar pedersen_ptr = pedersen_ptr
    # tempvar range_check_ptr = range_check_ptr

    # tempvar syscall_ptr = syscall_ptr
    # tempvar pedersen_ptr = pedersen_ptr
    # tempvar range_check_ptr = range_check_ptr

    # let (local caller_address) = get_caller_address()
    deposit_reward_called.emit(user=caller_address, reward_amount=amount)

    return ()
end
