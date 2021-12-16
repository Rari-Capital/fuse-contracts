// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.6.12;

interface IgOHM {
  function mint(address _to, uint256 _amount) external;
  function burn(address _from, uint256 _amount) external;
  function index() external view returns (uint256);
  function balanceFrom(uint256 _amount) external view returns (uint256);
  function balanceTo(uint256 _amount) external view returns (uint256);
  function migrate( address _staking, address _sOHM ) external;
}
