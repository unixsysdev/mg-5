// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ProtocolInitialized } from "./libraries/Events.sol";

contract ProtocolGovernor is AccessControl {
    bytes32 public constant ORACLE_UPDATER_ROLE = keccak256("ORACLE_UPDATER_ROLE");
    bytes32 public constant RESERVE_UPDATER_ROLE = keccak256("RESERVE_UPDATER_ROLE");
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ORACLE_UPDATER_ROLE, admin);
        _grantRole(RESERVE_UPDATER_ROLE, admin);
        _grantRole(KEEPER_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
        emit ProtocolInitialized(admin);
    }
}
