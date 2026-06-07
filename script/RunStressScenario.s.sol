// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { BasketOracle } from "../src/BasketOracle.sol";
import { CircuitBreaker } from "../src/CircuitBreaker.sol";

contract RunStressScenario is Script {
    function run(address oracleAddress, address circuitBreakerAddress) external {
        vm.startBroadcast();
        BasketOracle(oracleAddress).updatePrices(0.85e18, 1e18, 0.9e18, 0.9e18, 0.7e18);
        CircuitBreaker(circuitBreakerAddress).triggerIfUndercollateralized();
        vm.stopBroadcast();
    }
}
