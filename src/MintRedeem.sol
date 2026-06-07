// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MG5Token} from "./MG5Token.sol";
import {BasketOracle} from "./BasketOracle.sol";
import {ReserveManager} from "./ReserveManager.sol";
import {FixedPointMath} from "./libraries/FixedPointMath.sol";
import {
    MintPaused,
    RedeemPaused,
    OracleFrozen,
    OracleStale,
    PostMintUndercollateralized,
    PostRedeemUndercollateralized,
    RedemptionQueueRequired,
    SlippageExceeded,
    Unauthorized
} from "./libraries/Errors.sol";
import {StableMinted, StableRedeemed} from "./libraries/Events.sol";

contract MintRedeem is Ownable {
    MG5Token public immutable mg5;
    BasketOracle public immutable oracle;
    ReserveManager public immutable reserveManager;

    uint256 public mintFeeBps = 10;
    uint256 public redeemFeeBps = 20;
    uint256 public feeBuffer;
    uint256 public totalMockDeposits;
    bool public mintPaused;
    bool public redeemPaused;
    address public redemptionQueue;
    address public circuitBreaker;

    constructor(address admin, MG5Token mg5_, BasketOracle oracle_, ReserveManager reserveManager_) Ownable(admin) {
        mg5 = mg5_;
        oracle = oracle_;
        reserveManager = reserveManager_;
    }

    function setRedemptionQueue(address queue) external onlyOwner {
        redemptionQueue = queue;
    }

    function setCircuitBreaker(address circuitBreaker_) external onlyOwner {
        circuitBreaker = circuitBreaker_;
    }

    function setFees(uint256 mintFeeBps_, uint256 redeemFeeBps_) external onlyOwner {
        mintFeeBps = mintFeeBps_;
        redeemFeeBps = redeemFeeBps_;
    }

    function setPaused(bool mintPaused_, bool redeemPaused_) external onlyOwner {
        _setPaused(mintPaused_, redeemPaused_);
    }

    function setPausedByCircuitBreaker(bool mintPaused_, bool redeemPaused_) external {
        if (msg.sender != circuitBreaker) revert Unauthorized();
        _setPaused(mintPaused_, redeemPaused_);
    }

    function _setPaused(bool mintPaused_, bool redeemPaused_) internal {
        mintPaused = mintPaused_;
        redeemPaused = redeemPaused_;
    }

    function mintMG5(uint256 depositValue, uint256 minMg5Out) external {
        if (mintPaused) revert MintPaused();
        uint256 nav = _checkedNav();
        uint256 mintFee = FixedPointMath.applyBps(depositValue, mintFeeBps);
        uint256 netDeposit = depositValue - mintFee;
        uint256 mg5Out = FixedPointMath.divWad(netDeposit, nav);
        if (mg5Out < minMg5Out) revert SlippageExceeded();

        uint256 postSupply = mg5.totalSupply() + mg5Out;
        if (reserveManager.collateralRatioBps(postSupply, nav) < reserveManager.TARGET_COLLATERAL_RATIO_BPS()) {
            revert PostMintUndercollateralized();
        }

        feeBuffer += mintFee;
        totalMockDeposits += depositValue;
        mg5.mint(msg.sender, mg5Out);
        emit StableMinted(msg.sender, depositValue, mg5Out);
    }

    function redeemMG5(uint256 mg5Amount, uint256 minValueOut) external {
        if (redeemPaused) revert RedeemPaused();
        uint256 nav = _checkedNav();
        (uint256 grossValue, uint256 redeemFee, uint256 netValue) = quoteRedemption(mg5Amount, nav);
        if (netValue < minValueOut) revert SlippageExceeded();
        if (!_canRedeem(mg5.totalSupply() - mg5Amount, nav, netValue)) {
            revert RedemptionQueueRequired();
        }

        mg5.burnFrom(msg.sender, mg5Amount);
        reserveManager.reduceReservesProRata(netValue);
        feeBuffer += redeemFee;
        emit StableRedeemed(msg.sender, mg5Amount, netValue);
        grossValue;
    }

    function processQueuedRedemption(address user, uint256 mg5Amount, uint256 minValueOut)
        external
        returns (uint256 valueOut)
    {
        if (msg.sender != redemptionQueue) revert Unauthorized();
        uint256 nav = _checkedNav();
        (, uint256 redeemFee, uint256 netValue) = quoteRedemption(mg5Amount, nav);
        if (netValue < minValueOut) revert SlippageExceeded();
        if (!_canRedeem(mg5.totalSupply() - mg5Amount, nav, netValue)) {
            revert PostRedeemUndercollateralized();
        }
        mg5.burnFrom(redemptionQueue, mg5Amount);
        reserveManager.reduceReservesProRata(netValue);
        feeBuffer += redeemFee;
        emit StableRedeemed(user, mg5Amount, netValue);
        return netValue;
    }

    function quoteRedemption(uint256 mg5Amount, uint256 nav)
        public
        view
        returns (uint256 grossValue, uint256 redeemFee, uint256 netValue)
    {
        grossValue = FixedPointMath.mulWad(mg5Amount, nav);
        redeemFee = FixedPointMath.applyBps(grossValue, redeemFeeBps);
        netValue = grossValue - redeemFee;
    }

    function checkedNav() external view returns (uint256) {
        return _checkedNav();
    }

    function _checkedNav() internal view returns (uint256) {
        if (oracle.getPrices().frozen) revert OracleFrozen();
        if (oracle.isStale()) revert OracleStale();
        return oracle.getNAV();
    }

    function _canRedeem(uint256 postSupply, uint256 nav, uint256 netValue) internal view returns (bool) {
        uint256 adjusted = reserveManager.haircutAdjustedReserveValue();
        if (adjusted < netValue) return false;
        uint256 postAdjusted = adjusted - netValue;
        uint256 postLiability = FixedPointMath.mulWad(postSupply, nav);
        if (postLiability == 0) return true;
        return postAdjusted * FixedPointMath.BPS / postLiability >= reserveManager.MIN_COLLATERAL_RATIO_BPS();
    }
}
