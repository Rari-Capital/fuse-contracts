/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * No one is permitted to use the software for any purpose without the explicit permission of David Lucid of Rari Capital, Inc.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/synthetix/AddressResolver.sol";
import "../external/synthetix/ExchangeRates.sol";
import "../external/synthetix/ISynth.sol";
import "../external/synthetix/MixinResolver.sol";
import "../external/synthetix/Proxy.sol";

/**
 * @title SynthetixPriceOracle
 * @notice Returns prices for Synths from Synthetix's official `ExchangeRates` contract.
 * @dev Implements `PriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract SynthetixPriceOracle is PriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice Returns the price in ETH of the token underlying `cToken`.
     * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
     * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
     */
    function getUnderlyingPrice(CToken cToken) external override view returns (uint) {
        address underlying = CErc20(address(cToken)).underlying();
        uint256 baseUnit = 10 ** uint(ERC20Upgradeable(underlying).decimals());
        underlying = Proxy(underlying).target(); // For some reason we have to use the logic contract instead of the proxy contract to get `resolver` and `currencyKey`
        ExchangeRates exchangeRates = ExchangeRates(MixinResolver(underlying).resolver().requireAndGetAddress("ExchangeRates", "Failed to get Synthetix's ExchangeRates contract address."));
        return exchangeRates.effectiveValue(ISynth(underlying).currencyKey(), baseUnit, "ETH").mul(1e18).div(baseUnit);
    }
}
