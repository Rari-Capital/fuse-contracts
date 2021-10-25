// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

interface ICurveTriCryptoLpTokenOracle {
    function lp_price() external view returns (uint256);
}
