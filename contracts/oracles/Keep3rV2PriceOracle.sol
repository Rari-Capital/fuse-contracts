// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "../external/keep3r/Keep3rV2OracleFactory.sol";
import "../external/keep3r/Keep3rV2Oracle.sol";

import "../external/uniswap/IUniswapV2Pair.sol";
import "../external/uniswap/IUniswapV2Factory.sol";

import "./BasePriceOracle.sol";

/**
 * @title Keep3rV2PriceOracle
 * @notice Returns prices from `Keep3rV2Oracle`.
 * @dev Implements `PriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract Keep3rV2PriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Constructor that sets the Keep3rV1Oracle or SushiswapV1Oracle.
     */
    constructor (address _keep3rV2OracleFactory, address _uniswapV2Factory) public {
        keep3rV2OracleFactory = Keep3rV2OracleFactory(_keep3rV2OracleFactory);
        uniswapV2Factory = IUniswapV2Factory(_uniswapV2Factory);
    }

    /**
     * @dev Keep3rV1Oracle token contract object.
     */
    Keep3rV2OracleFactory immutable public keep3rV2OracleFactory;

    /**
     * @dev UniswapV2Factory contract object.
     */
    IUniswapV2Factory immutable public uniswapV2Factory;

    /**
     * @dev WETH token contract address.
     */
    address constant public WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @dev Minimum TWAP interval.
     */
    uint256 public constant MIN_TWAP_TIME = 15 minutes;

    /**
     * @dev Return the TWAP value price0. Revert if TWAP time range is not within the threshold.
     * Copied from: https://github.com/AlphaFinanceLab/homora-v2/blob/master/contracts/oracle/BaseKP3ROracle.sol
     * @param pair The pair to query for price0.
     */
    function price0TWAP(address pair) internal view returns (uint) {
        Keep3rV2Oracle feed = keep3rV2OracleFactory.feeds(pair);
        uint length = feed.length();
        require(length > 0, 'no length-1 observation');
        (uint lastTime, uint lastPx0CumuCompressed, ) = feed.observations(length - 1);
        if (lastTime > now - MIN_TWAP_TIME) {
            require(length > 1, 'no length-2 observation');
            (lastTime, lastPx0CumuCompressed, ) = feed.observations(length - 2);
        }
        uint elapsedTime = now - lastTime;
        require(elapsedTime >= MIN_TWAP_TIME, 'no TWAP satisfying MIN_TWAP_TIME');
        uint lastPx0Cumu = uint(lastPx0CumuCompressed) * (2 ** 112) / 1e18;
        uint currPx0Cumu = currentPx0Cumu(pair);
        return (currPx0Cumu - lastPx0Cumu) / (now - lastTime); // overflow is desired
    }

    /**
     * @dev Return the TWAP value price1. Revert if TWAP time range is not within the threshold.
     * Copied from: https://github.com/AlphaFinanceLab/homora-v2/blob/master/contracts/oracle/BaseKP3ROracle.sol
     * @param pair The pair to query for price1.
     */
    function price1TWAP(address pair) internal view returns (uint) {
        Keep3rV2Oracle feed = keep3rV2OracleFactory.feeds(pair);
        uint length = feed.length();
        require(length > 0, 'no length-1 observation');
        (uint lastTime, , uint112 lastPx1CumuCompressed) = feed.observations(length - 1);
        if (lastTime > now - MIN_TWAP_TIME) {
            require(length > 1, 'no length-2 observation');
            (lastTime, , lastPx1CumuCompressed) = feed.observations(length - 2);
        }
        uint elapsedTime = now - lastTime;
        require(elapsedTime >= MIN_TWAP_TIME, 'no TWAP satisfying MIN_TWAP_TIME');
        uint lastPx1Cumu = uint(lastPx1CumuCompressed) * (2 ** 112) / 1e18;
        uint currPx1Cumu = currentPx1Cumu(pair);
        return (currPx1Cumu - lastPx1Cumu) / (now - lastTime); // overflow is desired
    }

    /**
     * @dev Return the current price0 cumulative value on Uniswap.
     * Copied from: https://github.com/AlphaFinanceLab/homora-v2/blob/master/contracts/oracle/BaseKP3ROracle.sol
     * @param pair The uniswap pair to query for price0 cumulative value.
     */
    function currentPx0Cumu(address pair) internal view returns (uint px0Cumu) {
        uint32 currTime = uint32(now);
        px0Cumu = IUniswapV2Pair(pair).price0CumulativeLast();
        (uint reserve0, uint reserve1, uint32 lastTime) = IUniswapV2Pair(pair).getReserves();
        if (lastTime != now) {
            uint32 timeElapsed = currTime - lastTime; // overflow is desired
            px0Cumu += uint((reserve1 << 112) / reserve0) * timeElapsed; // overflow is desired
        }
    }

    /**
     * @dev Return the current price1 cumulative value on Uniswap.
     * Copied from: https://github.com/AlphaFinanceLab/homora-v2/blob/master/contracts/oracle/BaseKP3ROracle.sol
     * @param pair The uniswap pair to query for price1 cumulative value.
     */
    function currentPx1Cumu(address pair) internal view returns (uint px1Cumu) {
        uint32 currTime = uint32(now);
        px1Cumu = IUniswapV2Pair(pair).price1CumulativeLast();
        (uint reserve0, uint reserve1, uint32 lastTime) = IUniswapV2Pair(pair).getReserves();
        if (lastTime != currTime) {
            uint32 timeElapsed = currTime - lastTime; // overflow is desired
            px1Cumu += uint((reserve0 << 112) / reserve1) * timeElapsed; // overflow is desired
        }
    }
    
    /**
     * @notice Returns the price in ETH of the token underlying `cToken`.
     * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
     * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
     */
    function getUnderlyingPrice(CToken cToken) external override view returns (uint) {
        // Return 1e18 for ETH
        if (cToken.isCEther()) return 1e18;

        // Get underlying ERC20 token address
        address underlying = CErc20(address(cToken)).underlying();

        // Get price, format, and return
        uint256 baseUnit = 10 ** uint256(ERC20Upgradeable(underlying).decimals());
        return _price(underlying).mul(1e18).div(baseUnit);
    }
    
    /**
     * @dev Internal function returning the price in ETH of `underlying`.
     */
    function _price(address underlying) internal view returns (uint) {
        // Return 1e18 for WETH
        if (underlying == WETH_ADDRESS) return 1e18;

        // Call Keep3r for ERC20/ETH price and return
        address pair = uniswapV2Factory.getPair(underlying, WETH_ADDRESS);
        uint256 baseUnit = 10 ** uint256(ERC20Upgradeable(underlying).decimals());
        return (underlying < WETH_ADDRESS ? price0TWAP(pair) : price1TWAP(pair)).div(2 ** 56).mul(baseUnit).div(2 ** 56); // Scaled by 1e18, not 2 ** 112
    }

    /**
     * @dev Returns the price in ETH of `underlying` (implements `BasePriceOracle`).
     */
    function price(address underlying) external override view returns (uint) {
        return _price(underlying);
    }
}
