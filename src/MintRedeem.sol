// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MG5Token } from "./MG5Token.sol";
import { BasketOracle } from "./BasketOracle.sol";
import { ReserveManager } from "./ReserveManager.sol";
import { IReserveManager } from "./interfaces/IReserveManager.sol";
import { FixedPointMath } from "./libraries/FixedPointMath.sol";
import {
    MintPaused,
    RedeemPaused,
    OracleFrozen,
    OracleStale,
    PostMintUndercollateralized,
    PostRedeemUndercollateralized,
    RedemptionQueueRequired,
    SlippageExceeded,
    Unauthorized,
    InvalidReserveAsset,
    InvalidReserveDeposit
} from "./libraries/Errors.sol";
import { ReserveDepositReceived, StableMinted, StableRedeemed } from "./libraries/Events.sol";

contract MintRedeem is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

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

    constructor(address admin, MG5Token mg5_, BasketOracle oracle_, ReserveManager reserveManager_)
        Ownable(admin)
    {
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

    function mintMG5(uint256 depositValue, uint256 minMg5Out) external nonReentrant {
        uint256 nav = _preMintNav();
        _mintAgainstDepositValue(depositValue, minMg5Out, nav);
    }

    function mintMG5WithReserves(IReserveManager.Reserves calldata deposit, uint256 minMg5Out)
        external
        nonReentrant
    {
        uint256 nav = _preMintNav();
        uint256 depositValue = reserveManager.valueOfReserves(deposit);
        if (depositValue == 0) revert InvalidReserveDeposit();
        _pullReserveAssets(deposit);
        reserveManager.increaseReserves(deposit);
        emit ReserveDepositReceived(
            msg.sender, depositValue, reserveManager.adjustedValueOfReserves(deposit)
        );
        _mintAgainstDepositValue(depositValue, minMg5Out, nav);
    }

    function redeemMG5(uint256 mg5Amount, uint256 minValueOut) external nonReentrant {
        _redeemTo(msg.sender, msg.sender, mg5Amount, minValueOut, false);
    }

    function processQueuedRedemption(address user, uint256 mg5Amount, uint256 minValueOut)
        external
        nonReentrant
        returns (uint256 valueOut)
    {
        if (msg.sender != redemptionQueue) revert Unauthorized();
        return _redeemTo(redemptionQueue, user, mg5Amount, minValueOut, true);
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

    function _preMintNav() internal view returns (uint256) {
        if (mintPaused) revert MintPaused();
        return _checkedNav();
    }

    function _mintAgainstDepositValue(uint256 depositValue, uint256 minMg5Out, uint256 nav)
        internal
    {
        uint256 mintFee = FixedPointMath.applyBps(depositValue, mintFeeBps);
        uint256 netDeposit = depositValue - mintFee;
        uint256 mg5Out = FixedPointMath.divWad(netDeposit, nav);
        if (mg5Out < minMg5Out) revert SlippageExceeded();

        uint256 postSupply = mg5.totalSupply() + mg5Out;
        if (
            reserveManager.collateralRatioBps(postSupply, nav)
                < reserveManager.TARGET_COLLATERAL_RATIO_BPS()
        ) {
            revert PostMintUndercollateralized();
        }

        feeBuffer += mintFee;
        totalMockDeposits += depositValue;
        mg5.mint(msg.sender, mg5Out);
        emit StableMinted(msg.sender, depositValue, mg5Out);
    }

    function _redeemTo(
        address burnFrom,
        address reserveRecipient,
        uint256 mg5Amount,
        uint256 minValueOut,
        bool queued
    ) internal returns (uint256 valueOut) {
        if (redeemPaused) revert RedeemPaused();
        uint256 nav = _checkedNav();
        (uint256 grossValue, uint256 redeemFee, uint256 netValue) = quoteRedemption(mg5Amount, nav);
        if (netValue < minValueOut) revert SlippageExceeded();
        if (!_canRedeem(mg5.totalSupply() - mg5Amount, nav, netValue)) {
            if (queued) revert PostRedeemUndercollateralized();
            revert RedemptionQueueRequired();
        }

        mg5.burnFrom(burnFrom, mg5Amount);
        reserveManager.releaseReserves(reserveRecipient, netValue);
        feeBuffer += redeemFee;
        emit StableRedeemed(reserveRecipient, mg5Amount, netValue);
        grossValue;
        return netValue;
    }

    function _checkedNav() internal view returns (uint256) {
        if (oracle.getPrices().frozen) revert OracleFrozen();
        if (oracle.isStale()) revert OracleStale();
        return oracle.getNAV();
    }

    function _pullReserveAssets(IReserveManager.Reserves calldata deposit) internal {
        (
            address goldAsset,
            address usdAsset,
            address cnyAsset,
            address eurAsset,
            address brickAsset
        ) = reserveManager.reserveAssets();
        _pullAsset(goldAsset, deposit.gold);
        _pullAsset(usdAsset, deposit.usd);
        _pullAsset(cnyAsset, deposit.cny);
        _pullAsset(eurAsset, deposit.eur);
        _pullAsset(brickAsset, deposit.brick);
    }

    function _pullAsset(address asset, uint256 amount) internal {
        if (amount == 0) return;
        if (asset == address(0)) revert InvalidReserveAsset();
        IERC20(asset).safeTransferFrom(msg.sender, address(reserveManager), amount);
    }

    function _canRedeem(uint256 postSupply, uint256 nav, uint256 netValue)
        internal
        view
        returns (bool)
    {
        uint256 adjusted = reserveManager.haircutAdjustedReserveValue();
        if (adjusted < netValue) return false;
        uint256 postAdjusted = adjusted - netValue;
        uint256 postLiability = FixedPointMath.mulWad(postSupply, nav);
        if (postLiability == 0) return true;
        return postAdjusted * FixedPointMath.BPS / postLiability
            >= reserveManager.MIN_COLLATERAL_RATIO_BPS();
    }
}
