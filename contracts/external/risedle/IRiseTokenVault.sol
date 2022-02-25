// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.6.12;

interface IRiseTokenVault {
  function getNAV(address token) external view returns (uint256);
  function removeSupply(uint256 amount) external;
}
