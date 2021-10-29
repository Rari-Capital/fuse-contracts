// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "../external/alpha/ISafeBox.sol";

import "./BasePriceOracle.sol";

/**
 * @title AlphaHomoraV2PriceOracle
 * @notice Returns prices from Alpha Homora v2 "ibTokenV2" tokens (e.g., ibETHv2, ibDAIv2).
 * @dev Implements `PriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract AlphaHomoraV2PriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Fetches the fair ibTokenV2/ETH price, with 18 decimals of precision.
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
     * @dev Fetches the fair ibTokenV2/ETH price, with 18 decimals of precision.
     * @param safeBox The SafeBox (or SafeBoxETH) contract address for price retrieval.
     */
    function _price(address safeBox) internal view returns (uint) {
        // Get the cToken's underlying ibToken's underlying cToken
        CErc20 underlyingCErc20 = CErc20(ISafeBox(safeBox).cToken());

        // Get the token underlying the underlying cToken
        address baseToken = underlyingCErc20.underlying();

        // ibTokenV2/ETH price = underlying cToken/ETH price = underlying cToken/token price * base token/ETH price
        return underlyingCErc20.exchangeRateStored().mul(BasePriceOracle(msg.sender).price(baseToken)).div(1e18);
    }
}
