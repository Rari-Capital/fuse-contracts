// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "./Sett.sol";

interface DiggSett is Sett {
    function shares() external view returns (uint256);
}
