// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { BaseTest } from "./Base.t.sol";
import { BasketMath } from "../src/libraries/BasketMath.sol";
import { IReserveManager } from "../src/interfaces/IReserveManager.sol";

contract InvariantsTest is BaseTest {
    function testBasketWeightsSumTo10000() public pure {
        assertEq(
            BasketMath.GOLD_BPS + BasketMath.USD_BPS + BasketMath.CNY_BPS + BasketMath.EUR_BPS
                + BasketMath.BRICK_BPS,
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

    function testFuzzCollateralizedMintNeverBelowTarget(uint96 rawAmount) public {
        uint256 depositValue = bound(uint256(rawAmount), 1_000e18, 200_000e18);
        approveReserveAssets(user, depositValue);
        vm.prank(user);
        mintRedeem.mintMG5WithReserves(basketDeposit(depositValue), 0);

        assertGe(
            reserves.collateralRatioBps(mg5.totalSupply(), oracle.getNAV()),
            reserves.TARGET_COLLATERAL_RATIO_BPS()
        );
    }

    function testFuzzRedemptionEitherProcessesSafelyOrQueues(uint96 rawDeposit, uint96 rawRedeem)
        public
    {
        uint256 depositValue = bound(uint256(rawDeposit), 10_000e18, 500_000e18);
        approveReserveAssets(user, depositValue);
        vm.prank(user);
        mintRedeem.mintMG5WithReserves(basketDeposit(depositValue), 0);

        uint256 balance = mg5.balanceOf(user);
        uint256 redeemAmount = bound(uint256(rawRedeem), 1e18, balance);
        vm.prank(user);
        try mintRedeem.redeemMG5(redeemAmount, 0) {
            if (mg5.totalSupply() > 0) {
                assertGe(
                    reserves.collateralRatioBps(mg5.totalSupply(), oracle.getNAV()),
                    reserves.MIN_COLLATERAL_RATIO_BPS()
                );
            }
        } catch {
            vm.startPrank(user);
            mg5.approve(address(queue), redeemAmount);
            queue.requestRedemption(redeemAmount);
            vm.stopPrank();
            assertGt(queue.pendingCount(), 0);
        }
    }

    function testFuzzHaircutShockCannotCreateUnsafeMint(uint96 rawAmount, uint16 haircutBps)
        public
    {
        uint256 depositValue = bound(uint256(rawAmount), 10_000e18, 150_000e18);
        uint256 shock = bound(uint256(haircutBps), 2_000, 9_000);
        vm.prank(admin);
        reserves.updateHaircuts(
            IReserveManager.Haircuts(
                uint256(shock), uint256(shock), uint256(shock), uint256(shock), uint256(shock)
            )
        );

        approveReserveAssets(user, depositValue);
        vm.prank(user);
        try mintRedeem.mintMG5WithReserves(basketDeposit(depositValue), 0) {
            assertGe(
                reserves.collateralRatioBps(mg5.totalSupply(), oracle.getNAV()),
                reserves.TARGET_COLLATERAL_RATIO_BPS()
            );
        } catch {
            assertEq(mg5.balanceOf(user), 0);
        }
    }
}
