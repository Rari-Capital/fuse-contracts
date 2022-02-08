// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "./BasePriceOracle.sol";

/**
 * @title Temporary RGT Price Oracle pegged to TRIBE price * exchange rate (26.705673430).
 * @notice Returns prices for RGT based on the TRIBE price * `EXCHANGE_RATE`.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract RgtTempPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice RGT token address.
     */
    address public constant RGT = 0xD291E7a03283640FDc51b121aC401383A46cC623;
    
    /**
     * @notice TRIBE token address.
     */
    address public constant TRIBE = 0xc7283b66Eb1EB5FB86327f08e1B5816b0720212B;

    /**
     * @notice Multiplier applied to RGT before converting to TRIBE scaled by 1e9.
     */
    uint constant public EXCHANGE_RATE = 26705673430;

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
        require(token == RGT, "Invalid token passed to RGTTempPriceOracle.");
        return EXCHANGE_RATE.mul(BasePriceOracle(msg.sender).price(TRIBE)).div(1e9); // EXCHANGE_RATE is scaled by 1e9
    }
}
