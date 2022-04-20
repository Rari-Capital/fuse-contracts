// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.6.12;
interface FloorStaking {
  function unstake(address _to, uint256 _amount, bool _trigger, bool _rebasing) external returns (uint);
  function gFloor() external view returns (address);
}
