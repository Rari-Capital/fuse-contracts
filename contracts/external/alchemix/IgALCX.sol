// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.6.12;

interface IgALCX {
    function stake(uint256 _amount) external;
    function unstake(uint256 _amount) external;
    function exchangeRate() external view returns (uint256);
}
