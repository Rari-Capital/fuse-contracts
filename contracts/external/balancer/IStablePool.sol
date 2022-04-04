// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.6.12;

interface IStablePool {
    function getRate() external view returns (uint256);
}