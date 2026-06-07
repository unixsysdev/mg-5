// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {FixedPointMath} from "./libraries/FixedPointMath.sol";
import {Unauthorized} from "./libraries/Errors.sol";
import {WarChestDrawn} from "./libraries/Events.sol";

contract WaterfallManager is Ownable {
    uint8 public constant LAYER_DEX_LIQUIDITY = 1;
    uint8 public constant LAYER_FEE_BUFFER = 2;
    uint8 public constant LAYER_WAR_CHEST = 3;
    uint8 public constant LAYER_RESERVE_LIQUIDATION = 4;
    uint8 public constant LAYER_REDEMPTION_QUEUE = 5;
    uint8 public constant LAYER_CIRCUIT_BREAKER = 6;

    uint256 public mockDexLiquidity;
    uint256 public feeBuffer;
    uint256 public warChest;
    uint256 public reserveLiquidationCapacity;
    uint256 public maxDailyWarChestDrawBps = 1_000;
    uint256 public drawnToday;
    uint256 public lastDrawDay;
    address public protocol;

    constructor(address admin) Ownable(admin) {}

    function setProtocol(address protocol_) external onlyOwner {
        protocol = protocol_;
    }

    function seedLiquidity(uint256 dex, uint256 fees, uint256 warChest_, uint256 reserves) external onlyOwner {
        mockDexLiquidity = dex;
        feeBuffer = fees;
        warChest = warChest_;
        reserveLiquidationCapacity = reserves;
    }

    function availableImmediateLiquidity() external view returns (uint256) {
        return mockDexLiquidity + feeBuffer + warChest;
    }

    function canProcessRedemption(uint256 value) external view returns (bool) {
        return value <= mockDexLiquidity + feeBuffer + warChest + reserveLiquidationCapacity;
    }

    function drawWarChest(uint256 amount) external {
        if (msg.sender != protocol && msg.sender != owner()) revert Unauthorized();
        uint256 day = block.timestamp / 1 days;
        if (day != lastDrawDay) {
            lastDrawDay = day;
            drawnToday = 0;
        }
        uint256 dailyLimit = FixedPointMath.applyBps(warChest, maxDailyWarChestDrawBps);
        require(drawnToday + amount <= dailyLimit, "WAR_CHEST_DAILY_LIMIT");
        require(amount <= warChest, "WAR_CHEST_LOW");
        drawnToday += amount;
        warChest -= amount;
        emit WarChestDrawn(amount);
    }

    function selectDefenseLayer(uint256 requiredAmount) external view returns (uint8 layer) {
        if (requiredAmount <= mockDexLiquidity) return LAYER_DEX_LIQUIDITY;
        if (requiredAmount <= mockDexLiquidity + feeBuffer) return LAYER_FEE_BUFFER;
        if (requiredAmount <= mockDexLiquidity + feeBuffer + warChest) return LAYER_WAR_CHEST;
        if (requiredAmount <= mockDexLiquidity + feeBuffer + warChest + reserveLiquidationCapacity) {
            return LAYER_RESERVE_LIQUIDATION;
        }
        if (warChest == 0 || reserveLiquidationCapacity > 0) return LAYER_REDEMPTION_QUEUE;
        return LAYER_CIRCUIT_BREAKER;
    }
}
