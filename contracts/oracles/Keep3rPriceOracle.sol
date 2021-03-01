pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "../external/keep3r/Keep3rV1Oracle.sol";

import "./BasePriceOracle.sol";

/**
 * @title Keep3rPriceOracle
 * @notice Returns prices from `Keep3rV1Oracle` or `SushiswapV1Oracle`.
 * @dev Implements `PriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract Keep3rPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Constructor that sets the Keep3rV1Oracle or SushiswapV1Oracle.
     */
    constructor (bool sushiSwap) public {
        oracle = Keep3rV1Oracle(sushiSwap ? 0xf67Ab1c914deE06Ba0F264031885Ea7B276a7cDa : 0x73353801921417F465377c8d898c6f4C0270282C);
    }

    /**
     * @dev mStable imUSD ERC20 token contract object.
     */
    Keep3rV1Oracle public oracle = Keep3rV1Oracle(0x73353801921417F465377c8d898c6f4C0270282C);

    /**
     * @dev WETH token contract address.
     */
    address constant public WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    
    /**
     * @dev Returns the price in ETH of the token underlying `cToken` (implements `PriceOracle`).
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
    function _price(address underlying) internal view returns (uint) {
        // Return 1e18 for WETH
        if (underlying == WETH_ADDRESS) return 1e18;

        // Call Keep3r for ERC20/ETH price and return
        uint256 baseUnit = 10 ** uint256(ERC20Upgradeable(underlying).decimals());
        return oracle.current(underlying, baseUnit, WETH_ADDRESS);
    }

    /**
     * @dev Returns the price in ETH of `underlying` (implements `BasePriceOracle`).
     */
    function price(address underlying) external override view returns (uint) {
        return _price(underlying);
    }
}
