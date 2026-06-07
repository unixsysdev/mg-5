// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Unauthorized } from "./libraries/Errors.sol";

contract MGSToken is ERC20, Ownable {
    address public bountyMinter;

    constructor(address admin) ERC20("M&G5 Share Token", "MGS") Ownable(admin) { }

    function setBountyMinter(address minter) external onlyOwner {
        bountyMinter = minter;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != bountyMinter) revert Unauthorized();
        _mint(to, amount);
    }
}
