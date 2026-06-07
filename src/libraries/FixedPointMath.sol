// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library FixedPointMath {
    uint256 internal constant WAD = 1e18;
    uint256 internal constant BPS = 10_000;

    function mulWad(uint256 x, uint256 y) internal pure returns (uint256) {
        return x * y / WAD;
    }

    function divWad(uint256 x, uint256 y) internal pure returns (uint256) {
        return x * WAD / y;
    }

    function applyBps(uint256 value, uint256 bps) internal pure returns (uint256) {
        return value * bps / BPS;
    }
}
