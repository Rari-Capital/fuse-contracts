// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../external/ichi/ICHICommon.sol";
import "../external/ichi/IOneTokenV1.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title OneFoxLiquidator
 * @notice Redeems oneFOX for USDC for use as a step in a liquidation.
 * @author Zerosnacks <zerosnacks@protonmail.com> (https://github.com/zerosnacks)
 */
contract OneFoxLiquidator is IRedemptionStrategy, ICHICommon {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    /**
     * @dev USDC contract object.
     */
    IERC20Upgradeable constant private USDC = IERC20Upgradeable(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

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
        // Redeem oneFox for USDC
        IOneTokenV1 token = IOneTokenV1(address(inputToken));

        // TODO: is this necessary as the redemption happens inside of the oneFox contract?
        safeApprove(inputToken, address(token), inputAmount);

        // TODO: currently set at 0, is there a way to avoid this SLOAD
        uint256 redemptionFee = token.redemptionFee();

        outputToken = USDC;
        token.redeem(address(USDC), inputAmount);

        if (redemptionFee != 0) {
            // NOTE: the redeem method does not return the outputted amount so we have to re-compute it ourselves
            outputAmount = amount.sub(amount.mul(redemptionFee).div(PRECISION));
        } else {
            outputAmount = inputAmount;
        }
    }
}
