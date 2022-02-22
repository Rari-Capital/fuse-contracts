// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/risedle/IRiseTokenVault.sol";

import "./BasePriceOracle.sol";

/**
 * @title EthRisePriceOracle
 * @notice Returns prices for Risedle's ETHRISE token based on the getNAV() vault function.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author sri yantra <sriyantra@rari.capital> (https://github.com/sriyantra)
 */
contract EthRisePriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice Risedle Vault
     */
    IRiseTokenVault public rVault = IRiseTokenVault(0xf7EDB240DbF7BBED7D321776AFe87D1FBcFD0A94);
    
    /**
     * @notice ETHRISE address
     */
     address public ETHRISE = 0x46D06cf8052eA6FdbF71736AF33eD23686eA1452;

    /**
     * @notice USDC address
     */
    address public USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

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
        require(token == ETHRISE, "Invalid token passed to RisedlePriceOracle.");
        return rVault.getNAV(ETHRISE).mul(BasePriceOracle(msg.sender).price(USDC)).div(1e6); // 1e6 = USDC decimals as returned by getNAV()
    }
}
