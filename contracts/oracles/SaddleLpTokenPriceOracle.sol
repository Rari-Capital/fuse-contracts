// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "../external/saddle/ISwap.sol";

import "./BasePriceOracle.sol";

/**
 * @title SaddleLpTokenPriceOracle
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice SaddleLpTokenPriceOracle is a price oracle for Saddle LP tokens (using the sender as a root oracle).
 * @dev Implements the `PriceOracle` interface used by Fuse pools (and Compound v2).
 */
contract SaddleLpTokenPriceOracle is PriceOracle, BasePriceOracle {
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
     * @dev Fetches the fair LP token/ETH price from Saddle, with 18 decimals of precision.
     * Based on: https://github.com/AlphaFinanceLab/homora-v2/blob/master/contracts/oracle/CurveOracle.sol
     * @param lpToken The LP token contract address for price retrieval.
     */
    function _price(address lpToken) internal view returns (uint) {
        address pool = poolOf[lpToken];
        require(pool != address(0), "LP token is not registered.");
        address[] memory tokens = underlyingTokens[lpToken];
        uint256 minPx = uint256(-1);
        uint256 n = tokens.length;

        for (uint256 i = 0; i < n; i++) {
            address ulToken = tokens[i];
            uint256 tokenPx = BasePriceOracle(msg.sender).price(ulToken);
            if (tokenPx < minPx) minPx = tokenPx;
        }

        require(minPx != uint256(-1), "No minimum underlying token price found.");      
        return minPx.mul(ISwap(pool).getVirtualPrice()).div(1e18); // Use min underlying token prices
    }

    /**
     * @dev Maps Saddle LP token addresses to underlying token addresses.
     */
    mapping(address => address[]) public underlyingTokens;

    /**
     * @dev Maps Saddle LP token addresses to pool addresses.
     */
    mapping(address => address) public poolOf;

    /**
     * @dev Register the pool given LP token address and set the pool info.
     * Based on: https://github.com/AlphaFinanceLab/homora-v2/blob/master/contracts/oracle/CurveOracle.sol
     * @param lpToken LP token to find the corresponding pool.
     */
    function registerPool(address lpToken) external {
        address pool = poolOf[lpToken];
        require(pool == address(0), "This LP token is already registered.");
        pool = OwnableUpgradeable(lpToken).owner();
        require(pool != address(0), "No corresponding pool found for this LP token.");
        poolOf[lpToken] = pool;

        for (uint256 i = 0; i < 32; i++) {
            try ISwap(pool).getToken(i) returns (address underlyingToken) {
                underlyingTokens[lpToken].push(underlyingToken);
            } catch {
                require(i > 0, "Failed to get tokens underlying Saddle pool.");
                break;
            }
        }
    }
}
