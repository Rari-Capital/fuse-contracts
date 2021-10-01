// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import "@uniswap/v3-periphery/contracts/libraries/OracleLibrary.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "./BasePriceOracle.sol";

/**
 * @title UniswapV3TwapPriceOracle
 * @notice Stores cumulative prices and returns TWAPs for assets on Uniswap V3 pairs.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract UniswapV3TwapPriceOracle is BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev WETH token contract address.
     */
    address constant public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @dev Ideal TWAP interval.
     */
    uint32 public constant TWAP_PERIOD = 10 minutes;

    /**
     * @dev IUniswapV3Factory contract address.
     */
    address immutable public uniswapV3Factory;

    /**
     * @dev Uniswap V3 fee tier.
     */
    uint24 immutable public feeTier;
    
    /**
     * @dev Returns the price in ETH of `underlying` given `factory`.
     */
    function _price(address underlying) internal view returns (uint) {
        // Return 1e18 for WETH
        if (underlying == WETH) return 1e18;

        // Return token/WETH TWAP
        address pool = IUniswapV3Factory(uniswapV3Factory).getPool(underlying, WETH, feeTier);
        int24 timeWeightedAverageTick = OracleLibrary.consult(pool, TWAP_PERIOD);
        uint128 baseUnit = 10 ** uint128(ERC20Upgradeable(underlying).decimals());
        return OracleLibrary.getQuoteAtTick(timeWeightedAverageTick, baseUnit, underlying, WETH);
    }

    /**
     * @dev Constructor that sets the UniswapV3Factory and fee tier.
     */
    constructor (address _uniswapV3Factory, uint24 _feeTier) public {
        require(_uniswapV3Factory != address(0));
        require(_feeTier == 500 || _feeTier == 3000 || _feeTier == 10000);
        uniswapV3Factory = _uniswapV3Factory;
        feeTier = _feeTier;
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
     * @dev Returns the price in ETH of `underlying` (implements `BasePriceOracle`).
     */
    function price(address underlying) external override view returns (uint) {
        return _price(underlying);
    }
}
