// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/balancer/IStablePool.sol";

import "./BasePriceOracle.sol";

/**
 * @title BalancerStableLpTokenPriceOracle
 * @notice Returns prices for stable pool Balancer Lp tokens with more than 2 assets.
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract BalancerStableLpTokenPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev bbaUSD BPT token contract.
     */
    IStablePool constant public bbaUSD = IStablePool(0x7B50775383d3D6f0215A8F290f2C9e2eEBBEceb2);

    /**
     * @dev WBTC/renBTC/sBTC BPT token contract.
     */
    IStablePool constant public staBTC = IStablePool(0xFeadd389a5c427952D8fdb8057D6C8ba1156cC56);

    /**
     * @dev WBTC ERC20 token contract.
     */
    address public constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    /**
     * @dev DAI ERC20 token contract.
     */
    address public constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

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
        if (token == address(bbaUSD)) {
            return bbaUSD.getRate().mul(BasePriceOracle(msg.sender).price(DAI)).div(1e18);
        } else if (token == address(staBTC)) {
            return staBTC.getRate().mul(BasePriceOracle(msg.sender).price(WBTC)).div(1e18);
        } else revert("Invalid token address passed to BalancerStableLpTokenPriceOracle.");
    }
}
