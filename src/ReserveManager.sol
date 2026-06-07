// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IBasketOracle } from "./interfaces/IBasketOracle.sol";
import { IReserveManager } from "./interfaces/IReserveManager.sol";
import { FixedPointMath } from "./libraries/FixedPointMath.sol";
import { InvalidCollateralRatio } from "./libraries/Errors.sol";
import {
    RedemptionPolicyUpdated,
    ReserveAssetsConfigured,
    ReserveAssetsReleased,
    ReservesUpdated
} from "./libraries/Events.sol";

contract ReserveManager is AccessControl, IReserveManager {
    using SafeERC20 for IERC20;

    bytes32 public constant RESERVE_UPDATER_ROLE = keccak256("RESERVE_UPDATER_ROLE");
    bytes32 public constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");

    uint256 public constant TARGET_COLLATERAL_RATIO_BPS = 10_500;
    uint256 public constant MIN_COLLATERAL_RATIO_BPS = 10_200;

    IBasketOracle public immutable oracle;
    Reserves public reserves;
    Haircuts public haircuts;
    ReserveAssets public reserveAssets;
    RedemptionPolicy public redemptionPolicy;

    constructor(address admin, IBasketOracle oracle_) {
        oracle = oracle_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RESERVE_UPDATER_ROLE, admin);
        haircuts = Haircuts({
            goldBps: 500, usdBps: 100, cnyBps: 800, eurBps: 200, brickBps: 2_000
        });
    }

    function updateMockReserves(Reserves calldata newReserves)
        external
        onlyRole(RESERVE_UPDATER_ROLE)
    {
        reserves = newReserves;
        emit ReservesUpdated(haircutAdjustedReserveValue(), block.timestamp);
    }

    function configureReserveAssets(ReserveAssets calldata assets)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        reserveAssets = assets;
        emit ReserveAssetsConfigured(assets.gold, assets.usd, assets.cny, assets.eur, assets.brick);
    }

    function setRedemptionPolicy(RedemptionPolicy policy) external onlyRole(DEFAULT_ADMIN_ROLE) {
        redemptionPolicy = policy;
        emit RedemptionPolicyUpdated(uint8(policy));
    }

    function updateHaircuts(Haircuts calldata newHaircuts) external onlyRole(RESERVE_UPDATER_ROLE) {
        if (
            newHaircuts.goldBps > FixedPointMath.BPS || newHaircuts.usdBps > FixedPointMath.BPS
                || newHaircuts.cnyBps > FixedPointMath.BPS
                || newHaircuts.eurBps > FixedPointMath.BPS
                || newHaircuts.brickBps > FixedPointMath.BPS
        ) revert InvalidCollateralRatio();
        haircuts = newHaircuts;
        emit ReservesUpdated(haircutAdjustedReserveValue(), block.timestamp);
    }

    function setProtocol(address protocol, bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (enabled) _grantRole(PROTOCOL_ROLE, protocol);
        else _revokeRole(PROTOCOL_ROLE, protocol);
    }

    function valueOfReserves(Reserves calldata reserveAmounts) public view returns (uint256) {
        IBasketOracle.Prices memory p = oracle.getPrices();
        return _value(reserveAmounts, p);
    }

    function adjustedValueOfReserves(Reserves calldata reserveAmounts)
        public
        view
        returns (uint256)
    {
        IBasketOracle.Prices memory p = oracle.getPrices();
        return _adjusted(reserveAmounts.gold, p.goldUsd, haircuts.goldBps)
            + _adjusted(reserveAmounts.usd, p.usdUsd, haircuts.usdBps)
            + _adjusted(reserveAmounts.cny, p.cnyUsd, haircuts.cnyBps)
            + _adjusted(reserveAmounts.eur, p.eurUsd, haircuts.eurBps)
            + _adjusted(reserveAmounts.brick, p.brickUsd, haircuts.brickBps);
    }

    function increaseReserves(Reserves calldata reserveAmounts) external onlyRole(PROTOCOL_ROLE) {
        reserves.gold += reserveAmounts.gold;
        reserves.usd += reserveAmounts.usd;
        reserves.cny += reserveAmounts.cny;
        reserves.eur += reserveAmounts.eur;
        reserves.brick += reserveAmounts.brick;
        emit ReservesUpdated(haircutAdjustedReserveValue(), block.timestamp);
    }

    function rawReserveValue() public view returns (uint256) {
        IBasketOracle.Prices memory p = oracle.getPrices();
        return _value(reserves, p);
    }

    function haircutAdjustedReserveValue() public view returns (uint256) {
        IBasketOracle.Prices memory p = oracle.getPrices();
        return _adjusted(reserves.gold, p.goldUsd, haircuts.goldBps)
            + _adjusted(reserves.usd, p.usdUsd, haircuts.usdBps)
            + _adjusted(reserves.cny, p.cnyUsd, haircuts.cnyBps)
            + _adjusted(reserves.eur, p.eurUsd, haircuts.eurBps)
            + _adjusted(reserves.brick, p.brickUsd, haircuts.brickBps);
    }

    function liabilities(uint256 mg5Supply, uint256 nav) external pure returns (uint256) {
        return FixedPointMath.mulWad(mg5Supply, nav);
    }

    function collateralRatioBps(uint256 mg5Supply, uint256 nav) public view returns (uint256) {
        uint256 liability = FixedPointMath.mulWad(mg5Supply, nav);
        if (liability == 0) return type(uint256).max;
        return haircutAdjustedReserveValue() * FixedPointMath.BPS / liability;
    }

    function reduceReservesProRata(uint256 value) external onlyRole(PROTOCOL_ROLE) {
        _reduceReservesProRata(value);
    }

    function releaseReservesProRata(address to, uint256 value) external onlyRole(PROTOCOL_ROLE) {
        Reserves memory released = _reduceReservesProRata(value);
        _transferReleased(to, released);
        emit ReserveAssetsReleased(to, value);
    }

    function releaseReserves(address to, uint256 value) external onlyRole(PROTOCOL_ROLE) {
        Reserves memory released = redemptionPolicy == RedemptionPolicy.LiquidityPriority
            ? _reduceReservesByLiquidityPriority(value)
            : _reduceReservesProRata(value);
        _transferReleased(to, released);
        emit ReserveAssetsReleased(to, value);
    }

    function _transferReleased(address to, Reserves memory released) private {
        _transferIfConfigured(reserveAssets.gold, to, released.gold);
        _transferIfConfigured(reserveAssets.usd, to, released.usd);
        _transferIfConfigured(reserveAssets.cny, to, released.cny);
        _transferIfConfigured(reserveAssets.eur, to, released.eur);
        _transferIfConfigured(reserveAssets.brick, to, released.brick);
    }

    function _reduceReservesProRata(uint256 value) private returns (Reserves memory released) {
        uint256 raw = rawReserveValue();
        if (raw == 0 || value == 0) return released;
        uint256 bps = value >= raw ? FixedPointMath.BPS : value * FixedPointMath.BPS / raw;
        released.gold = FixedPointMath.applyBps(reserves.gold, bps);
        released.usd = FixedPointMath.applyBps(reserves.usd, bps);
        released.cny = FixedPointMath.applyBps(reserves.cny, bps);
        released.eur = FixedPointMath.applyBps(reserves.eur, bps);
        released.brick = FixedPointMath.applyBps(reserves.brick, bps);
        reserves.gold -= released.gold;
        reserves.usd -= released.usd;
        reserves.cny -= released.cny;
        reserves.eur -= released.eur;
        reserves.brick -= released.brick;
        emit ReservesUpdated(haircutAdjustedReserveValue(), block.timestamp);
    }

    function _reduceReservesByLiquidityPriority(uint256 value)
        private
        returns (Reserves memory released)
    {
        if (value == 0) return released;
        IBasketOracle.Prices memory p = oracle.getPrices();
        uint256 remaining = value;

        (released.usd, remaining) = _takeByValue(reserves.usd, p.usdUsd, remaining);
        reserves.usd -= released.usd;
        if (remaining > 0) {
            (released.eur, remaining) = _takeByValue(reserves.eur, p.eurUsd, remaining);
            reserves.eur -= released.eur;
        }
        if (remaining > 0) {
            (released.gold, remaining) = _takeByValue(reserves.gold, p.goldUsd, remaining);
            reserves.gold -= released.gold;
        }
        if (remaining > 0) {
            (released.cny, remaining) = _takeByValue(reserves.cny, p.cnyUsd, remaining);
            reserves.cny -= released.cny;
        }
        if (remaining > 0) {
            (released.brick, remaining) = _takeByValue(reserves.brick, p.brickUsd, remaining);
            reserves.brick -= released.brick;
        }

        emit ReservesUpdated(haircutAdjustedReserveValue(), block.timestamp);
    }

    function _takeByValue(uint256 availableAmount, uint256 price, uint256 neededValue)
        private
        pure
        returns (uint256 amountTaken, uint256 remainingValue)
    {
        uint256 availableValue = FixedPointMath.mulWad(availableAmount, price);
        if (availableValue <= neededValue) return (availableAmount, neededValue - availableValue);
        amountTaken = FixedPointMath.divWad(neededValue, price);
        if (FixedPointMath.mulWad(amountTaken, price) < neededValue) amountTaken += 1;
        return (amountTaken, 0);
    }

    function _value(Reserves memory reserveAmounts, IBasketOracle.Prices memory p)
        private
        pure
        returns (uint256)
    {
        return FixedPointMath.mulWad(reserveAmounts.gold, p.goldUsd)
            + FixedPointMath.mulWad(reserveAmounts.usd, p.usdUsd)
            + FixedPointMath.mulWad(reserveAmounts.cny, p.cnyUsd)
            + FixedPointMath.mulWad(reserveAmounts.eur, p.eurUsd)
            + FixedPointMath.mulWad(reserveAmounts.brick, p.brickUsd);
    }

    function _adjusted(uint256 amount, uint256 price, uint256 haircutBps)
        private
        pure
        returns (uint256)
    {
        uint256 raw = FixedPointMath.mulWad(amount, price);
        return raw * (FixedPointMath.BPS - haircutBps) / FixedPointMath.BPS;
    }

    function _transferIfConfigured(address asset, address to, uint256 amount) private {
        if (asset == address(0) || amount == 0) return;
        IERC20(asset).safeTransfer(to, amount);
    }
}
