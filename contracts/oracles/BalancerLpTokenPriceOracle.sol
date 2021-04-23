// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "../external/balancer/IBalancerPool.sol";
import "../external/balancer/BNum.sol";

import "./BasePriceOracle.sol";

/**
 * @title BalancerLpTokenPriceOracle
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice BalancerLpTokenPriceOracle is a price oracle for Balancer LP tokens.
 * @dev Implements the `PriceOracle` interface used by Fuse pools (and Compound v2).
 */
contract BalancerLpTokenPriceOracle is PriceOracle, BasePriceOracle, BNum {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice Get the LP token price price for an underlying token address.
     * @param underlying The underlying token address for which to get the price (set to zero address for ETH).
     * @return Price denominated in ETH (scaled by 1e18).
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
     * @dev Fetches the fair LP token/ETH price from Balancer, with 18 decimals of precision.
     * Source: https://github.com/AlphaFinanceLab/homora-v2/blob/master/contracts/oracle/BalancerPairOracle.sol
     */
    function _price(address underlying) internal view virtual returns (uint) {
        IBalancerPool pool = IBalancerPool(underlying);
        require(pool.getNumTokens() == 2, "Balancer pool must have exactly 2 tokens.");
        address[] memory tokens = pool.getFinalTokens();
        address tokenA = tokens[0];
        address tokenB = tokens[1];
        uint256 pxA = BasePriceOracle(msg.sender).price(tokenA);
        uint256 pxB = BasePriceOracle(msg.sender).price(tokenB);
        uint8 decimalsA = ERC20Upgradeable(tokenA).decimals();
        uint8 decimalsB = ERC20Upgradeable(tokenB).decimals();
        if (decimalsA < 18) pxA = pxA.mul(10 ** (18 - uint256(decimalsA)));
        if (decimalsA > 18) pxA = pxA.div(10 ** (uint256(decimalsA) - 18));
        if (decimalsB < 18) pxB = pxB.mul(10 ** (18 - uint256(decimalsB)));
        if (decimalsB > 18) pxB = pxB.div(10 ** (uint256(decimalsB) - 18));
        (uint256 fairResA, uint256 fairResB) = computeFairReserves(
            pool.getBalance(tokenA),
            pool.getBalance(tokenB),
            pool.getNormalizedWeight(tokenA),
            pool.getNormalizedWeight(tokenB),
            pxA,
            pxB
        );
        // use fairReserveA and fairReserveB to compute LP token price
        // LP price = (fairResA * pxA + fairResB * pxB) / totalLPSupply
        return fairResA.mul(pxA).add(fairResB.mul(pxB)).div(pool.totalSupply());
    }

    /**
     * @dev Returns fair reserve amounts given spot reserves, weights, and fair prices.
     * Source: https://github.com/AlphaFinanceLab/homora-v2/blob/master/contracts/oracle/BalancerPairOracle.sol
     * @param resA Reserve of the first asset
     * @param resB Reserev of the second asset
     * @param wA Weight of the first asset
     * @param wB Weight of the second asset
     * @param pxA Fair price of the first asset
     * @param pxB Fair price of the second asset
     */
    function computeFairReserves(uint256 resA, uint256 resB, uint256 wA, uint256 wB, uint256 pxA, uint256 pxB) internal pure returns (uint256 fairResA, uint256 fairResB) {
        // NOTE: wA + wB = 1 (normalize weights)
        // constant product = resA^wA * resB^wB
        // constraints:
        // - fairResA^wA * fairResB^wB = constant product
        // - fairResA * pxA / wA = fairResB * pxB / wB
        // Solving equations:
        // --> fairResA^wA * (fairResA * (pxA * wB) / (wA * pxB))^wB = constant product
        // --> fairResA / r1^wB = constant product
        // --> fairResA = resA^wA * resB^wB * r1^wB
        // --> fairResA = resA * (resB/resA)^wB * r1^wB = resA * (r1/r0)^wB
        uint256 r0 = bdiv(resA, resB);
        uint256 r1 = bdiv(bmul(wA, pxB), bmul(wB, pxA));
        // fairResA = resA * (r1 / r0) ^ wB
        // fairResB = resB * (r0 / r1) ^ wA
        if (r0 > r1) {
            uint256 ratio = bdiv(r1, r0);
            fairResA = bmul(resA, bpow(ratio, wB));
            fairResB = bdiv(resB, bpow(ratio, wA));
        } else {
            uint256 ratio = bdiv(r0, r1);
            fairResA = bdiv(resA, bpow(ratio, wB));
            fairResB = bmul(resB, bpow(ratio, wA));
        }
    }
}