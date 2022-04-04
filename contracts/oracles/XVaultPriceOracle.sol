// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/nftx/INFTXInventoryStaking.sol";
import "../external/nftx/INFTXVaultUpgradeable.sol";
import "../external/nftx/IXTokenUpgradeable.sol";

import "./BasePriceOracle.sol";

/**
 * @title NFTX xVault Price Oracle
 * @notice Returns prices for NFTX xAssets based on the underlying price and the xAssest Share Value.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract XVaultPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice INFTXInventoryStaking contract address.
     */
    INFTXInventoryStaking staking = INFTXInventoryStaking(0x3E135c3E981fAe3383A5aE0d323860a34CfAB893);

    /**
     * @notice Fetches the token/ETH price, with 18 decimals of precision.
     * @param underlying The underlying token address for which to get the price.
     * @return Price denominated in ETH (scaled by 1e18)
     */
    function price(address underlying) external override view returns (uint) {
        return _price(underlying);
    }

    /**
     * @notice Returns the price in ETH of the token underlying `cToken`.
     * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
     * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
     */
    function getUnderlyingPrice(CToken cToken) external override view returns (uint) {
        address underlying = CErc20(address(cToken)).underlying();
        // Comptroller needs prices to be scaled by 1e(36 - decimals)
        // Since `_price` returns prices scaled by 18 decimals, we must scale them by 1e(36 - 18 - decimals)
        return _price(underlying).mul(1e18).div(10 ** uint256(ERC20Upgradeable(underlying).decimals()));
    }

    /**
     * @notice Fetches the token/ETH price, with 18 decimals of precision.
     */
    function _price(address token) internal view returns (uint) {
        IXTokenUpgradeable xToken = IXTokenUpgradeable(token);
        INFTXVaultUpgradeable vault = INFTXVaultUpgradeable(xToken.baseToken());
        require(address(vault) != address(0), "Invalid token passed to XVaultPriceOracle");
        return staking.xTokenShareValue(vault.vaultId()).mul(BasePriceOracle(msg.sender).price(address(vault))).div(1e18); 
    }
}
