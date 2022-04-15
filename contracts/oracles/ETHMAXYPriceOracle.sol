// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/rari/IUniswapV3Twap.sol";

import "./BasePriceOracle.sol";

/**
 * @title ETHMAXYPriceOracle
 * @notice Returns prices for ETHMAXY with price deviation guard
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract ETHMAXYPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice ETHMAXY token address.
     */
    address public ETHMAXY = 0x0FE20E0Fa9C78278702B05c333Cc000034bb69E2;
    
    /**
     * @notice Uni-v3 WETH oracle 500 fee tier address
     */
    IUniswapV3Twap univ3twap = IUniswapV3Twap(0x35d45e98E3C3696A40645A4E98Ca6023EF135E04);

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
        require(token == ETHMAXY, "Invalid token passed to ETHMAXYPriceOracle.");
        uint price = univ3twap.price(token);
        require(price <= 1.2e18 && price >= .95e18, "ETHMAXY price out of bounds.");
        return price;
    }
}
