// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IReserveManager {
    struct Reserves {
        uint256 gold;
        uint256 usd;
        uint256 cny;
        uint256 eur;
        uint256 brick;
    }

    struct Haircuts {
        uint256 goldBps;
        uint256 usdBps;
        uint256 cnyBps;
        uint256 eurBps;
        uint256 brickBps;
    }

    function updateMockReserves(Reserves calldata reserves) external;
    function rawReserveValue() external view returns (uint256);
    function haircutAdjustedReserveValue() external view returns (uint256);
    function liabilities(uint256 mg5Supply, uint256 nav) external pure returns (uint256);
    function collateralRatioBps(uint256 mg5Supply, uint256 nav) external view returns (uint256);
    function reduceReservesProRata(uint256 value) external;
}
