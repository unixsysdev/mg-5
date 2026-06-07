// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IMG5Token {
    function mint(address to, uint256 amount) external;
    function burnFrom(address from, uint256 amount) external;
    function totalSupply() external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}
