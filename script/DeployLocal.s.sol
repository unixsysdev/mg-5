// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {ProtocolGovernor} from "../src/ProtocolGovernor.sol";
import {MG5Token} from "../src/MG5Token.sol";
import {MGSToken} from "../src/MGSToken.sol";
import {BasketOracle} from "../src/BasketOracle.sol";
import {ReserveManager} from "../src/ReserveManager.sol";
import {WaterfallManager} from "../src/WaterfallManager.sol";
import {CircuitBreaker} from "../src/CircuitBreaker.sol";
import {RedemptionQueue} from "../src/RedemptionQueue.sol";
import {BountyManager} from "../src/BountyManager.sol";
import {MintRedeem} from "../src/MintRedeem.sol";
import {IReserveManager} from "../src/interfaces/IReserveManager.sol";

contract DeployLocal is Script {
    function run()
        external
        returns (
            ProtocolGovernor governor,
            MG5Token mg5,
            MGSToken mgs,
            BasketOracle oracle,
            ReserveManager reserves,
            WaterfallManager waterfall,
            CircuitBreaker circuitBreaker,
            RedemptionQueue queue,
            BountyManager bounties,
            MintRedeem mintRedeem
        )
    {
        vm.startBroadcast();
        address admin = msg.sender;
        governor = new ProtocolGovernor(admin);
        mg5 = new MG5Token(admin);
        mgs = new MGSToken(admin);
        oracle = new BasketOracle(admin);
        reserves = new ReserveManager(admin, oracle);
        waterfall = new WaterfallManager(admin);
        mintRedeem = new MintRedeem(admin, mg5, oracle, reserves);
        queue = new RedemptionQueue(admin, mg5, mintRedeem);
        bounties = new BountyManager(admin, mgs);
        circuitBreaker = new CircuitBreaker(admin, oracle, reserves, mg5);

        mg5.setProtocolMinter(address(mintRedeem));
        mgs.setBountyMinter(address(bounties));
        mintRedeem.setRedemptionQueue(address(queue));
        mintRedeem.setCircuitBreaker(address(circuitBreaker));
        reserves.setProtocol(address(mintRedeem), true);
        circuitBreaker.configure(queue, mintRedeem);
        waterfall.setProtocol(address(mintRedeem));

        oracle.updatePrices(1e18, 1e18, 1e18, 1e18, 1e18);
        reserves.updateMockReserves(IReserveManager.Reserves(200_000e18, 350_000e18, 250_000e18, 100_000e18, 100_000e18));
        waterfall.seedLiquidity(25_000e18, 5_000e18, 50_000e18, 500_000e18);
        vm.stopBroadcast();
    }
}
