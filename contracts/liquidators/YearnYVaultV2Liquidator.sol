// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../external/yearn/IVaultV2.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title YearnYVaultV2Liquidator
 * @notice Exchanges seized Yearn yVault V2 token collateral for underlying tokens for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract YearnYVaultV2Liquidator is IRedemptionStrategy {
    /**
     * @notice Redeems custom collateral `token` for an underlying token.
     * @param inputToken The input wrapped token to be redeemed for an underlying token.
     * @param inputAmount The amount of the input wrapped token to be redeemed for an underlying token.
     * @param strategyData The ABI-encoded data to be used in the redemption strategy logic.
     * @return outputToken The underlying ERC20 token outputted.
     * @return outputAmount The quantity of underlying tokens outputted.
     */
    function redeem(IERC20Upgradeable inputToken, uint256 inputAmount, bytes memory strategyData) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
        // Redeem yVault token for underlying token (and store output as new collateral)
        IVaultV2 yVault = IVaultV2(address(inputToken));
        outputAmount = yVault.withdraw(inputAmount);
        outputToken = IERC20Upgradeable(yVault.token());
    }
}
