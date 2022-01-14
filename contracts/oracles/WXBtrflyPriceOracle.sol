// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/redacted/wxBTRFLY.sol";

import "./BasePriceOracle.sol";

/**
 * @title WXBtrflyPriceOracle
 * @notice Returns prices for wxBTRFLY based on the BTRFLY price and the sBTRFLY index.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract WXBtrflyPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice wxBTRFLY token address.
     */
    wxBTRFLY public WXBTRFLY = wxBTRFLY(0x186E55C0BebD2f69348d94C4A27556d93C5Bd36C);
    
    /**
     * @notice BTRFLY token address.
     */
    address public BTRFLY = 0xC0d4Ceb216B3BA9C3701B291766fDCbA977ceC3A;

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
        require(token == address(WXBTRFLY), "Invalid token passed to WXBtrflyPriceOracle.");
        return WXBTRFLY.realIndex().mul(BasePriceOracle(msg.sender).price(BTRFLY)).div(1e9); // 1e9 = BTRFLY base unit and therefore also xBTRFLY/BTRFLY index base unit
    }
}