// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "./BasePriceOracle.sol";
import "./MasterPriceOracle.sol";
import "./ChainlinkPriceOracleV2.sol";

/**
 * @title PreferredPriceOracle
 * @notice Returns prices from MasterPriceOracle, ChainlinkPriceOracleV2, or prices from a tertiary oracle (in order of preference).
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract PreferredPriceOracle is PriceOracle, BasePriceOracle {
    /**
     * @dev The primary `MasterPriceOracle`.
     */
    MasterPriceOracle public masterOracle;

    /**
     * @dev The secondary `ChainlinkPriceOracleV2`.
     */
    ChainlinkPriceOracleV2 public chainlinkOracleV2;

    /**
     * @dev The tertiary `PriceOracle`.
     */
    PriceOracle public tertiaryOracle;
    
    /**
     * @dev Constructor to set the primary `MasterPriceOracle`, the secondary `ChainlinkPriceOracleV2`, and the tertiary `PriceOracle`.
     */
    constructor(MasterPriceOracle _masterOracle, ChainlinkPriceOracleV2 _chainlinkOracleV2, PriceOracle _tertiaryOracle) public {
        require(address(_masterOracle) != address(0), "MasterPriceOracle not set.");
        require(address(_chainlinkOracleV2) != address(0), "ChainlinkPriceOracleV2 not set.");
        require(address(_tertiaryOracle) != address(0), "Tertiary price oracle not set.");
        masterOracle = _masterOracle;
        chainlinkOracleV2 = _chainlinkOracleV2;
        tertiaryOracle = _tertiaryOracle;
    }

    /**
     * @notice Fetches the token/ETH price, with 18 decimals of precision.
     * @param underlying The underlying token address for which to get the price.
     * @return Price denominated in ETH (scaled by 1e18)
     */
    function price(address underlying) external override view returns (uint) {
        // Return 1e18 for WETH
        if (underlying == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) return 1e18;

        // Try to get MasterPriceOracle price
        if (address(masterOracle.oracles(underlying)) != address(0)) return masterOracle.price(underlying);

        // Try to get ChainlinkPriceOracleV2 price
        if (address(chainlinkOracleV2.priceFeeds(underlying)) != address(0)) return chainlinkOracleV2.price(underlying);

        // Otherwise, get price from tertiary oracle
        return BasePriceOracle(address(tertiaryOracle)).price(underlying);
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

        // Try to get MasterPriceOracle price
        if (address(masterOracle.oracles(underlying)) != address(0)) return masterOracle.getUnderlyingPrice(cToken);

        // Try to get ChainlinkPriceOracleV2 price
        if (address(chainlinkOracleV2.priceFeeds(underlying)) != address(0)) return chainlinkOracleV2.getUnderlyingPrice(cToken);

        // Otherwise, get price from tertiary oracle
        return tertiaryOracle.getUnderlyingPrice(cToken);
    }
}
