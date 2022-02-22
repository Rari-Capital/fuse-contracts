// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

interface ICurveFactoryRegistry {
    function get_n_coins(address lp) external view returns (uint);
    function get_coins(address pool) external view returns (address[4] memory);
    function get_meta_n_coins(address pool) external view returns (uint, uint);
}
