// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

abstract contract FodlStake is IERC20Upgradeable {
    IERC20Upgradeable public fodlToken;
    function stake(uint256 _amount) external virtual returns (uint256 shares);
    function unstake(uint256 _share) external virtual returns (uint256 amount);
}
