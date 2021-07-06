// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.6.12;

import "./CToken.sol";

/**
 * @title Compound's CEther Contract
 * @notice CTokens which wrap an EIP-20 underlying
 * @author Compound
 */
interface CEther is CToken {
    function liquidateBorrow(address borrower, CToken cTokenCollateral) external payable;
}
