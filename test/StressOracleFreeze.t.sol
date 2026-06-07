// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";
import {OracleFrozen, OracleStale} from "../src/libraries/Errors.sol";

contract StressOracleFreezeTest is BaseTest {
    function testOracleFreezeBlocksNavActionsAndTriggersBreaker() public {
        vm.prank(admin);
        oracle.freezeOracle();
        vm.prank(user);
        vm.expectRevert(OracleFrozen.selector);
        mintRedeem.mintMG5(1_000e18, 0);
        circuitBreaker.triggerIfOracleStale();
        assertTrue(circuitBreaker.triggered());
    }

    function testCombinedStaleAndRedemptionRun() public {
        mintForUser(500_000e18);
        vm.warp(block.timestamp + 301);
        vm.prank(user);
        vm.expectRevert(OracleStale.selector);
        mintRedeem.redeemMG5(100_000e18, 0);
    }
}
