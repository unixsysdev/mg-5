// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { BasketOracle } from "./BasketOracle.sol";
import { ReserveManager } from "./ReserveManager.sol";
import { MG5Token } from "./MG5Token.sol";
import { RedemptionQueue } from "./RedemptionQueue.sol";
import { MintRedeem } from "./MintRedeem.sol";
import { CircuitBreakerTriggered, CircuitBreakerCleared } from "./libraries/Events.sol";

contract CircuitBreaker is AccessControl {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    uint256 public queueThresholdValue = 100_000e18;
    bool public triggered;
    string public reason;

    BasketOracle public immutable oracle;
    ReserveManager public immutable reserveManager;
    MG5Token public immutable mg5;
    RedemptionQueue public redemptionQueue;
    MintRedeem public mintRedeem;

    constructor(
        address admin,
        BasketOracle oracle_,
        ReserveManager reserveManager_,
        MG5Token mg5_
    ) {
        oracle = oracle_;
        reserveManager = reserveManager_;
        mg5 = mg5_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PAUSER_ROLE, admin);
    }

    function configure(RedemptionQueue queue_, MintRedeem mintRedeem_)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        redemptionQueue = queue_;
        mintRedeem = mintRedeem_;
    }

    function triggerIfOracleStale() external {
        if (oracle.isStale() || oracle.getPrices().frozen) _trigger("ORACLE_UNAVAILABLE");
    }

    function triggerIfUndercollateralized() external {
        if (
            reserveManager.collateralRatioBps(mg5.totalSupply(), oracle.getNAV())
                < reserveManager.MIN_COLLATERAL_RATIO_BPS()
        ) {
            _trigger("UNDERCOLLATERALIZED");
        }
    }

    function triggerIfQueueTooLarge() external {
        if (
            address(redemptionQueue) != address(0)
                && redemptionQueue.pendingValue() > queueThresholdValue
        ) {
            _trigger("QUEUE_TOO_LARGE");
        }
    }

    function pauseMinting() external onlyRole(PAUSER_ROLE) {
        mintRedeem.setPausedByCircuitBreaker(true, false);
        _trigger("MINT_PAUSED");
    }

    function pauseRedemptions() external onlyRole(PAUSER_ROLE) {
        mintRedeem.setPausedByCircuitBreaker(false, true);
        _trigger("REDEEM_PAUSED");
    }

    function pauseAll() external onlyRole(PAUSER_ROLE) {
        mintRedeem.setPausedByCircuitBreaker(true, true);
        _trigger("MANUAL_EMERGENCY");
    }

    function clearCircuitBreaker() external onlyRole(PAUSER_ROLE) {
        triggered = false;
        reason = "";
        mintRedeem.setPausedByCircuitBreaker(false, false);
        emit CircuitBreakerCleared();
    }

    function _trigger(string memory reason_) internal {
        triggered = true;
        reason = reason_;
        emit CircuitBreakerTriggered(reason_);
    }
}
