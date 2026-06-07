// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MG5Token } from "./MG5Token.sol";
import { MintRedeem } from "./MintRedeem.sol";
import {
    InvalidRedemptionRequest,
    RedemptionAlreadyProcessed,
    Unauthorized
} from "./libraries/Errors.sol";
import { RedemptionRequested, RedemptionProcessed } from "./libraries/Events.sol";

contract RedemptionQueue is AccessControl, ReentrancyGuard {
    using SafeERC20 for MG5Token;

    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    enum Status {
        Pending,
        Processed,
        Cancelled
    }

    struct RedemptionRequest {
        uint256 id;
        address owner;
        uint256 mg5Amount;
        uint256 navAtRequest;
        uint256 redeemValue;
        uint256 createdAt;
        Status status;
    }

    MG5Token public immutable mg5;
    MintRedeem public immutable mintRedeem;
    uint256 public nextRequestId = 1;
    uint256 private pendingValue_;
    uint256 private pendingCount_;
    mapping(uint256 => RedemptionRequest) public requests;

    constructor(address admin, MG5Token mg5_, MintRedeem mintRedeem_) {
        mg5 = mg5_;
        mintRedeem = mintRedeem_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(KEEPER_ROLE, admin);
    }

    function requestRedemption(uint256 mg5Amount)
        external
        nonReentrant
        returns (uint256 requestId)
    {
        uint256 nav = mintRedeem.checkedNav();
        (uint256 grossValue,,) = mintRedeem.quoteRedemption(mg5Amount, nav);
        requestId = nextRequestId++;
        requests[requestId] = RedemptionRequest({
            id: requestId,
            owner: msg.sender,
            mg5Amount: mg5Amount,
            navAtRequest: nav,
            redeemValue: grossValue,
            createdAt: block.timestamp,
            status: Status.Pending
        });
        pendingValue_ += grossValue;
        pendingCount_ += 1;
        mg5.safeTransferFrom(msg.sender, address(this), mg5Amount);
        emit RedemptionRequested(requestId, msg.sender, mg5Amount);
    }

    function processRedemption(uint256 requestId) external onlyRole(KEEPER_ROLE) nonReentrant {
        RedemptionRequest storage request = requests[requestId];
        if (request.owner == address(0)) revert InvalidRedemptionRequest();
        if (request.status != Status.Pending) revert RedemptionAlreadyProcessed();

        request.status = Status.Processed;
        pendingValue_ -= request.redeemValue;
        pendingCount_ -= 1;
        uint256 valueOut = mintRedeem.processQueuedRedemption(request.owner, request.mg5Amount, 0);
        emit RedemptionProcessed(request.id, request.owner, valueOut);
    }

    function cancelRedemption(uint256 requestId) external nonReentrant {
        RedemptionRequest storage request = requests[requestId];
        if (request.owner == address(0)) revert InvalidRedemptionRequest();
        if (request.owner != msg.sender) revert Unauthorized();
        if (request.status != Status.Pending) revert RedemptionAlreadyProcessed();

        request.status = Status.Cancelled;
        pendingValue_ -= request.redeemValue;
        pendingCount_ -= 1;
        mg5.safeTransfer(msg.sender, request.mg5Amount);
    }

    function pendingValue() external view returns (uint256) {
        return pendingValue_;
    }

    function pendingCount() external view returns (uint256) {
        return pendingCount_;
    }
}
