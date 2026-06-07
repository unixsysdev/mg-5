// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";
import {Unauthorized} from "../src/libraries/Errors.sol";

contract MG5TokenTest is BaseTest {
    function testDeploysTokens() public view {
        assertEq(mg5.totalSupply(), 0);
        assertEq(mgs.totalSupply(), 0);
    }

    function testOnlyMinterCanMintMG5() public {
        vm.expectRevert(Unauthorized.selector);
        mg5.mint(user, 1e18);
        mintForUser(10_000e18);
        assertGt(mg5.balanceOf(user), 0);
    }

    function testOnlyProtocolCanBurnMG5() public {
        mintForUser(1_000e18);
        vm.expectRevert(Unauthorized.selector);
        mg5.burnFrom(user, 1e18);
    }
}
