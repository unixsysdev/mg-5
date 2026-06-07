// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "./Base.t.sol";
import { IReserveManager } from "../src/interfaces/IReserveManager.sol";

contract CircuitBreakerTest is BaseTest {
    function testTriggerOnStaleOracle() public {
        vm.warp(block.timestamp + 301);
        circuitBreaker.triggerIfOracleStale();
        assertTrue(circuitBreaker.triggered());
    }

    function testTriggerOnFrozenOracle() public {
        vm.prank(admin);
        oracle.freezeOracle();
        circuitBreaker.triggerIfOracleStale();
        assertTrue(circuitBreaker.triggered());
    }

    function testTriggerOnLowCollateralRatio() public {
        mintForUser(800_000e18);
        vm.prank(admin);
        reserves.updateMockReserves(IReserveManager.Reserves(1e18, 1e18, 1e18, 1e18, 1e18));
        circuitBreaker.triggerIfUndercollateralized();
        assertTrue(circuitBreaker.triggered());
    }

    function testPauseAndClear() public {
        vm.prank(admin);
        circuitBreaker.pauseAll();
        assertTrue(mintRedeem.mintPaused());
        vm.prank(admin);
        circuitBreaker.clearCircuitBreaker();
        assertFalse(mintRedeem.mintPaused());
    }
}
