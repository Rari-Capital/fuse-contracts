// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface ISafeBoxETH is IERC20Upgradeable {
  function cToken() external view returns (address);
  function deposit() external payable;
  function withdraw(uint amount) external;
}
