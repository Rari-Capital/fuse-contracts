// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.6.12;

/**
 * @title ComptrollerCore
 * @dev Storage for the comptroller is at this address, while execution is delegated to the `comptrollerImplementation`.
 * CTokens should reference this contract as their comptroller.
 */
interface Unitroller {
    function _setPendingImplementation(address newPendingImplementation) external returns (uint);
    function _setPendingAdmin(address newPendingAdmin) external returns (uint);
}
