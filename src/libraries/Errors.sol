// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

error InvalidWeights();
error InvalidPrice();
error OracleFrozen();
error OracleStale();
error ProtocolPaused();
error MintPaused();
error RedeemPaused();
error Unauthorized();
error InvalidCollateralRatio();
error InsufficientCollateral();
error PostMintUndercollateralized();
error PostRedeemUndercollateralized();
error RedemptionQueueRequired();
error InvalidRedemptionRequest();
error RedemptionAlreadyProcessed();
error SlippageExceeded();
error BountyDoesNotImprovePeg();
error BountyRewardTooLarge();
error MathOverflow();
error InvalidReserveAsset();
error InvalidReserveDeposit();
