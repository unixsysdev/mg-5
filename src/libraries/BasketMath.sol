// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FixedPointMath } from "./FixedPointMath.sol";
import { InvalidWeights } from "./Errors.sol";

library BasketMath {
    uint256 public constant GOLD_BPS = 2_000;
    uint256 public constant USD_BPS = 3_500;
    uint256 public constant CNY_BPS = 2_500;
    uint256 public constant EUR_BPS = 1_000;
    uint256 public constant BRICK_BPS = 1_000;
    uint256 public constant TOTAL_WEIGHT_BPS = 10_000;

    function validateWeights() internal pure {
        if (GOLD_BPS + USD_BPS + CNY_BPS + EUR_BPS + BRICK_BPS != TOTAL_WEIGHT_BPS) {
            revert InvalidWeights();
        }
    }

    function nav(uint256 gold, uint256 usd, uint256 cny, uint256 eur, uint256 brick)
        internal
        pure
        returns (uint256)
    {
        validateWeights();
        return (FixedPointMath.applyBps(gold, GOLD_BPS) + FixedPointMath.applyBps(usd, USD_BPS)
                + FixedPointMath.applyBps(cny, CNY_BPS) + FixedPointMath.applyBps(eur, EUR_BPS)
                + FixedPointMath.applyBps(brick, BRICK_BPS));
    }
}
