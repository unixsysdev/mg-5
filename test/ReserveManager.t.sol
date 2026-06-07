// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";
import {IReserveManager} from "../src/interfaces/IReserveManager.sol";

contract ReserveManagerTest is BaseTest {
    function testReserveUpdateAndValues() public {
        vm.prank(admin);
        reserves.updateMockReserves(IReserveManager.Reserves(100e18, 100e18, 100e18, 100e18, 100e18));
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
}
