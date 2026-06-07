// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {BasketOracle} from "../src/BasketOracle.sol";

contract SeedMockPrices is Script {
    function run(address oracleAddress) external {
        vm.startBroadcast();
        BasketOracle(oracleAddress).updatePrices(1e18, 1e18, 1e18, 1e18, 1e18);
        vm.stopBroadcast();
    }
}
