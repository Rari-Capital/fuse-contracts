// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../external/floor/FloorStaking.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title GFloorLiquidator
 * @notice Redeems gFloor for underlying Floor for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract GFloorLiquidator is IRedemptionStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev Floor staking contract.
     */
    FloorStaking constant public FLOOR_STAKING = FloorStaking(0x759c6De5bcA9ADE8A1a2719a31553c4B7DE02539);

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
        // Unstake gFloor (and store output Floor as new collateral)
        safeApprove(inputToken, address(FLOOR_STAKING), inputAmount);
        outputAmount = FLOOR_STAKING.unstake(address(this), inputAmount, true, false);
        outputToken = IERC20Upgradeable(FLOOR_STAKING.gFloor());
    }
}
