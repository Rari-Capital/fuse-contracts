// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "../external/chainlink/AggregatorV3Interface.sol";

import "./BasePriceOracle.sol";

/**
 * @title FixedUsdPriceOracle
 * @notice Returns fixed prices of 1 USD in terms of ETH for all tokens (expected to be used under a `MasterPriceOracle`).
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract FixedUsdPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice Chainlink ETH/USD price feed contracts.
     */
    AggregatorV3Interface public constant ETH_USD_PRICE_FEED = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    /**
     * @dev Internal function returning the price in ETH of `underlying`.
     */
    function _price(address underlying) internal view returns (uint) {
        // Get ETH/USD price from Chainlink
        (uint80 roundId, int256 ethUsdPrice, , , uint80 answeredInRound) = ETH_USD_PRICE_FEED.latestRoundData();
        require(answeredInRound == roundId, "Chainlink round timed out.");
        if (ethUsdPrice <= 0) return 0;

        // Return USD/ETH price = 1e26 / ETH/USD price
        return uint256(1e26).div(uint256(ethUsdPrice));
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
        // Get underlying token address
        address underlying = CErc20(address(cToken)).underlying();

        // Format and return price
        // Comptroller needs prices to be scaled by 1e(36 - decimals)
        // Since `_price` returns prices scaled by 18 decimals, we must scale them by 1e(36 - 18 - decimals)
        return _price(underlying).mul(1e18).div(10 ** uint256(ERC20Upgradeable(underlying).decimals()));
    }
}
