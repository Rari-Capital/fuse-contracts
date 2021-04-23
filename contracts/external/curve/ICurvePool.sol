// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

interface ICurvePool {
    function get_virtual_price() external view returns (uint);
    function remove_liquidity_one_coin(uint256 _token_amount, int128 i, uint256 min_amount) external;
}
