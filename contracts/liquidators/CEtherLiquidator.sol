// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../external/compound/CEther.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title CEtherLiquidator
 * @notice Redeems seized Compound/Cream/Fuse CEther cTokens for underlying ETH for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract CEtherLiquidator is IRedemptionStrategy {
    /**
     * @notice Redeems custom collateral `token` for an underlying token.
     * @param inputToken The input wrapped token to be redeemed for an underlying token.
     * @param inputAmount The amount of the input wrapped token to be redeemed for an underlying token.
     * @param strategyData The ABI-encoded data to be used in the redemption strategy logic.
     * @return outputToken The underlying ERC20 token outputted.
     * @return outputAmount The quantity of underlying tokens outputted.
     */
    function redeem(IERC20Upgradeable inputToken, uint256 inputAmount, bytes memory strategyData) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
        // Redeem cEther for underlying ETH (and store output as new collateral)
        CEther cEther = CEther(address(inputToken));
        uint256 redeemResult = cEther.redeem(inputAmount);
        require(redeemResult == 0, "Error calling redeeming seized cEther: error code not equal to 0");
        outputToken = IERC20Upgradeable(address(0));
        outputAmount = address(this).balance;
    }
}
