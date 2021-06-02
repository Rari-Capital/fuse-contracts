// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "../external/curve/ICurveLiquidityGaugeV2.sol";

import "./BasePriceOracle.sol";

/**
 * @title CurveLiquidityGaugeV2PriceOracle
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice CurveLiquidityGaugeV2PriceOracle is a price oracle for Curve LiquidityGaugeV2 tokens (using the sender as a root oracle).
 * @dev Implements the `PriceOracle` interface used by Fuse pools (and Compound v2).
 * This contract is expected to be called by a `MasterPriceOracle` with the necessary `CurveLpTokenPriceOracle` configured.
 * The price of a Curve LiquidityGaugeV2 token is the same as the price of its underlying Curve LP token.
 */
contract CurveLiquidityGaugeV2PriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice Get the LiquidityGaugeV2 price price for an underlying token address.
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
     * @dev Fetches the fair LiquidityGaugeV2/ETH price from Curve, with 18 decimals of precision.
     * @param gauge The LiquidityGaugeV2 contract address for price retrieval.
     */
    function _price(address gauge) internal view returns (uint) {
        return BasePriceOracle(msg.sender).price(ICurveLiquidityGaugeV2(gauge).lp_token());
    }
}
