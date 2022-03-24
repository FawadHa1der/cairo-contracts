from starkware.starknet.business_logic.state import BlockInfo
from starkware.starknet.public.abi import get_selector_from_name
import logging
from ast import Constant
import pytest
from enum import Enum
import asyncio
from starkware.starknet.testing.starknet import Starknet
from utils import (
    Signer, uint, str_to_felt, ZERO_ADDRESS, TRUE, FALSE, assert_revert, assert_event_emitted,
    get_contract_def, cached_contract, to_uint, sub_uint, add_uint
)

signer = Signer(123456789987654321)
ERC721Id = 0
INITIAL_RICKS_SUPPLY = 100
DAILY_INFLATION_RATE = 50
TIME_ELAPSED_ONE_HOUR = 3600
TIME_ELAPSED_SIX_HOUR = 21600


class AuctionState(Enum):
    empty = 0,
    inactive = 1,
    active = 2,
    finalized = 3


HOUR = 60 * 60

NONEXISTENT_TOKEN = to_uint(999)
# random token IDs
TOKENS = [5042, 793]
# test token
TOKEN = TOKENS[0]
# random user address
RECIPIENT = 555
# random data (mimicking bytes in Solidity)
DATA = [0x42, 0x89, 0x55]
# random URIs
SAMPLE_URI_1 = str_to_felt('mock://mytoken.v1')
SAMPLE_URI_2 = str_to_felt('mock://mytoken.v2')

# selector ids
IERC165_ID = 0x01ffc9a7
IERC721_ID = 0x80ac58cd
IERC721_METADATA_ID = 0x5b5e139f
INVALID_ID = 0xffffffff
UNSUPPORTED_ID = 0xabcd1234


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
def contract_defs():
    account_def = get_contract_def('openzeppelin/account/Account.cairo')
    erc721_def = get_contract_def(
        'openzeppelin/token/erc721/ERC721_Mintable_Pausable.cairo')
    erc721_holder_def = get_contract_def(
        'openzeppelin/token/erc721/utils/ERC721_Holder.cairo')

    unsupported_def = get_contract_def(
        'openzeppelin/security/initializable.cairo')

    erc20_def = get_contract_def(
        'openzeppelin/token/erc20/ERC20.cairo')

    stakingpool_def = get_contract_def(
        'contracts/StakingPool.cairo')
    ricks_def = get_contract_def(
        'contracts/RICKS.cairo')

    return account_def, erc721_def, erc721_holder_def, unsupported_def, erc20_def, stakingpool_def, ricks_def


def update_starknet_block(starknet, block_number=1, block_timestamp=TIME_ELAPSED_ONE_HOUR):
    starknet.state.state.block_info = BlockInfo(
        block_number=block_number, block_timestamp=block_timestamp)


def reset_starknet_block(starknet):
    update_starknet_block(starknet=starknet)


# async def setup_ricks(starknet, staking_contract, staking_pool_contract, reward_contract, erc721IdContract, erc721Id):
#     ricks = await starknet.deploy(
#         "contracts/ricks.cairo",
#         constructor_calldata=[
#             str_to_felt("RICKS"),      # name
#             str_to_felt("RCK"),        # symbol
#             18,                        # decimals
#             INITIAL_RICKS_SUPPLY,               # initial_supply
#             erc721IdContract,
#             5042,
#             DAILY_INFLATION_RATE,
#             staking_contract,
#             staking_pool_contract,
#             reward_contract
#         ]
#     )

#     return ricks


