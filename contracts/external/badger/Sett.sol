// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

interface Sett {
    function totalSupply() external view returns (uint256);
    function withdrawAll() external;
    function token() external view returns (address);
}
