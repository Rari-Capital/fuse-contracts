// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../external/pooltogether/ControlledTokenInterface.sol";
import "../external/pooltogether/PrizePoolInterface.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title PoolTogetherLiquidator
 * @notice Redeems PoolTogether PcTokens for underlying assets for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract PoolTogetherLiquidator is IRedemptionStrategy {
    /**
     * @notice Redeems custom collateral `token` for an underlying token.
     * @param inputToken The input wrapped token to be redeemed for an underlying token.
     * @param inputAmount The amount of the input wrapped token to be redeemed for an underlying token.
     * @param strategyData The ABI-encoded data to be used in the redemption strategy logic.
     * @return outputToken The underlying ERC20 token outputted.
     * @return outputAmount The quantity of underlying tokens outputted.
     */
    function redeem(IERC20Upgradeable inputToken, uint256 inputAmount, bytes memory strategyData) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
        // Redeem PcToken (and store output as new collateral)
        ControlledTokenInterface token = ControlledTokenInterface(address(inputToken));
        PrizePoolInterface controller = PrizePoolInterface(token.controller());
        controller.withdrawInstantlyFrom(address(this), inputAmount, address(token), uint256(-1));
        outputToken = IERC20Upgradeable(controller.token());
        outputAmount = inputAmount;
    }
}
