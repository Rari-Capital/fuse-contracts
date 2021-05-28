// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../external/curve/ICurveRegistry.sol";
import "../external/curve/ICurvePool.sol";

import "../external/aave/IWETH.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title CurveSwapLiquidator
 * @notice Swaps seized token collateral via Curve as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract CurveSwapLiquidator is IRedemptionStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev WETH contract object.
     */
    IWETH constant private WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

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
        // Exchange and store output
        (ICurvePool curvePool, int128 i, int128 j, address jToken) = abi.decode(strategyData, (ICurvePool, int128, int128, address));
        outputToken = IERC20Upgradeable(jToken == 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE ? address(0) : jToken);
        safeApprove(inputToken, address(curvePool), inputAmount);
        outputAmount = curvePool.exchange(i, j, inputAmount, 0);

        // Convert to WETH if ETH because `FuseSafeLiquidator.repayTokenFlashLoan` only supports tokens (not ETH) as output from redemptions (reverts on line 24 because `underlyingCollateral` is the zero address) 
        if (address(outputToken) == address(0)) {
            WETH.deposit{value: outputAmount}();
            return (IERC20Upgradeable(address(WETH)), outputAmount);
        }
    }
}
