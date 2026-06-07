// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IReserveAttestation {
    struct AttestedReserve {
        bytes32 assetId;
        uint256 amount;
        uint256 valueUsd;
        uint256 attestedAt;
        bytes32 reportHash;
    }

    function latestAttestation(bytes32 assetId) external view returns (AttestedReserve memory);
    function isAttestationCurrent(bytes32 assetId) external view returns (bool);
}
