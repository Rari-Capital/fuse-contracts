// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface ITempleTreasury {
    function intrinsicValueRatio() external view returns (uint256, uint256);
}
