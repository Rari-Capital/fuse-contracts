// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "./BasePriceOracle.sol";
import "./UniswapTwapPriceOracleV2Root.sol";

/**
 * @title UniswapTwapPriceOracleV2
 * @notice Stores cumulative prices and returns TWAPs for assets on Uniswap V2 pairs.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract UniswapTwapPriceOracleV2 is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Constructor that sets the UniswapV2Factory.
     */
    constructor (address _rootOracle, address _uniswapV2Factory, address _baseToken) public {
        rootOracle = UniswapTwapPriceOracleV2Root(_rootOracle);
        uniswapV2Factory = _uniswapV2Factory;
        baseToken = _baseToken == address(0) ? address(WETH) : _baseToken;
    }

    /**
     * @dev WETH token contract address.
     */
    address constant public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @dev UniswapTwapPriceOracleV2Root contract address.
     */
    UniswapTwapPriceOracleV2Root immutable public rootOracle;

    /**
     * @dev UniswapV2Factory contract address.
     */
    address immutable public uniswapV2Factory;

    /**
     * @dev The token on which to base TWAPs (its price must be available via `msg.sender`).
     */
    address immutable public baseToken;
    
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
        if (underlying == WETH) return 1e18;

        // Return root oracle ERC20/ETH TWAP
        uint256 twap = rootOracle.price(underlying, baseToken, uniswapV2Factory);
        uint256 baseTokenBaseUnit = 10 ** uint256(ERC20Upgradeable(baseToken).decimals());
        return baseToken == address(0) ? twap : twap.mul(BasePriceOracle(msg.sender).price(baseToken)).div(baseTokenBaseUnit);
    }

    /**
     * @dev Returns the price in ETH of `underlying` (implements `BasePriceOracle`).
     */
    function price(address underlying) external override view returns (uint) {
        return _price(underlying);
    }
}
