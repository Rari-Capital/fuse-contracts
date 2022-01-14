// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/olympus/sOlympus.sol";

import "./BasePriceOracle.sol";

/**
 * @title WSSquidPriceOracle
 * @notice Returns prices for wsSQUID based on the SQUID price and the sSQUID index.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract WSSquidPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice sSQUID token address.
     */
    sOlympus public SSQUID = sOlympus(0x9d49BfC921F36448234b0eFa67B5f91b3C691515);

    /**
     * @notice wsSQUID token address.
     */
    address public WSSQUID = 0x3b1388eB39c72D2145f092C01067C02Bb627d4BE;
    
    /**
     * @notice SQUID token address.
     */
    address public SQUID = 0x21ad647b8F4Fe333212e735bfC1F36B4941E6Ad2;

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
        require(token == WSSQUID, "Invalid token passed to WSSquidPriceOracle.");
        return SSQUID.index().mul(BasePriceOracle(msg.sender).price(SQUID)).div(1e9); // 1e9 = SQUID base unit and therefore also sSQUID/SQUID index base unit
    }
}