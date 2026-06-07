// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

contract MockReserveAsset is ERC20, Ownable {
    constructor(string memory name_, string memory symbol_, address admin)
        ERC20(name_, symbol_)
        Ownable(admin)
    { }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }
}
