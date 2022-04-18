// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/volt/IVoltOracle.sol";
import "../external/chainlink/AggregatorV3Interface.sol";

import "./BasePriceOracle.sol";

/**
 * @title VoltPriceOracle
 * @notice Returns prices for VOLT based on the Volt oracle price.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract VoltPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice VOLT token address.
     */
    address public VOLT = 0x559eBC30b0E58a45Cc9fF573f77EF1e5eb1b3E18;
    
    /**
     * @notice Volt oracle address.
     */
    IVoltOracle voltOracle = IVoltOracle(0x84dc71500D504163A87756dB6368CC8bB654592f);

    /**
     * @notice Chainlink ETH/USD price feed contracts.
     */
    AggregatorV3Interface public constant ETH_USD_PRICE_FEED = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

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
        require(token == address(VOLT), "Invalid token passed to VoltPriceOracle.");

        uint voltUsdPrice = voltOracle.currPegPrice();
        // Get ETH/USD price from Chainlink
        (, int256 ethUsdPrice, , , ) = ETH_USD_PRICE_FEED.latestRoundData();
        return uint256(voltUsdPrice).mul(1e26).div(1e18).div(uint256(ethUsdPrice));
    }
}
