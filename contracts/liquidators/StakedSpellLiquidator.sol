// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../external/abracadabra/sSpell.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title StakedSpellLiquidator
 * @notice Redeems Staked Spell Tokens (sSPELL) for underlying SPELL for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract StakedSpellLiquidator is IRedemptionStrategy {
    /**
     * @notice Redeems custom collateral `token` for an underlying token.
     * @param inputToken The input wrapped token to be redeemed for an underlying token.
     * @param inputAmount The amount of the input wrapped token to be redeemed for an underlying token.
     * @param strategyData The ABI-encoded data to be used in the redemption strategy logic.
     * @return outputToken The underlying ERC20 token outputted.
     * @return outputAmount The quantity of underlying tokens outputted.
     */
    function redeem(IERC20Upgradeable inputToken, uint256 inputAmount, bytes memory strategyData) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
        // Unstake sSPELL (and store output SPELL as new collateral)
        sSpellV1 sSpell = sSpellV1(address(inputToken));
        require(sSpell.burn(address(this), inputAmount), "Failed to burn sSPELL.");
        outputToken = IERC20Upgradeable(sSpell.token());
        outputAmount = outputToken.balanceOf(address(this));
    }
}
