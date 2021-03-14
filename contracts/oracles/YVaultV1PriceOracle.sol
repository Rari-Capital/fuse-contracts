/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * No one is permitted to use the software for any purpose without the explicit permission of David Lucid of Rari Capital, Inc.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/yearn/IVault.sol";

import "./BasePriceOracle.sol";

/**
 * @title YVaultV1PriceOracle
 * @notice Returns prices for yVaults using the sender as a root oracle.
 * @dev Implements the `PriceOracle` interface.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract YVaultV1PriceOracle is PriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice Returns the price in ETH of the token underlying `cToken`.
     * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
     * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
     */
    function getUnderlyingPrice(CToken cToken) external override view returns (uint) {
        // Get price of token underlying yVault
        IVault yVault = IVault(CErc20(address(cToken)).underlying());
        address underlyingToken = yVault.token();
        uint underlyingPrice = underlyingToken == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 ? 1e18 : BasePriceOracle(msg.sender).price(underlyingToken);

        // yVault/ETH = yVault/token * token/ETH
        // Return value = yVault/ETH scaled by 1e(36 - yVault decimals)
        // `getPricePerFullShare` = yVault/token scaled by 1e18
        // `underlyingPrice` = token/ETH scaled by 1e18
        // Return value = `pricePerShare` * `underlyingPrice` / 1e(yVault decimals)
        uint256 baseUnit = 10 ** uint256(yVault.decimals());
        return yVault.getPricePerFullShare().mul(underlyingPrice).div(baseUnit); // getPricePerFullShare is scaled by 1e18
    }
}
