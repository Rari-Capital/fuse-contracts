// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/curve/ICurveMinter.sol";

import "./BasePriceOracle.sol";

/**
 * @title CvxFXSPriceOracle
 * @notice Returns prices for cvxFXS and cvxFXSFXS LP tokens
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract CvxFXSPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice FXS token address.
     */
    address public FXS = 0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0;

    /**
     * @notice cvxFXS token address.
     */
    address public cvxFXS = 0xFEEf77d3f69374f66429C91d732A244f074bdf74;
    
    /**
     * @notice Curve cvxFXSFXS LP token address.
     */
    address public cvxFXSFXS = 0xF3A43307DcAFa93275993862Aae628fCB50dC768;

    /**
     * @notice Curve cvxFXSFXS Minter contract address.
     */
    ICurveMinter public cvxFXSFXSMinter = ICurveMinter(0xd658A338613198204DCa1143Ac3F01A722b5d94A);

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
        if (token == cvxFXS) {
            // check if exchange rate < 1
            return cvxFXSFXSMinter.price_oracle() < 1e18 ?
                cvxFXSFXSMinter.price_oracle().mul(BasePriceOracle(msg.sender).price(FXS)).div(1e18) :
                BasePriceOracle(msg.sender).price(FXS);
        }
        else if (token == cvxFXSFXS) {
            return cvxFXSFXSMinter.lp_price().mul(BasePriceOracle(msg.sender).price(FXS)).div(1e18);
        }
        else revert("Invalid token passed to CvxFXSPriceOracle");
    }
}
