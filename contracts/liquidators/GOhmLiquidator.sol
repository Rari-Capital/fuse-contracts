// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../external/olympus/OlympusV2Staking.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title GOhmLiquidator
 * @notice Redeems gOHM for underlying OHM for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract GOhmLiquidator is IRedemptionStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev OHM V2 OlympusStaking contract.
     */
    OlympusV2Staking constant public OLYMPUS_STAKING = OlympusV2Staking(0xB63cac384247597756545b500253ff8E607a8020);

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
        // Unstake gOHM (and store output OHM as new collateral)
        safeApprove(inputToken, address(OLYMPUS_STAKING), inputAmount);
        outputAmount = OLYMPUS_STAKING.unstake(address(this), inputAmount, true, false);
        outputToken = IERC20Upgradeable(OLYMPUS_STAKING.OHM());
    }
}
