// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface Vm {
    function expectRevert(bytes4 revertData) external;
    function expectRevert() external;
    function prank(address msgSender) external;
    function startPrank(address msgSender) external;
    function stopPrank() external;
    function warp(uint256 newTimestamp) external;
}

contract Test {
    Vm internal constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function assertTrue(bool condition) internal pure {
        require(condition, "assertTrue failed");
    }

    function assertFalse(bool condition) internal pure {
        require(!condition, "assertFalse failed");
    }

    function assertEq(uint256 a, uint256 b) internal pure {
        require(a == b, "assertEq uint failed");
    }

    function assertEq(address a, address b) internal pure {
        require(a == b, "assertEq address failed");
    }

    function assertEq(bool a, bool b) internal pure {
        require(a == b, "assertEq bool failed");
    }

    function assertGt(uint256 a, uint256 b) internal pure {
        require(a > b, "assertGt failed");
    }

    function assertGe(uint256 a, uint256 b) internal pure {
        require(a >= b, "assertGe failed");
    }

    function bound(uint256 x, uint256 min, uint256 max) internal pure returns (uint256) {
        require(min <= max, "bound invalid");
        if (x < min) return min;
        if (x > max) return max;
        return x;
    }
}
