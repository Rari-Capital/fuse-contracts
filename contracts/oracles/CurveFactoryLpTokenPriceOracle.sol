// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "../external/curve/ICurveFactoryRegistry.sol";
import "../external/curve/ICurvePool.sol";

import "./BasePriceOracle.sol";
import "hardhat/console.sol";

/**
 * @title CurveFactoryLpTokenPriceOracle
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice CurveFactoryLpTokenPriceOracle is a price oracle for Curve LP tokens (using the sender as a root oracle).
 * @dev Implements the `PriceOracle` interface used by Fuse pools (and Compound v2).
 */
contract CurveFactoryLpTokenPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice Get the LP token price price for an underlying token address.
     * @param underlying The underlying token address for which to get the price (set to zero address for ETH).
     * @return Price denominated in ETH (scaled by 1e18).
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
     * @dev Fetches the fair LP token/ETH price from Curve, with 18 decimals of precision.
     * Source: https://github.com/AlphaFinanceLab/homora-v2/blob/master/contracts/oracle/CurveOracle.sol
     * @param pool pool LP token
     */
    function _price(address pool) internal view returns (uint) {
        address[] memory tokens = underlyingTokens[pool];
        require(tokens.length != 0, "LP token is not registered.");
        uint256 minPx = uint256(-1);
        uint256 n = tokens.length;

        for (uint256 i = 0; i < n; i++) {
            address ulToken = tokens[i];
            uint256 tokenPx = BasePriceOracle(msg.sender).price(ulToken);
            if (tokenPx < minPx) minPx = tokenPx;
        }

        require(minPx != uint256(-1), "No minimum underlying token price found."); 
        return minPx.mul(ICurvePool(pool).get_virtual_price()).div(1e18); // Use min underlying token prices
    }

    /**
     * @dev The Curve registry.
     */
    ICurveFactoryRegistry public constant registry = ICurveFactoryRegistry(0xB9fC157394Af804a3578134A6585C0dc9cc990d4);

    /**
     * @dev Maps Curve LP token addresses to underlying token addresses.
     */
    mapping(address => address[]) public underlyingTokens;

    /**
     * @dev Maps Curve LP token addresses to pool addresses.
     */
    mapping(address => address) public poolOf;

    /**
     * @dev Register the pool given LP token address and set the pool info.
     * Source: https://github.com/AlphaFinanceLab/homora-v2/blob/master/contracts/oracle/CurveOracle.sol
     * @param pool pool LP token
     */
    function registerPool(address pool) external {
        uint n = registry.get_n_coins(pool);
        if (n == 0) (n, ) = registry.get_meta_n_coins(pool);
        require(n != 0, "n");
        address[4] memory tokens = registry.get_coins(pool);
        for (uint256 i = 0; i < n; i++) {
            underlyingTokens[pool].push(tokens[i]);
        }
    }
}
