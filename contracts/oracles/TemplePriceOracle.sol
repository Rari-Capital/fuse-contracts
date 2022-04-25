// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/temple/ITempleTreasury.sol";

import "./BasePriceOracle.sol";

/**
 * @title TemplePriceOracle
 * @notice Returns on-chain IV price for temple
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 */
contract TemplePriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice Temple treasury address.
     */
    ITempleTreasury constant public TREASURY = ITempleTreasury(0x22c2fE05f55F81Bf32310acD9a7C51c4d7b4e443);

    /**
     * @notice Temple token address.
     */
    address constant public TEMPLE = 0x470EBf5f030Ed85Fc1ed4C2d36B9DD02e77CF1b7;

    /**
     * @dev The token (FRAX) on which to base IV (its price must be available via `msg.sender`).
     */
    address constant public baseToken = 0x853d955aCEf822Db058eb8505911ED77F175b99e;

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
        require(token == address(TEMPLE), "Invalid token passed to TemplePriceOracle");
        (uint256 stablec, uint256 temple) = TREASURY.intrinsicValueRatio(); // IV price is stablec / temple
        return stablec.mul(BasePriceOracle(msg.sender).price(baseToken)).div(temple);
    }
}
