%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.math import (
    abs_value, assert_nn, assert_le, assert_lt, unsigned_div_rem, signed_div_rem, assert_in_range,
    sqrt)
from starkware.cairo.common.math_cmp import is_le, is_in_range
# from openzeppelin.utils.constants import TRUE, FALSE

@storage_var
func ricks_address(id : felt) -> (address : felt):
end

@storage_var
func total_ricks() -> (total : felt):
end

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    return ()
end

@external
func register{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        address : felt) -> ():
    let _total_ricks : felt = total_ricks.read()
    ricks_address.write(_total_ricks, address)
    total_ricks.write(_total_ricks + 1)
    return ()
end

@view
func get_ricks_address{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        id : felt) -> (address : felt):
    let address : felt = ricks_address.read(id)
    return (address)
end

@view
func get_total_ricks{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (total : felt):
    let total : felt = total_ricks.read()
    return (total)
end

