// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "../external/chainlink/FeedRegistryInterface.sol";
import "../external/chainlink/Denominations.sol";

import "./BasePriceOracle.sol";

/**
 * @title ChainlinkPriceOracleV3
 * @notice Returns prices from Chainlink.
 * @dev Implements `PriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract ChainlinkPriceOracleV3 is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Official Chainlink feed registry contract.
     */
    FeedRegistryInterface feedRegistry;

    /**
     * @dev Internal function returning the price in ETH of `underlying`.
     */
    function _price(address underlying) internal view returns (uint) {
        // Return 1e18 for WETH
        if (underlying == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) return 1e18;

        // Try token/ETH to get token/ETH
        try feedRegistry.getFeed(underlying, Denominations.ETH) returns (AggregatorV2V3Interface feed) {
            (, int256 tokenEthPrice, , , ) = feed.latestRoundData();
            return tokenEthPrice >= 0 ? uint256(tokenEthPrice).mul(1e18).div(10 ** uint256(feed.decimals())) : 0;
        } catch Error(string memory reason) {
            require(keccak256(abi.encodePacked(reason)) == keccak256(abi.encodePacked("Feed not found")), "Attempt to get ETH-based feed failed for unexpected reason.");
        }

        // Try token/USD to get token/ETH
        try feedRegistry.getFeed(underlying, Denominations.USD) returns (AggregatorV2V3Interface feed) {
            (, int256 ethUsdPrice, , , ) = feedRegistry.latestRoundData(Denominations.ETH, Denominations.USD);
            if (ethUsdPrice <= 0) return 0;
            (, int256 tokenUsdPrice, , , ) = feed.latestRoundData();
            return tokenUsdPrice >= 0 ? uint256(tokenUsdPrice).mul(1e26).div(10 ** uint256(feed.decimals())).div(uint256(ethUsdPrice)) : 0;
        } catch Error(string memory reason) {
            require(keccak256(abi.encodePacked(reason)) == keccak256(abi.encodePacked("Feed not found")), "Attempt to get USD-based feed failed for unexpected reason.");
        }

        // Try token/BTC to get token/ETH
        try feedRegistry.getFeed(underlying, Denominations.BTC) returns (AggregatorV2V3Interface feed) {
            (, int256 btcEthPrice, , , ) = feedRegistry.latestRoundData(Denominations.BTC, Denominations.ETH);
            if (btcEthPrice <= 0) return 0;
            (, int256 tokenBtcPrice, , , ) = feed.latestRoundData();
            return tokenBtcPrice >= 0 ? uint256(tokenBtcPrice).mul(uint256(btcEthPrice)).div(10 ** uint256(feed.decimals())) : 0;
        } catch Error(string memory reason) {
            require(keccak256(abi.encodePacked(reason)) == keccak256(abi.encodePacked("Feed not found")), "Attempt to get BTC-based feed failed for unexpected reason.");
        }

        // Revert if all else fails
        revert("No Chainlink price feed found for this underlying ERC20 token.");
    }

    /**
     * @dev Returns the price in ETH of `underlying` (implements `BasePriceOracle`).
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
        // Return 1e18 for ETH
        if (cToken.isCEther()) return 1e18;

        // Get underlying token address
        address underlying = CErc20(address(cToken)).underlying();

        // Get, format, and return price
        // Comptroller needs prices to be scaled by 1e(36 - decimals)
        // Since `_price` returns prices scaled by 18 decimals, we must scale them by 1e(36 - 18 - decimals)
        return _price(underlying).mul(1e18).div(10 ** uint256(ERC20Upgradeable(underlying).decimals()));
    }
}
