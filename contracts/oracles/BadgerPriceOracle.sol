// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/chainlink/AggregatorV3Interface.sol";

import "../external/badger/IXToken.sol";
import "../external/badger/IDigg.sol";
import "../external/badger/DiggSett.sol";

import "./BasePriceOracle.sol";

/**
 * @title BadgerPriceOracle
 * @notice Returns prices for bDIGG, bBADGER, and ibBTC.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract BadgerPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev BADGER/ETH Chainlink price feed.
     */
    AggregatorV3Interface constant public BADGER_ETH_FEED = AggregatorV3Interface(0x58921Ac140522867bf50b9E009599Da0CA4A2379);

    /**
     * @dev bBADGER ERC20 token contract.
     */
    IXToken constant public BBADGER = IXToken(0x19D97D8fA813EE2f51aD4B4e04EA08bAf4DFfC28);

    /**
     * @dev DIGG/BTC Chainlink price feed.
     */
    AggregatorV3Interface constant public DIGG_BTC_FEED = AggregatorV3Interface(0x418a6C98CD5B8275955f08F0b8C1c6838c8b1685);

    /**
     * @dev bDIGG ERC20 token contract.
     */
    DiggSett constant public BDIGG = DiggSett(0x7e7E112A68d8D2E221E11047a72fFC1065c38e1a);

    /**
     * @dev BTC/ETH Chainlink price feed.
     */
    AggregatorV3Interface constant public BTC_ETH_FEED = AggregatorV3Interface(0xdeb288F737066589598e9214E782fa5A8eD689e8);

    /**
     * @dev ibBTC ERC20 token contract.
     */
    IXToken constant public IBBTC = IXToken(0xc4E15973E6fF2A35cC804c2CF9D2a1b817a8b40F);

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
        if (token == address(BBADGER)) {
            (uint80 roundId, int256 badgerEthPrice, , , uint80 answeredInRound) = BADGER_ETH_FEED.latestRoundData();
            require(answeredInRound == roundId, "Chainlink round timed out.");
            return badgerEthPrice > 0 ? uint256(badgerEthPrice).mul(BBADGER.getPricePerFullShare()).div(1e18) : 0;
        } else if (token == address(BDIGG)) {
            (uint80 roundId, int256 diggBtcPrice, , , uint80 answeredInRound) = DIGG_BTC_FEED.latestRoundData();
            require(answeredInRound == roundId, "Chainlink round timed out.");
            if (diggBtcPrice < 0) return 0;
            int256 btcEthPrice;
            (roundId, btcEthPrice, , , answeredInRound) = BTC_ETH_FEED.latestRoundData();
            require(answeredInRound == roundId, "Chainlink round timed out.");
            if (btcEthPrice < 0) return 0;
            uint256 bDiggDiggPrice = IDigg(BDIGG.token()).sharesToFragments(BDIGG.shares().div(BDIGG.totalSupply()).mul(1e18));
            // bDIGG/ETH price = (bDIGG/DIGG price / 1e9) * (DIGG/BTC price / 1e8) * BTC/ETH price
            // Divide by BTC base unit 1e8 (BTC has 8 decimals) and DIGG base unit 1e9 (DIGG has 9 decimals)
            return bDiggDiggPrice > 0 ? uint256(diggBtcPrice).mul(uint256(btcEthPrice)).div(1e8).mul(bDiggDiggPrice).div(1e9) : 0;
        } else if (token == address(IBBTC)) {
            (uint80 roundId, int256 btcEthPrice, , , uint80 answeredInRound) = BTC_ETH_FEED.latestRoundData();
            require(answeredInRound == roundId, "Chainlink round timed out.");
            return btcEthPrice > 0 ? uint256(btcEthPrice).mul(IBBTC.pricePerShare()).div(1e18) : 0;
        } else revert("Invalid token address passed to BadgerPriceOracle.");
    }
}
