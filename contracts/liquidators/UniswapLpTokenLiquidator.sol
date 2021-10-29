// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../external/uniswap/IUniswapV2Router02.sol";
import "../external/uniswap/IUniswapV2Pair.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title UniswapLpTokenLiquidator
 * @notice Exchanges seized Uniswap V2 LP token collateral for underlying tokens for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract UniswapLpTokenLiquidator is IRedemptionStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev Internal function to approve unlimited tokens of `erc20Contract` to `to`.
     */
    function safeApprove(IERC20Upgradeable token, address to, uint256 minAmount) private {
        uint256 allowance = token.allowance(address(this), to);

        if (allowance < minAmount) {
            if (allowance > 0) token.safeApprove(to, 0);
            token.safeApprove(to, uint256(-1));
        }
    }

    /**
     * @notice Redeems custom collateral `token` for an underlying token.
     * @param inputToken The input wrapped token to be redeemed for an underlying token.
     * @param inputAmount The amount of the input wrapped token to be redeemed for an underlying token.
     * @param strategyData The ABI-encoded data to be used in the redemption strategy logic.
     * @return outputToken The underlying ERC20 token outputted.
     * @return outputAmount The quantity of underlying tokens outputted.
     */
    function redeem(IERC20Upgradeable inputToken, uint256 inputAmount, bytes memory strategyData) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
        // Exit Uniswap pool
        IUniswapV2Pair pair = IUniswapV2Pair(address(inputToken));
        address token0 = pair.token0();
        address token1 = pair.token1();
        pair.transfer(address(pair), inputAmount);
        (uint amount0, uint amount1) = pair.burn(address(this));

        // Swap underlying tokens
        (IUniswapV2Router02 uniswapV2Router, address[] memory swapToken0Path, address[] memory swapToken1Path) = abi.decode(strategyData, (IUniswapV2Router02, address[], address[]));
        require((swapToken0Path.length > 0 ? swapToken0Path[swapToken0Path.length - 1] : token0) == (swapToken1Path.length > 0 ? swapToken1Path[swapToken1Path.length - 1] : token1), "Output of token0 swap path must equal output of token1 swap path.");

        if (swapToken0Path.length > 0 && swapToken0Path[swapToken0Path.length - 1] != token0) {
            safeApprove(IERC20Upgradeable(token0), address(uniswapV2Router), amount0);
            uniswapV2Router.swapExactTokensForTokens(amount0, 0, swapToken0Path, address(this), block.timestamp);
        }

        if (swapToken1Path.length > 0 && swapToken1Path[swapToken1Path.length - 1] != token1) {
            safeApprove(IERC20Upgradeable(token1), address(uniswapV2Router), amount1);
            uniswapV2Router.swapExactTokensForTokens(amount1, 0, swapToken1Path, address(this), block.timestamp);
        }

        // Get new collateral
        outputToken = IERC20Upgradeable(swapToken0Path.length > 0 ? swapToken0Path[swapToken0Path.length - 1] : token0);
        outputAmount = outputToken.balanceOf(address(this));
    }
}
