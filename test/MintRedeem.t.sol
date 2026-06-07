// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";
import {IReserveManager} from "../src/interfaces/IReserveManager.sol";
import {PostMintUndercollateralized, RedemptionQueueRequired} from "../src/libraries/Errors.sol";

contract MintRedeemTest is BaseTest {
    function testHealthyMintSucceedsAndFeeEntersBuffer() public {
        mintForUser(1_000e18);
        assertEq(mg5.balanceOf(user), 999e18);
        assertEq(mintRedeem.feeBuffer(), 1e18);
    }

    function testMintFailsBelowTargetCollateral() public {
        vm.prank(admin);
        reserves.updateMockReserves(IReserveManager.Reserves(1e18, 1e18, 1e18, 1e18, 1e18));
        vm.prank(user);
        vm.expectRevert(PostMintUndercollateralized.selector);
        mintRedeem.mintMG5(1_000e18, 0);
    }

    function testHealthyRedemptionSucceedsAndFeeEntersBuffer() public {
        mintForUser(10_000e18);
        vm.prank(user);
        mintRedeem.redeemMG5(1_000e18, 0);
        assertEq(mintRedeem.feeBuffer(), 10e18 + 2e18);
    }

    function testRedemptionQueueRequiredUnderStress() public {
        mintForUser(850_000e18);
        vm.prank(admin);
        reserves.updateMockReserves(IReserveManager.Reserves(160_000e18, 280_000e18, 200_000e18, 80_000e18, 80_000e18));
        vm.prank(user);
        vm.expectRevert(RedemptionQueueRequired.selector);
        mintRedeem.redeemMG5(700_000e18, 0);
    }
}
