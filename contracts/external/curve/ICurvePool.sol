// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

interface ICurvePool {
    function get_virtual_price() external view returns (uint);
}
