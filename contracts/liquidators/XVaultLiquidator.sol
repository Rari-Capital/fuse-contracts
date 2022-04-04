// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../external/nftx/INFTXInventoryStaking.sol";
import "../external/nftx/INFTXVaultUpgradeable.sol";
import "../external/nftx/IXTokenUpgradeable.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title NFTX xVault Liquidator
 * @notice Redeems xVault assets for underlying assets for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract XVaultLiquidator is IRedemptionStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @notice INFTXInventoryStaking contract address.
     */
    INFTXInventoryStaking staking = INFTXInventoryStaking(0x3E135c3E981fAe3383A5aE0d323860a34CfAB893);

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
        // Unstake xVault asset (and store output asset as new collateral)
        IXTokenUpgradeable xToken = IXTokenUpgradeable(address(inputToken));
        INFTXVaultUpgradeable vault = INFTXVaultUpgradeable(xToken.baseToken());
        safeApprove(inputToken, address(staking), inputAmount);
        staking.withdraw(vault.vaultId(), inputAmount);
        outputToken = IERC20Upgradeable(address(vault));
        outputAmount = inputAmount;
    }
}
