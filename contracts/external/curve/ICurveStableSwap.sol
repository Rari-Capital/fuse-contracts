// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface ICurveStableSwap is IERC20Upgradeable {
    function get_balances() external view returns (uint256[2] memory);
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external;
}
