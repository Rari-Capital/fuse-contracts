// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface ISafeBox is IERC20Upgradeable {
  function cToken() external view returns (address); 
  function deposit(uint amount) external;
  function withdraw(uint amount) external;
}
