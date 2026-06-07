// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";
import {IReserveManager} from "../src/interfaces/IReserveManager.sol";
import {RedemptionAlreadyProcessed, PostRedeemUndercollateralized} from "../src/libraries/Errors.sol";

contract RedemptionQueueTest is BaseTest {
    function testRequestEscrowsAndCancelReturnsMG5() public {
        mintForUser(10_000e18);
        vm.startPrank(user);
        mg5.approve(address(queue), 1_000e18);
        uint256 id = queue.requestRedemption(1_000e18);
        assertEq(mg5.balanceOf(address(queue)), 1_000e18);
        queue.cancelRedemption(id);
        assertEq(mg5.balanceOf(address(queue)), 0);
        vm.stopPrank();
    }

    function testProcessRedemptionAndCannotProcessTwice() public {
        mintForUser(10_000e18);
        vm.startPrank(user);
        mg5.approve(address(queue), 1_000e18);
        uint256 id = queue.requestRedemption(1_000e18);
        vm.stopPrank();
        vm.prank(keeper);
        queue.processRedemption(id);
        vm.prank(keeper);
        vm.expectRevert(RedemptionAlreadyProcessed.selector);
        queue.processRedemption(id);
    }

    function testCannotProcessIfSolvencyWouldBreak() public {
        mintForUser(850_000e18);
        vm.startPrank(user);
        mg5.approve(address(queue), 700_000e18);
        uint256 id = queue.requestRedemption(700_000e18);
        vm.stopPrank();
        vm.prank(admin);
        reserves.updateMockReserves(IReserveManager.Reserves(10_000e18, 10_000e18, 10_000e18, 10_000e18, 10_000e18));
        vm.prank(keeper);
        vm.expectRevert(PostRedeemUndercollateralized.selector);
        queue.processRedemption(id);
    }
}
