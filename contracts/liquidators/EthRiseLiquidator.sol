// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../external/risedle/IRiseTokenVault.sol";

import "../external/aave/IWETH.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title EthRiseLiquidator
 * @notice Redeems EthRise for underlying WETH for use as a step in a liquidation.
 * @author Sri Yantra <sriyantra@rari.capital>, David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract EthRiseLiquidator is IRedemptionStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @notice Risedle Vault
     */
    IRiseTokenVault public rVault = IRiseTokenVault(0xf7EDB240DbF7BBED7D321776AFe87D1FBcFD0A94);

    /**
     * @dev WETH contract object.
     */
    IWETH constant private WETH = IWETH(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);

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
        safeApprove(inputToken, address(rVault), inputAmount);
        rVault.removeSupply(inputAmount);

        // convert ETH to WETH
        outputAmount = address(this).balance;
        WETH.deposit{value: outputAmount}();
        return (IERC20Upgradeable(address(WETH)), outputAmount);
    }
}
