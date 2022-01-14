// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../external/fodl/FodlStake.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title StakedFodlLiquidator
 * @notice Redeems staked FODL (xFODL) for underlying FODL for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract StakedFodlLiquidator is IRedemptionStrategy {
    /**
     * @notice Redeems custom collateral `token` for an underlying token.
     * @param inputToken The input wrapped token to be redeemed for an underlying token.
     * @param inputAmount The amount of the input wrapped token to be redeemed for an underlying token.
     * @param strategyData The ABI-encoded data to be used in the redemption strategy logic.
     * @return outputToken The underlying ERC20 token outputted.
     * @return outputAmount The quantity of underlying tokens outputted.
     */
    function redeem(IERC20Upgradeable inputToken, uint256 inputAmount, bytes memory strategyData) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
        // Unstake sOHM (and store output OHM as new collateral)
        FodlStake stakedFodl = FodlStake(address(inputToken));
        outputAmount = stakedFodl.unstake(inputAmount);
        outputToken = stakedFodl.fodlToken();
    }
}
