// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.6.12;

interface INFTXInventoryStaking {
    function xTokenShareValue(uint256 vaultId) external view returns (uint256);
    function withdraw(uint256 vaultId, uint256 _share) external;
}