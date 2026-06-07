// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IPriceAdapter {
    function latestPrice(bytes32 assetId) external view returns (uint256 price, uint256 updatedAt);
    function isHealthy(bytes32 assetId) external view returns (bool);
}
