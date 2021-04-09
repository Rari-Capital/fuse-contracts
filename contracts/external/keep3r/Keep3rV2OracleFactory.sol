// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "./Keep3rV2Oracle.sol";

contract Keep3rV2OracleFactory {
    mapping(address => Keep3rV2Oracle) public feeds;
}
