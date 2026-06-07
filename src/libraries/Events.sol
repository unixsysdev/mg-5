// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

event ProtocolInitialized(address indexed admin);
event PricesUpdated(uint256 nav, uint256 timestamp);
event ReservesUpdated(uint256 adjustedReserves, uint256 timestamp);
event StableMinted(address indexed user, uint256 depositValue, uint256 mg5Out);
event StableRedeemed(address indexed user, uint256 mg5Amount, uint256 valueOut);
event RedemptionRequested(uint256 indexed id, address indexed user, uint256 mg5Amount);
event RedemptionProcessed(uint256 indexed id, address indexed user, uint256 valueOut);
event CircuitBreakerTriggered(string reason);
event CircuitBreakerCleared();
event WarChestDrawn(uint256 amount);
event BountyClaimed(address indexed keeper, uint256 reward);
