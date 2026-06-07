// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IBasketOracle} from "./interfaces/IBasketOracle.sol";
import {IReserveManager} from "./interfaces/IReserveManager.sol";
import {FixedPointMath} from "./libraries/FixedPointMath.sol";
import {InvalidCollateralRatio, Unauthorized} from "./libraries/Errors.sol";
import {ReservesUpdated} from "./libraries/Events.sol";

contract ReserveManager is AccessControl, IReserveManager {
    bytes32 public constant RESERVE_UPDATER_ROLE = keccak256("RESERVE_UPDATER_ROLE");
    bytes32 public constant PROTOCOL_ROLE = keccak256("PROTOCOL_ROLE");

    uint256 public constant TARGET_COLLATERAL_RATIO_BPS = 10_500;
    uint256 public constant MIN_COLLATERAL_RATIO_BPS = 10_200;

    IBasketOracle public immutable oracle;
    Reserves public reserves;
    Haircuts public haircuts;

    constructor(address admin, IBasketOracle oracle_) {
        oracle = oracle_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(RESERVE_UPDATER_ROLE, admin);
        haircuts = Haircuts({goldBps: 500, usdBps: 100, cnyBps: 800, eurBps: 200, brickBps: 2_000});
    }

    function updateMockReserves(Reserves calldata newReserves) external onlyRole(RESERVE_UPDATER_ROLE) {
        reserves = newReserves;
        emit ReservesUpdated(haircutAdjustedReserveValue(), block.timestamp);
    }

    function updateHaircuts(Haircuts calldata newHaircuts) external onlyRole(RESERVE_UPDATER_ROLE) {
        if (
            newHaircuts.goldBps > FixedPointMath.BPS || newHaircuts.usdBps > FixedPointMath.BPS
                || newHaircuts.cnyBps > FixedPointMath.BPS || newHaircuts.eurBps > FixedPointMath.BPS
                || newHaircuts.brickBps > FixedPointMath.BPS
        ) revert InvalidCollateralRatio();
        haircuts = newHaircuts;
        emit ReservesUpdated(haircutAdjustedReserveValue(), block.timestamp);
    }

    function setProtocol(address protocol, bool enabled) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (enabled) _grantRole(PROTOCOL_ROLE, protocol);
        else _revokeRole(PROTOCOL_ROLE, protocol);
    }

    function rawReserveValue() public view returns (uint256) {
        IBasketOracle.Prices memory p = oracle.getPrices();
        return FixedPointMath.mulWad(reserves.gold, p.goldUsd) + FixedPointMath.mulWad(reserves.usd, p.usdUsd)
            + FixedPointMath.mulWad(reserves.cny, p.cnyUsd) + FixedPointMath.mulWad(reserves.eur, p.eurUsd)
            + FixedPointMath.mulWad(reserves.brick, p.brickUsd);
    }

    function haircutAdjustedReserveValue() public view returns (uint256) {
        IBasketOracle.Prices memory p = oracle.getPrices();
        return _adjusted(reserves.gold, p.goldUsd, haircuts.goldBps) + _adjusted(reserves.usd, p.usdUsd, haircuts.usdBps)
            + _adjusted(reserves.cny, p.cnyUsd, haircuts.cnyBps) + _adjusted(reserves.eur, p.eurUsd, haircuts.eurBps)
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
        uint256 raw = rawReserveValue();
        if (raw == 0 || value == 0) return;
        uint256 bps = value >= raw ? FixedPointMath.BPS : value * FixedPointMath.BPS / raw;
        reserves.gold -= FixedPointMath.applyBps(reserves.gold, bps);
        reserves.usd -= FixedPointMath.applyBps(reserves.usd, bps);
        reserves.cny -= FixedPointMath.applyBps(reserves.cny, bps);
        reserves.eur -= FixedPointMath.applyBps(reserves.eur, bps);
        reserves.brick -= FixedPointMath.applyBps(reserves.brick, bps);
        emit ReservesUpdated(haircutAdjustedReserveValue(), block.timestamp);
    }

    function _adjusted(uint256 amount, uint256 price, uint256 haircutBps) private pure returns (uint256) {
        uint256 raw = FixedPointMath.mulWad(amount, price);
        return raw * (FixedPointMath.BPS - haircutBps) / FixedPointMath.BPS;
    }
}
