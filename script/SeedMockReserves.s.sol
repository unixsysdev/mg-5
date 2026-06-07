// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {ReserveManager} from "../src/ReserveManager.sol";
import {IReserveManager} from "../src/interfaces/IReserveManager.sol";

contract SeedMockReserves is Script {
    function run(address reserveManagerAddress) external {
        vm.startBroadcast();
        ReserveManager(reserveManagerAddress).updateMockReserves(
            IReserveManager.Reserves(200_000e18, 350_000e18, 250_000e18, 100_000e18, 100_000e18)
        );
        vm.stopBroadcast();
    }
}
