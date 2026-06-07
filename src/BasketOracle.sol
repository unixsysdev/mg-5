// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IBasketOracle} from "./interfaces/IBasketOracle.sol";
import {BasketMath} from "./libraries/BasketMath.sol";
import {InvalidPrice} from "./libraries/Errors.sol";
import {PricesUpdated} from "./libraries/Events.sol";

contract BasketOracle is AccessControl, IBasketOracle {
    bytes32 public constant ORACLE_UPDATER_ROLE = keccak256("ORACLE_UPDATER_ROLE");
    uint256 public constant DEFAULT_MAX_STALENESS = 300;

    Prices private prices;
    uint256 public maxStaleness = DEFAULT_MAX_STALENESS;

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_UPDATER_ROLE, admin);
        _setPrices(1e18, 1e18, 1e18, 1e18, 1e18);
    }

    function updatePrices(uint256 goldUsd, uint256 usdUsd, uint256 cnyUsd, uint256 eurUsd, uint256 brickUsd)
        external
        onlyRole(ORACLE_UPDATER_ROLE)
    {
        _setPrices(goldUsd, usdUsd, cnyUsd, eurUsd, brickUsd);
    }

    function freezeOracle() external onlyRole(ORACLE_UPDATER_ROLE) {
        prices.frozen = true;
    }

    function unfreezeOracle() external onlyRole(ORACLE_UPDATER_ROLE) {
        prices.frozen = false;
        prices.updatedAt = block.timestamp;
    }

    function setMaxStaleness(uint256 value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxStaleness = value;
    }

    function getPrices() external view returns (Prices memory) {
        return prices;
    }

    function getNAV() public view returns (uint256 nav) {
        return BasketMath.nav(prices.goldUsd, prices.usdUsd, prices.cnyUsd, prices.eurUsd, prices.brickUsd);
    }

    function isStale() public view returns (bool) {
        return block.timestamp > prices.updatedAt + maxStaleness;
    }

    function _setPrices(uint256 goldUsd, uint256 usdUsd, uint256 cnyUsd, uint256 eurUsd, uint256 brickUsd) private {
        if (goldUsd == 0 || usdUsd == 0 || cnyUsd == 0 || eurUsd == 0 || brickUsd == 0) {
            revert InvalidPrice();
        }
        prices = Prices(goldUsd, usdUsd, cnyUsd, eurUsd, brickUsd, block.timestamp, false);
        emit PricesUpdated(getNAV(), block.timestamp);
    }
}
