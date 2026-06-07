// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./Base.t.sol";
import {BasketMath} from "../src/libraries/BasketMath.sol";

contract InvariantsTest is BaseTest {
    function testBasketWeightsSumTo10000() public pure {
        assertEq(
            BasketMath.GOLD_BPS + BasketMath.USD_BPS + BasketMath.CNY_BPS + BasketMath.EUR_BPS + BasketMath.BRICK_BPS,
            10_000
        );
    }

    function testMGSIsNotCollateral() public {
        vm.prank(keeper);
        bounties.claimRebalanceBounty(200, 100);
        uint256 adjustedBefore = reserves.haircutAdjustedReserveValue();
        assertGt(mgs.balanceOf(keeper), 0);
        assertEq(reserves.haircutAdjustedReserveValue(), adjustedBefore);
    }
}
