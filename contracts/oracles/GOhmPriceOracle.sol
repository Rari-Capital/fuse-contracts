// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/olympus/IgOHM.sol";

import "./BasePriceOracle.sol";

/**
 * @title GOhmPriceOracle
 * @notice Returns prices for gOHM based on the OHM (v2) price and the gOHM index.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract GOhmPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice gOHM token address.
     */
    IgOHM public GOHM = IgOHM(0x0ab87046fBb341D058F17CBC4c1133F25a20a52f);
    
    /**
     * @notice OHM (v2) token address.
     */
    address public OHM = 0x64aa3364F17a4D01c6f1751Fd97C2BD3D7e7f1D5;

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
        require(token == address(GOHM), "Invalid token passed to GOhmPriceOracle.");
        return GOHM.index().mul(BasePriceOracle(msg.sender).price(OHM)).div(1e9); // 1e9 = OHM base unit and therefore also gOHM/OHM index base unit
    }
}
