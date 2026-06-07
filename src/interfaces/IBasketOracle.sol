// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBasketOracle {
    struct Prices {
        uint256 goldUsd;
        uint256 usdUsd;
        uint256 cnyUsd;
        uint256 eurUsd;
        uint256 brickUsd;
        uint256 updatedAt;
        bool frozen;
    }

    function getPrices() external view returns (Prices memory);
    function getNAV() external view returns (uint256 nav);
    function isStale() external view returns (bool);
}
