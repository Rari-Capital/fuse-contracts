// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "../external/badger/Sett.sol";

/**
 * @title BadgerSettLiquidatorEnclave
 * @notice Internal component to redeems a Badger Sett for underlying tokens for use as a step in a liquidation.
 * @dev This contract was created because we need to whitelist a contract that can only withdraw from a Sett and not deposit. We cannot use BadgerSettLiquidator because FuseSafeLiquidator delegatecalls to it, meaning the address to whitelist would be FuseSafeLiquidator, which is open to permissionless strategies.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract BadgerSettLiquidatorEnclave {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @notice Withdraws all from the Sett `inputToken`.
     */
    function withdrawAll(Sett inputToken) external returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
        inputToken.withdrawAll();
        outputToken = IERC20Upgradeable(inputToken.token());
        outputAmount = outputToken.balanceOf(address(this));
        outputToken.safeTransfer(msg.sender, outputAmount);
    }
}
