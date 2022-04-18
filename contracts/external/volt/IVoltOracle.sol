// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.6.12;

interface IVoltOracle {
    function currPegPrice() external view returns (uint256);
}
