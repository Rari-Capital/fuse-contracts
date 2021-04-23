// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

interface ICurveLiquidityGaugeV2 {
    function lp_token() external view returns (address);
    function deposit(uint256 _value) external;
    function withdraw(uint256 _value) external;
}
