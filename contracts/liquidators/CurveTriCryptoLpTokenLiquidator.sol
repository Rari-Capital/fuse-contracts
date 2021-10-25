// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../external/curve/ICurveTriCryptoLpToken.sol";
import "../external/curve/ICurvePool.sol";

import "../external/aave/IWETH.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title CurveTriCryptoLpTokenLiquidator
 * @notice Redeems seized Curve TriCrypto LP token collateral for underlying tokens for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract CurveTriCryptoLpTokenLiquidator is IRedemptionStrategy {
    /**
     * @notice Redeems custom collateral `token` for an underlying token.
     * @param inputToken The input wrapped token to be redeemed for an underlying token.
     * @param inputAmount The amount of the input wrapped token to be redeemed for an underlying token.
     * @param strategyData The ABI-encoded data to be used in the redemption strategy logic.
     * @return outputToken The underlying ERC20 token outputted.
     * @return outputAmount The quantity of underlying tokens outputted.
     */
    function redeem(IERC20Upgradeable inputToken, uint256 inputAmount, bytes memory strategyData) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
        // Remove liquidity from Curve pool in the form of one coin only (and store output as new collateral)
        ICurvePool curvePool = ICurvePool(ICurveTriCryptoLpToken(address(inputToken)).minter());
        (uint8 curveCoinIndex, address underlying) = abi.decode(strategyData, (uint8, address));
        curvePool.remove_liquidity_one_coin(inputAmount, int128(curveCoinIndex), 1);
        outputToken = IERC20Upgradeable(underlying);
        outputAmount = outputToken.balanceOf(address(this));
    }
}
