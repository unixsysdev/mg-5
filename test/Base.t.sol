// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ProtocolGovernor} from "../src/ProtocolGovernor.sol";
import {MG5Token} from "../src/MG5Token.sol";
import {MGSToken} from "../src/MGSToken.sol";
import {BasketOracle} from "../src/BasketOracle.sol";
import {ReserveManager} from "../src/ReserveManager.sol";
import {MintRedeem} from "../src/MintRedeem.sol";
import {RedemptionQueue} from "../src/RedemptionQueue.sol";
import {WaterfallManager} from "../src/WaterfallManager.sol";
import {CircuitBreaker} from "../src/CircuitBreaker.sol";
import {BountyManager} from "../src/BountyManager.sol";
import {IReserveManager} from "../src/interfaces/IReserveManager.sol";

contract BaseTest is Test {
    address internal admin = address(0xA11CE);
    address internal user = address(0xB0B);
    address internal keeper = address(0xC0DE);

    ProtocolGovernor internal governor;
    MG5Token internal mg5;
    MGSToken internal mgs;
    BasketOracle internal oracle;
    ReserveManager internal reserves;
    MintRedeem internal mintRedeem;
    RedemptionQueue internal queue;
    WaterfallManager internal waterfall;
    CircuitBreaker internal circuitBreaker;
    BountyManager internal bounties;

    function setUp() public virtual {
        governor = new ProtocolGovernor(admin);
        vm.startPrank(admin);
        mg5 = new MG5Token(admin);
        mgs = new MGSToken(admin);
        oracle = new BasketOracle(admin);
        reserves = new ReserveManager(admin, oracle);
        mintRedeem = new MintRedeem(admin, mg5, oracle, reserves);
        queue = new RedemptionQueue(admin, mg5, mintRedeem);
        waterfall = new WaterfallManager(admin);
        bounties = new BountyManager(admin, mgs);
        circuitBreaker = new CircuitBreaker(admin, oracle, reserves, mg5);
        mg5.setProtocolMinter(address(mintRedeem));
        mgs.setBountyMinter(address(bounties));
        mintRedeem.setRedemptionQueue(address(queue));
        mintRedeem.setCircuitBreaker(address(circuitBreaker));
        reserves.setProtocol(address(mintRedeem), true);
        queue.grantRole(queue.KEEPER_ROLE(), keeper);
        circuitBreaker.configure(queue, mintRedeem);
        reserves.updateMockReserves(IReserveManager.Reserves(200_000e18, 350_000e18, 250_000e18, 100_000e18, 100_000e18));
        waterfall.seedLiquidity(25_000e18, 5_000e18, 50_000e18, 500_000e18);
        vm.stopPrank();
    }

    function mintForUser(uint256 depositValue) internal {
        vm.prank(user);
        mintRedeem.mintMG5(depositValue, 0);
    }
}
