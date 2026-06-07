// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { Script } from "forge-std/Script.sol";
import { ProtocolGovernor } from "../src/ProtocolGovernor.sol";
import { MG5Token } from "../src/MG5Token.sol";
import { MGSToken } from "../src/MGSToken.sol";
import { BasketOracle } from "../src/BasketOracle.sol";
import { ReserveManager } from "../src/ReserveManager.sol";
import { WaterfallManager } from "../src/WaterfallManager.sol";
import { CircuitBreaker } from "../src/CircuitBreaker.sol";
import { RedemptionQueue } from "../src/RedemptionQueue.sol";
import { BountyManager } from "../src/BountyManager.sol";
import { MintRedeem } from "../src/MintRedeem.sol";
import { IReserveManager } from "../src/interfaces/IReserveManager.sol";
import { MockReserveAsset } from "../src/mocks/MockReserveAsset.sol";

contract DeployLocal is Script {
    struct Deployed {
        ProtocolGovernor governor;
        MG5Token mg5;
        MGSToken mgs;
        BasketOracle oracle;
        ReserveManager reserves;
        WaterfallManager waterfall;
        CircuitBreaker circuitBreaker;
        RedemptionQueue queue;
        BountyManager bounties;
        MintRedeem mintRedeem;
        MockReserveAsset goldAsset;
        MockReserveAsset usdAsset;
        MockReserveAsset cnyAsset;
        MockReserveAsset eurAsset;
        MockReserveAsset brickAsset;
    }

    function run() external {
        vm.startBroadcast();
        address admin = msg.sender;
        Deployed memory d;
        d.governor = new ProtocolGovernor(admin);
        d.mg5 = new MG5Token(admin);
        d.mgs = new MGSToken(admin);
        d.oracle = new BasketOracle(admin);
        d.reserves = new ReserveManager(admin, d.oracle);
        d.goldAsset = new MockReserveAsset("Mock Gold Reserve Unit", "mGOLD", admin);
        d.usdAsset = new MockReserveAsset("Mock USD Reserve Unit", "mUSD", admin);
        d.cnyAsset = new MockReserveAsset("Mock CNY Reserve Unit", "mCNY", admin);
        d.eurAsset = new MockReserveAsset("Mock EUR Reserve Unit", "mEUR", admin);
        d.brickAsset = new MockReserveAsset("Mock BRICK Reserve Unit", "mBRICK", admin);
        d.waterfall = new WaterfallManager(admin);
        d.mintRedeem = new MintRedeem(admin, d.mg5, d.oracle, d.reserves);
        d.queue = new RedemptionQueue(admin, d.mg5, d.mintRedeem);
        d.bounties = new BountyManager(admin, d.mgs);
        d.circuitBreaker = new CircuitBreaker(admin, d.oracle, d.reserves, d.mg5);

        d.mg5.setProtocolMinter(address(d.mintRedeem));
        d.mgs.setBountyMinter(address(d.bounties));
        d.mintRedeem.setRedemptionQueue(address(d.queue));
        d.mintRedeem.setCircuitBreaker(address(d.circuitBreaker));
        d.reserves.setProtocol(address(d.mintRedeem), true);
        d.reserves
            .configureReserveAssets(
                IReserveManager.ReserveAssets(
                    address(d.goldAsset),
                    address(d.usdAsset),
                    address(d.cnyAsset),
                    address(d.eurAsset),
                    address(d.brickAsset)
                )
            );
        d.circuitBreaker.configure(d.queue, d.mintRedeem);
        d.waterfall.setProtocol(address(d.mintRedeem));

        d.oracle.updatePrices(1e18, 1e18, 1e18, 1e18, 1e18);
        d.reserves
            .updateMockReserves(
                IReserveManager.Reserves(200_000e18, 350_000e18, 250_000e18, 100_000e18, 100_000e18)
            );
        d.goldAsset.mint(address(d.reserves), 200_000e18);
        d.usdAsset.mint(address(d.reserves), 350_000e18);
        d.cnyAsset.mint(address(d.reserves), 250_000e18);
        d.eurAsset.mint(address(d.reserves), 100_000e18);
        d.brickAsset.mint(address(d.reserves), 100_000e18);
        d.waterfall.seedLiquidity(25_000e18, 5_000e18, 50_000e18, 500_000e18);
        vm.stopBroadcast();
    }
}
