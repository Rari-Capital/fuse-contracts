// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../external/curve/ICurveRegistry.sol";
import "../external/curve/ICurvePool.sol";
import "../external/curve/ICurveLiquidityGaugeV2.sol";

import "./IRedemptionStrategy.sol";

/**
 * @title CurveLiquidityGaugeV2Liquidator
 * @notice Redeems seized Curve LiquidityGaugeV2 collateral for underlying tokens for use as a step in a liquidation.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract CurveLiquidityGaugeV2Liquidator is IRedemptionStrategy {
    /**
     * @notice Redeems custom collateral `token` for an underlying token.
     * @param inputToken The input wrapped token to be redeemed for an underlying token.
     * @param inputAmount The amount of the input wrapped token to be redeemed for an underlying token.
     * @param strategyData The ABI-encoded data to be used in the redemption strategy logic.
     * @return outputToken The underlying ERC20 token outputted.
     * @return outputAmount The quantity of underlying tokens outputted.
     */
    function redeem(IERC20Upgradeable inputToken, uint256 inputAmount, bytes memory strategyData) external override returns (IERC20Upgradeable outputToken, uint256 outputAmount) {
        // Redeem Curve liquidity gauge V2 token for Curve pool LP token (and store output as new collateral)
        ICurveLiquidityGaugeV2 gauge = ICurveLiquidityGaugeV2(address(inputToken));
        gauge.withdraw(inputAmount);
        inputToken = IERC20Upgradeable(gauge.lp_token());
        
        // Remove liquidity from Curve pool in the form of one coin only (and store output as new collateral)
        ICurvePool curvePool = ICurvePool(ICurveRegistry(0x7D86446dDb609eD0F5f8684AcF30380a356b2B4c).get_pool_from_lp_token(address(inputToken)));
        (uint8 curveCoinIndex, address underlying) = abi.decode(strategyData, (uint8, address));
        curvePool.remove_liquidity_one_coin(inputAmount, int128(curveCoinIndex), 1);
        outputToken = IERC20Upgradeable(underlying);
        outputAmount = outputToken.balanceOf(address(this));
    }
}
