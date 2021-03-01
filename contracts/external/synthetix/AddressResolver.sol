// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface AddressResolver {
    function requireAndGetAddress(bytes32 name, string calldata reason) external view returns (address);
}
