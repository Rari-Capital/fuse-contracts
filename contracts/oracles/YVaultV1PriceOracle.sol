// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/yearn/IVault.sol";

import "./BasePriceOracle.sol";

/**
 * @title YVaultV1PriceOracle
 * @notice Returns prices for V1 yVaults (using the sender as a root oracle).
 * @dev Implements the `PriceOracle` interface.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract YVaultV1PriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

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
        // Get price of token underlying yVault
        IVault yVault = IVault(token);
        address underlyingToken = yVault.token();
        uint underlyingPrice = underlyingToken == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 ? 1e18 : BasePriceOracle(msg.sender).price(underlyingToken);

        // yVault/ETH = yVault/token * token/ETH
        // Return value = yVault/ETH scaled by 1e18
        // `getPricePerFullShare` = yVault/token scaled by 1e18
        // `underlyingPrice` = token/ETH scaled by 1e18
        // Return value = `pricePerShare` * `underlyingPrice` / 1e18
        return yVault.getPricePerFullShare().mul(underlyingPrice).div(1e18);
    }
}
