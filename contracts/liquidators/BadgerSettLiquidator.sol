// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../external/badger/Sett.sol";

import "./IRedemptionStrategy.sol";
import "./BadgerSettLiquidatorEnclave.sol";

/**
 * @title BadgerSettLiquidator
 * @notice Redeems a Badger Sett for underlying tokens for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract BadgerSettLiquidator is IRedemptionStrategy {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @notice Internal "enclave" which is whitelisted to redeem Badger Setts.
     */
    BadgerSettLiquidatorEnclave public immutable enclave;

    /**
     * @notice Constructor to deploy BadgerSettLiquidatorEnclave.
     */
    constructor() public {
        enclave = new BadgerSettLiquidatorEnclave();
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
        Sett token = Sett(address(inputToken));
        inputToken.safeTransfer(address(enclave), inputAmount);
        (outputToken, outputAmount) = enclave.withdrawAll(token);
    }
}
