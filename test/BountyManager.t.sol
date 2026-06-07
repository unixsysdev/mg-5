// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "./Base.t.sol";
import { BountyDoesNotImprovePeg } from "../src/libraries/Errors.sol";

contract BountyManagerTest is BaseTest {
    function testBountyPaysMGSOnly() public {
        vm.prank(keeper);
        bounties.claimRebalanceBounty(200, 100);
        assertGt(mgs.balanceOf(keeper), 0);
        assertEq(mg5.balanceOf(keeper), 0);
    }

    function testBountyRequiresImprovement() public {
        vm.expectRevert(BountyDoesNotImprovePeg.selector);
        bounties.claimRebalanceBounty(200, 250);
    }
}