@pytest.fixture(scope='module')
async def erc721_init(contract_defs):
    account_def, erc721_def, erc721_holder_def, unsupported_def, erc20_def, stakingpool_def, ricks_def = contract_defs
    starknet = await Starknet.empty()
    owner = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )

    account1 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )

    account2 = await starknet.deploy(
        contract_def=account_def,
        constructor_calldata=[signer.public_key]
    )

    erc721 = await starknet.deploy(
        contract_def=erc721_def,
        constructor_calldata=[
            str_to_felt("Non Fungible Token"),  # name
            str_to_felt("NFT"),                 # ticker
            account1.contract_address           # owner
        ]
    )

    erc721_holder = await starknet.deploy(
        contract_def=erc721_holder_def,
        constructor_calldata=[]
    )

    unsupported = await starknet.deploy(
        contract_def=unsupported_def,
        constructor_calldata=[]
    )

    erc20Stake = await starknet.deploy(
        contract_def=erc20_def,
        constructor_calldata=[
            str_to_felt("STAKE"),      # name
            str_to_felt("STK"),        # symbol
            18,                        # decimals
            *uint(1000),               # initial_supply
            owner.contract_address   # recipient
        ]
    )

    erc20Reward = await starknet.deploy(
        contract_def=erc20_def,
        constructor_calldata=[
            str_to_felt("Reward"),      # name
            str_to_felt("RWD"),        # symbol
            18,                        # decimals
            *uint(1000),               # initial_supply
            owner.contract_address   # recipient
        ]
    )

    stakingPool = await starknet.deploy(
        contract_def=stakingpool_def,
        constructor_calldata=[
            erc20Stake.contract_address,
            erc20Reward.contract_address
        ]
    )

    ricks = await starknet.deploy(
        contract_def=ricks_def,
        constructor_calldata=[
            str_to_felt("RICKS"),      # name
            str_to_felt("RCK"),        # symbol
            18,                        # decimals
            INITIAL_RICKS_SUPPLY,               # initial_supply
            erc721.contract_address,
            TOKEN,
            DAILY_INFLATION_RATE,
            erc20Stake.contract_address,
            stakingPool.contract_address,
            erc20Reward.contract_address
        ]
    )

    return (
        starknet.state,
        owner,
        account1,
        account2,
        erc721,
        erc721_holder,
        unsupported,
        erc20Stake,
        stakingPool,
        erc20Reward,
        ricks
    )


@pytest.fixture
def erc721_factory(contract_defs, erc721_init):
    account_def, erc721_def, erc721_holder_def, unsupported_def, erc20_def, stakingpool_def, ricks_def = contract_defs
    state, owner, account1, account2, erc721, erc721_holder, unsupported,  erc20Stake, stakingPool, erc20Reward, ricks = erc721_init
    _state = state.copy()
    account1 = cached_contract(_state, account_def, account1)
    account2 = cached_contract(_state, account_def, account2)
    erc721 = cached_contract(_state, erc721_def, erc721)
    erc721_holder = cached_contract(_state, erc721_holder_def, erc721_holder)
    unsupported = cached_contract(_state, unsupported_def, unsupported)
    erc20Stake = cached_contract(_state, erc20_def, erc20Stake)
    erc20Reward = cached_contract(_state, erc20_def, erc20Reward)
    stakingPool = cached_contract(_state, stakingpool_def, stakingPool)
    ricks = cached_contract(_state, ricks_def, ricks)

    return erc721, owner, account1, account2, erc721_holder, unsupported, erc20Stake, erc20Reward, stakingPool, ricks


# Note that depending on what's being tested, test cases alternate between
# accepting `erc721_minted`, `erc721_factory`, and `erc721_unsupported` fixtures
@pytest.fixture
async def erc721_minted(erc721_factory):
    erc721, owner, account, account2, erc721_holder, _ = erc721_factory
    # mint tokens to account
    for token in TOKENS:
        await signer.send_transaction(
            account, erc721.contract_address, 'mint', [
                account.contract_address, *to_uint(token)]
        )

    return erc721, account, account2, erc721_holder


@pytest.mark.asyncio
async def test_constructor(erc721_factory):
    erc721, _, _, _, _, _, _, _, _, _ = erc721_factory
    execution_info = await erc721.name().invoke()
    assert execution_info.result == (str_to_felt("Non Fungible Token"),)

    execution_info = await erc721.symbol().invoke()
    assert execution_info.result == (str_to_felt("NFT"),)
