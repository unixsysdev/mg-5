// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";
import {InvalidPrice, OracleFrozen, OracleStale} from "../src/libraries/Errors.sol";

contract BasketOracleTest is BaseTest {
    function testValidPriceUpdateAndNav() public {
        vm.prank(admin);
        oracle.updatePrices(1e18, 1e18, 1e18, 1e18, 1e18);
        assertEq(oracle.getNAV(), 1e18);
    }

    function testZeroPriceRejected() public {
        vm.prank(admin);
        vm.expectRevert(InvalidPrice.selector);
        oracle.updatePrices(0, 1e18, 1e18, 1e18, 1e18);
    }

    function testFrozenOracleBlocksMint() public {
        vm.prank(admin);
        oracle.freezeOracle();
        vm.prank(user);
        vm.expectRevert(OracleFrozen.selector);
        mintRedeem.mintMG5(1_000e18, 0);
    }

    function testStaleOracleBlocksMint() public {
        vm.warp(block.timestamp + 301);
        vm.prank(user);
        vm.expectRevert(OracleStale.selector);
        mintRedeem.mintMG5(1_000e18, 0);
    }
}
