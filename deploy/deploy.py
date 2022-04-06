from nile.core.account import Account
import os

os.environ["SIGNER"] = "123456"
#os.environ["SIGNER"] = "123456"
RECV_ACCOUNTS = []

TEST_REWARD_TOKEN_ADDRESS = 0x07394cbe418daa16e42b87ba67372d4ab4a5df0b05c6e554d158458ce245bc10
TEST_721_TOKEN_ADDRESS = 0x03a0dbc41c598ca8a59e16c2c2aa3b6f4c82ab62331d91a5df4af3eb18156122

# The above contracts have already been deployed to make testing the contracts easier.
# TEST_REWARD_TOKEN_ADDRESS is the address of TEST token already deployed with Argentx wallet. You should be able to mint as many tokens as want. Lets mint 1000000 tokens
# TEST_721_TOKEN_ADDRESS is just a simple ERC721 contract that I have deployed with simple modification to make it easier to mint to any address.

# Steps
# Make mutiple accounts in Argentx wallet to simulate different bidders bidding on the shard of NFTs
# Mint 1000000 Test tokens in every account your Argentx wallet.
# Compile/Build using the command 'nile compile' from project root directory
# Deploy by running 'nile run deploy/deploy.py --network goerli'. This will deploy the staking contract and the main ricks contract on the goerli network and return you the addresses.
# Give approval/allowance to the ricks contract for all your TEST tokens, since there is no native currency we will have to simulate the payments via this test token
# using https://goerli.voyager.online/ mint a new token with TokenID = 54387 (or update the TOKEN_ID below)
# Give approval to the ricks contract for the new minted token.
# On the ricks contract call the 'activate' method and give it the erc721 contract address and the ID that you are fractionalyzing.
# Now you can start the auction with a start_auction with a bid amount.
# Any other account/user can also bid by calling the 'bid' method.
# Any user can end the bidding by calling end_auction.
# Who ever is the winner will get new 'RICKS' token and which will be deposited in staking contract.
# Losing bids will have their bid refunded.
# Any users can buyout other shards at any point by paying a premium propeortional to his unowned fraction of the total supply


INITIAL_RICKS_SUPPLY = 100
DAILY_INFLATION_RATE = 50
AUCTION_LENGTH = 10800  # 3 hours = 10800
AUCTION_INTERVAL = 0  # 1 day = 86400
MIN_BID_INCREASE = 50
TOKEN_ID = 54387  #


def str_to_felt(text):
    b_text = bytes(text, "ascii")
    return int.from_bytes(b_text, "big")


def felt_to_str(felt):
    b_felt = felt.to_bytes(31, "big")
    return b_felt.decode()


def run(nre):
    felt721 = str_to_felt("Test721")
    ricks = str_to_felt("ricks")
    signer = Account("SIGNER", nre.network)

    print(f"Signer account: {signer}")
    print(f"Network: {nre.network}")
    # print(f"OSEnviron: {os.environ}")
    # print(f" felt721 is  {felt721} and signer address is {signer.address}")

    # test721Impl, test721abi = nre.deploy(
    #     "Test721", arguments=[f'{felt721}', f'{felt721}', f'{signer.address}'], alias="Test721")
    # print(f"Deployed test 721 to {test721Impl}")

    stakingpool_impl, abi = nre.deploy(
        "stakingpool", arguments=[], alias="stakingpool")
    print(f"Deployed stakingpool_impl to {stakingpool_impl}")

    # ricks = await starknet.deploy(
    #     contract_def=ricks_def,
    #     constructor_calldata=[
    #         str_to_felt("RICKS"),      # name
    #         str_to_felt("RCK"),        # symbol
    #         18,                        # decimals
    #         INITIAL_RICKS_SUPPLY,               # initial_supply
    #         erc721.contract_address,
    #         TOKEN,
    #         DAILY_INFLATION_RATE,
    #         stakingPool.contract_address,
    #         erc20Weth.contract_address
    #     ]
    # )

    ricks_impl, abi = nre.deploy(
        "ricks", arguments=[f'{ricks}', f'{ricks}', f'{18}', f'{INITIAL_RICKS_SUPPLY}', f'{DAILY_INFLATION_RATE}', f'{AUCTION_LENGTH}', f'{AUCTION_INTERVAL}', f'{MIN_BID_INCREASE}', f'{stakingpool_impl}', f'{TEST_REWARD_TOKEN_ADDRESS}'], alias="ricks")
    print(f"Deployed ricks_impl to {ricks_impl}")

    # erc721_impl, abi = nre.deploy(
    #     "weth", arguments=[], alias="mytoken")
    # print(f"Deployed stakingpool_impl to {stakingpool_impl}")

    # stakingpool_impl, abi = nre.deploy(
    #     "stakingpool", arguments=[], alias="stakingpool")
    # print(f"Deployed stakingpool_impl to {stakingpool_impl}")

    # nre.invoke
