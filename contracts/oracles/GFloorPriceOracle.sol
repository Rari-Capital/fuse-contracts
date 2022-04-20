// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/floor/IgFloor.sol";

import "./BasePriceOracle.sol";

/**
 * @title GFloorPriceOracle
 * @notice Returns prices for gFloor based on the Floor price and the gFloor index.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract GFloorPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice gFloor token address.
     */
    IgFloor public gFloor = IgFloor(0xb1Cc59Fc717b8D4783D41F952725177298B5619d);
    
    /**
     * @notice Floor token address.
     */
    address public Floor = 0xf59257E961883636290411c11ec5Ae622d19455e;

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
        require(token == address(gFloor), "Invalid token passed to gFloorPriceOracle.");
        return gFloor.index().mul(BasePriceOracle(msg.sender).price(Floor)).div(1e9); // 1e9 = Floor base unit and therefore also gFloor/Floor index base unit
    }
}
