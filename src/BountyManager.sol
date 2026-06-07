// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { MGSToken } from "./MGSToken.sol";
import { BountyDoesNotImprovePeg, BountyRewardTooLarge } from "./libraries/Errors.sol";
import { BountyClaimed } from "./libraries/Events.sol";

contract BountyManager is AccessControl {
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    uint256 public bountyThresholdBps = 50;
    uint256 public maxReward = 1_000e18;
    uint256 public rewardPerBpsImproved = 10e18;
    uint256 public rewardBudget = 1_000_000e18;
    MGSToken public immutable mgs;

    constructor(address admin, MGSToken mgs_) {
        mgs = mgs_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(KEEPER_ROLE, admin);
    }

    function claimRebalanceBounty(uint256 deviationBeforeBps, uint256 deviationAfterBps) external {
        if (deviationBeforeBps <= bountyThresholdBps || deviationAfterBps >= deviationBeforeBps) {
            revert BountyDoesNotImprovePeg();
        }
        uint256 reward = (deviationBeforeBps - deviationAfterBps) * rewardPerBpsImproved;
        if (reward > maxReward) reward = maxReward;
        if (reward > rewardBudget) revert BountyRewardTooLarge();
        rewardBudget -= reward;
        mgs.mint(msg.sender, reward);
        emit BountyClaimed(msg.sender, reward);
    }
}
