// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

interface IXToken {
    function pricePerShare() external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
}
