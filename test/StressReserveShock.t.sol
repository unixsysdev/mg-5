// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";
import {IReserveManager} from "../src/interfaces/IReserveManager.sol";

contract StressReserveShockTest is BaseTest {
    function testSleevePriceShocksReduceNav() public {
        uint256 beforeNav = oracle.getNAV();
        vm.prank(admin);
        oracle.updatePrices(0.85e18, 1e18, 0.90e18, 0.90e18, 0.70e18);
        assertTrue(oracle.getNAV() < beforeNav);
    }

    function testReserveHaircutIncreaseReducesCollateralRatio() public {
        mintForUser(500_000e18);
        uint256 beforeRatio = reserves.collateralRatioBps(mg5.totalSupply(), oracle.getNAV());
        vm.prank(admin);
        reserves.updateHaircuts(IReserveManager.Haircuts(1_500, 500, 1_500, 1_000, 3_000));
        assertTrue(reserves.collateralRatioBps(mg5.totalSupply(), oracle.getNAV()) < beforeRatio);
    }

    function testFeeBufferAndWarChestDepletionRemainBounded() public {
        mintForUser(10_000e18);
        vm.prank(admin);
        waterfall.drawWarChest(5_000e18);
        assertGe(mintRedeem.feeBuffer(), 0);
        assertGe(waterfall.warChest(), 0);
    }
}
