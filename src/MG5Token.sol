// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Unauthorized } from "./libraries/Errors.sol";

contract MG5Token is ERC20, Ownable {
    address public protocolMinter;

    constructor(address admin) ERC20("M&G5 Reserve Token", "MG5") Ownable(admin) { }

    function setProtocolMinter(address minter) external onlyOwner {
        protocolMinter = minter;
    }

    function mint(address to, uint256 amount) external {
        if (msg.sender != protocolMinter) revert Unauthorized();
        _mint(to, amount);
    }

    function burnFrom(address from, uint256 amount) external {
        if (msg.sender != protocolMinter) revert Unauthorized();
        _burn(from, amount);
    }
}
