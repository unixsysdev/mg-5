// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "./Base.t.sol";
import { IReserveManager } from "../src/interfaces/IReserveManager.sol";

contract ReserveManagerTest is BaseTest {
    function testReserveUpdateAndValues() public {
        vm.prank(admin);
        reserves.updateMockReserves(
            IReserveManager.Reserves(100e18, 100e18, 100e18, 100e18, 100e18)
        );
        assertEq(reserves.rawReserveValue(), 500e18);
        assertEq(reserves.haircutAdjustedReserveValue(), 464e18);
    }

    function testHaircutUpdateAffectsCollateralRatio() public {
        mintForUser(10_000e18);
        uint256 beforeRatio = reserves.collateralRatioBps(mg5.totalSupply(), oracle.getNAV());
        vm.prank(admin);
        reserves.updateHaircuts(IReserveManager.Haircuts(1_000, 1_000, 1_000, 1_000, 1_000));
        uint256 afterRatio = reserves.collateralRatioBps(mg5.totalSupply(), oracle.getNAV());
        assertTrue(afterRatio < beforeRatio);
    }

    function testLiquidityPriorityRedemptionUsesUsdFirst() public {
        IReserveManager.Reserves memory deposit = basketDeposit(10_000e18);
        approveReserveAssets(user, 10_000e18);
        vm.prank(user);
        mintRedeem.mintMG5WithReserves(deposit, 0);
        uint256 beforeUsd = usdAsset.balanceOf(user);
        uint256 beforeGold = goldAsset.balanceOf(user);

        vm.prank(admin);
        reserves.setRedemptionPolicy(IReserveManager.RedemptionPolicy.LiquidityPriority);
        vm.prank(user);
        mintRedeem.redeemMG5(1_000e18, 0);

        assertGt(usdAsset.balanceOf(user), beforeUsd);
        assertEq(goldAsset.balanceOf(user), beforeGold);
    }
}
