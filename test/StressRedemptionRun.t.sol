// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "./Base.t.sol";

contract StressRedemptionRunTest is BaseTest {
    function testTwentyPercentRedemptionRunSurvives() public {
        mintForUser(500_000e18);
        vm.prank(user);
        mintRedeem.redeemMG5(100_000e18, 0);
        assertGe(
            reserves.collateralRatioBps(mg5.totalSupply(), oracle.getNAV()),
            reserves.MIN_COLLATERAL_RATIO_BPS()
        );
    }

    function testFortyPercentRunMovesToQueueWhenUnsafe() public {
        mintForUser(850_000e18);
        vm.startPrank(user);
        mg5.approve(address(queue), 340_000e18);
        queue.requestRedemption(340_000e18);
        vm.stopPrank();
        assertEq(queue.pendingCount(), 1);
    }
}
