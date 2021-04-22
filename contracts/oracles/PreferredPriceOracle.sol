// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "./ChainlinkPriceOracle.sol";

/**
 * @title PreferredPriceOracle
 * @notice Returns prices from Chainlink or prices from a secondary oracle if an asset's price is not available via Chainlink.
 * @dev Implements `PriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract PreferredPriceOracle is PriceOracle {
    /**
     * @dev The primary `ChainlinkPriceOracle`.
     */
    ChainlinkPriceOracle public chainlinkOracle;

    /**
     * @dev The secondary `PriceOracle`.
     */
    PriceOracle public secondaryOracle;
    
    /**
     * @dev Constructor to set the primary `ChainlinkPriceOracle` and the secondary `PriceOracle`.
     */
    constructor(ChainlinkPriceOracle _chainlinkOracle, PriceOracle _secondaryOracle) public {
        require(address(_chainlinkOracle) != address(0), "ChainlinkPriceOracle not set.");
        require(address(_secondaryOracle) != address(0), "Secondary price oracle not set.");
        chainlinkOracle = _chainlinkOracle;
        secondaryOracle = _secondaryOracle;
    }

    /**
     * @notice Returns the price in ETH of the token underlying `cToken`.
     * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
     * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
     */
    function getUnderlyingPrice(CToken cToken) external override view returns (uint) {
        // Return 1e18 for ETH
        if (cToken.isCEther()) return 1e18;

        // Get underlying ERC20 token address
        address underlying = address(CErc20(address(cToken)).underlying());

        // Return 1e18 for WETH
        if (underlying == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) return 1e18;

        // Try to get Chainlink price
        if (chainlinkOracle.hasPriceFeed(underlying)) return chainlinkOracle.getUnderlyingPrice(cToken);

        // Otherwise, get price from secondary oracle
        return secondaryOracle.getUnderlyingPrice(cToken);
    }
}
