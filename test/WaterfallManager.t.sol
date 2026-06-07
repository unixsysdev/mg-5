// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";

contract WaterfallManagerTest is BaseTest {
    function testAvailableLiquidityAndLayers() public view {
        assertEq(waterfall.availableImmediateLiquidity(), 80_000e18);
        assertEq(waterfall.selectDefenseLayer(1_000e18), waterfall.LAYER_DEX_LIQUIDITY());
        assertEq(waterfall.selectDefenseLayer(30_000e18), waterfall.LAYER_FEE_BUFFER());
        assertEq(waterfall.selectDefenseLayer(70_000e18), waterfall.LAYER_WAR_CHEST());
        assertEq(waterfall.selectDefenseLayer(250_000e18), waterfall.LAYER_RESERVE_LIQUIDATION());
    }

    function testWarChestDrawLimit() public {
        vm.prank(admin);
        waterfall.drawWarChest(5_000e18);
        vm.prank(admin);
        vm.expectRevert();
        waterfall.drawWarChest(1e18);
    }
}
