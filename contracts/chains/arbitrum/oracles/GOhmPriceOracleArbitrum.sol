// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../../../external/compound/PriceOracle.sol";
import "../../../external/compound/CErc20.sol";

import "../../../external/chainlink/AggregatorV3Interface.sol";

import "../../../oracles/BasePriceOracle.sol";

/**
 * @title GOhmPriceOracleArbitrum
 * @notice Returns prices for gOHM based on the OHM (v2) price and the gOHM index.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author Sri Yantra <sriyantra@rari.capital>, David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract GOhmPriceOracleArbitrum is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice gOHM token address.
     */
    address public GOHM = 0x8D9bA570D6cb60C7e3e0F31343Efe75AB8E65FB1;
    
    /**
     * @notice OHM (v2) token address.
     */
    address public OHM = 0x6E6a3D8F1AfFAc703B1aEF1F43B8D2321bE40043;

    /**
     * @notice Chainlink OHM INDEX price feed contract.
     */
    AggregatorV3Interface public OHM_INDEX_PRICE_FEED = AggregatorV3Interface(0x48C4721354A3B29D80EF03C65E6644A37338a0B1);

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
        (, int256 OHM_INDEX, , , ) = OHM_INDEX_PRICE_FEED.latestRoundData();
        return uint256(OHM_INDEX).mul(BasePriceOracle(msg.sender).price(OHM)).div(1e9); // 1e9 = OHM base unit and therefore also gOHM/OHM index base unit
    }
}
