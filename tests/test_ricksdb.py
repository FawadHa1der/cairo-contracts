import logging
import pytest
import asyncio
from starkware.starknet.public.abi import get_selector_from_name
from starkware.starknet.testing.starknet import Starknet
from utils import (
    Signer, uint, str_to_felt, ZERO_ADDRESS, TRUE, FALSE, assert_revert, assert_event_emitted,
    get_contract_def, cached_contract, to_uint, sub_uint, add_uint, div_rem_uint, mul_uint
)
LOGGER = logging.getLogger(__name__)
# @pytest.fixture(scope='session')
# def logger():

#     logger = logging.getLogger('Some.Logger')
#     logger.setLevel(logging.INFO)

#     return logger

OwnerSigner = Signer(123456789987654321)
Account1Signer = Signer(123456789987654322)
Account2Signer = Signer(123456789987654323)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
def contract_defs():
    account_def = get_contract_def('openzeppelin/account/Account.cairo')

    ricksdb_def = get_contract_def(
        'contracts/ricksdb.cairo')

    return account_def, ricksdb_def


@pytest.fixture(scope='module')
async def ricksdb_init(contract_defs):

    starknet = await Starknet.empty()
    account_def, ricksdb_def = contract_defs

    owner = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[OwnerSigner.public_key]
    )

    db = await starknet.deploy(
        contract_def=ricksdb_def,
    )

    return owner, db


@pytest.mark.asyncio
async def test_constructor(ricksdb_init):
    owner, db = ricksdb_init
    return_bool = await OwnerSigner.send_transaction(owner, db.contract_address, 'register', [db.contract_address])

    execution_info = await db.get_total_ricks().call()
    assert execution_info.result.total == 1

    execution_info = await db.get_ricks_address(0).call()
    assert execution_info.result.address == db.contract_address

    return_bool = await OwnerSigner.send_transaction(owner, db.contract_address, 'register', [111000])
    execution_info = await db.get_total_ricks().call()
    assert execution_info.result.total == 2

    execution_info = await db.get_ricks_address(1).call()
    assert execution_info.result.address == 111000
