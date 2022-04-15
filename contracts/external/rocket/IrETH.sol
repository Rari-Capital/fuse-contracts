// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.6.12;

interface IrETH {
    function getExchangeRate() external view returns (uint256);
}
