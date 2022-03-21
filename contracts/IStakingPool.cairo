%lang starknet

from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace IStakingPool:
    func stake(amount : Uint256) -> (success : felt):
    end
    func unstake_claim_rewards() -> (success : felt):
    end
    func deposit_reward(amount : Uint256) -> (success : felt):
    end
end
