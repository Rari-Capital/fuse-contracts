pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "../external/uniswap/IUniswapV2Pair.sol";

import "./BasePriceOracle.sol";

/**
 * @title UniswapLpTokenPriceOracle
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice UniswapLpTokenPriceOracle is a price oracle for Uniswap (and SushiSwap) LP tokens.
 * @dev Implements the `PriceOracle` interface used by Fuse pools (and Compound v2).
 */
contract UniswapLpTokenPriceOracle is PriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev WETH contract address.
     */
    address constant private WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @notice Get the LP token price price for an underlying token address
     * @param underlying The underlying token address for which to get the price (set to zero address for ETH)
     * @return Price denominated in ETH (scaled by 1e18)
     */
    function price(address underlying) external view returns (uint) {
        return _price(underlying);
    }

    /**
     * @notice Get the underlying price of a cToken
     * @dev Implements the PriceOracle interface for Fuse pools (and Compound v2).
     * @param cToken The cToken address for price retrieval
     * @return Price denominated in ETH, with 18 decimals, for the given cToken address
     */
    function getUnderlyingPrice(CToken cToken) external override view returns (uint) {
        address underlying = CErc20(address(cToken)).underlying();
        // Comptroller needs prices to be scaled by 1e(36 - decimals)
        // Since `_price` returns prices scaled by 18 decimals, we must scale them by 1e(36 - 18 - decimals)
        return _price(underlying).mul(1e18).div(10 ** uint256(ERC20Upgradeable(underlying).decimals()));
    }

    /**
     * @dev Fetches the fair LP token token/ETH price from Uniswap, with 18 decimals of precision.
     */
    function _price(address token) internal view virtual returns (uint) {
        IUniswapV2Pair pair = IUniswapV2Pair(token);
        uint totalSupply = pair.totalSupply();
        if (totalSupply == 0) return 0;
        (uint reserve0, uint reserve1, ) = pair.getReserves();
        address token0 = pair.token0();
        address token1 = pair.token1();

        // Get fair price of non-WETH token (underlying the pair) in terms of ETH
        uint token0FairPrice = token0 == WETH_ADDRESS ? 1e18 : BasePriceOracle(msg.sender).price(token0).mul(1e18).div(10 ** uint256(ERC20Upgradeable(token0).decimals()));
        uint token1FairPrice = token1 == WETH_ADDRESS ? 1e18 : BasePriceOracle(msg.sender).price(token1).mul(1e18).div(10 ** uint256(ERC20Upgradeable(token1).decimals()));

        // Implementation from https://github.com/AlphaFinanceLab/homora-v2/blob/e643392d582c81f6695136971cff4b685dcd2859/contracts/oracle/UniswapV2Oracle.sol#L18
        uint256 sqrtK = sqrt(reserve0.mul(reserve1)).mul(2 ** 112).div(totalSupply);
        return sqrtK.mul(2).mul(sqrt(token0FairPrice)).div(2 ** 56).mul(sqrt(token1FairPrice)).div(2 ** 56);
    }

    /**
     * @dev Fast square root function.
     * Implementation from: https://github.com/Uniswap/uniswap-lib/commit/99f3f28770640ba1bb1ff460ac7c5292fb8291a0
     * Original implementation: https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.sol#L687
     */
    function sqrt(uint x) internal pure returns (uint) {
        if (x == 0) return 0;
        uint xx = x;
        uint r = 1;

        if (xx >= 0x100000000000000000000000000000000) {
            xx >>= 128;
            r <<= 64;
        }
        if (xx >= 0x10000000000000000) {
            xx >>= 64;
            r <<= 32;
        }
        if (xx >= 0x100000000) {
            xx >>= 32;
            r <<= 16;
        }
        if (xx >= 0x10000) {
            xx >>= 16;
            r <<= 8;
        }
        if (xx >= 0x100) {
            xx >>= 8;
            r <<= 4;
        }
        if (xx >= 0x10) {
            xx >>= 4;
            r <<= 2;
        }
        if (xx >= 0x8) {
            r <<= 1;
        }

        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1;
        r = (r + x / r) >> 1; // Seven iterations should be enough
        uint r1 = x / r;
        return (r < r1 ? r : r1);
    }
}
