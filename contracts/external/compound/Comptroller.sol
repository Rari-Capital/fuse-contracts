// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.6.12;

import "./PriceOracle.sol";
import "./CToken.sol";
import "./Unitroller.sol";
import "./RewardsDistributor.sol";

/**
 * @title Compound's Comptroller Contract
 * @author Compound
 */
interface Comptroller {
    function admin() external view returns (address);
    function adminHasRights() external view returns (bool);
    function fuseAdminHasRights() external view returns (bool);

    function oracle() external view returns (PriceOracle);
    function closeFactorMantissa() external view returns (uint);
    function liquidationIncentiveMantissa() external view returns (uint);

    function markets(address cToken) external view returns (bool, uint);

    function getAssetsIn(address account) external view returns (CToken[] memory);
    function checkMembership(address account, CToken cToken) external view returns (bool);
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);

    function _setPriceOracle(PriceOracle newOracle) external returns (uint);
    function _setCloseFactor(uint newCloseFactorMantissa) external returns (uint256);
    function _setLiquidationIncentive(uint newLiquidationIncentiveMantissa) external returns (uint);
    function _become(Unitroller unitroller) external;

    function getRewardsDistributors() external view returns (RewardsDistributor[] memory);
    function getAllMarkets() external view returns (CToken[] memory);
    function getAllBorrowers() external view returns (address[] memory);
    function suppliers(address account) external view returns (bool);
    function enforceWhitelist() external view returns (bool);
    function whitelist(address account) external view returns (bool);

    function _setWhitelistEnforcement(bool enforce) external returns (uint);
    function _setWhitelistStatuses(address[] calldata _suppliers, bool[] calldata statuses) external returns (uint);

    function _toggleAutoImplementations(bool enabled) external returns (uint);
}
