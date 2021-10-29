# Changelog

## `v1.1.0` (contracts deployed; all code pushed)

* New `FuseSafeLiquidator`:
    * Chain any combination of collateral redemption strategies.
    * Use any `UniswapV2Router02` (i.e., Uniswap V2, SushiSwap).
    * Enable flashbots with `ethToCoinbase` parameter.
* Created new oracles:
    * `CurveLpTokenPriceOracle`
    * `CurveLiquidityGaugeV2PriceOracle`
    * `YearnYVaultV1PriceOracle`
    * `YearnYVaultV2PriceOracle`
    * `FixedEthPriceOracle`
    * `FixedEurPriceOracle`
    * `AlphaHomoraV2PriceOracle`
* Created new liquidator collateral redemption strategies:
    * `CurveLpTokenLiquidator`
    * `CurveLiquidityGaugeV2Liquidator`
    * `YearnYVaultV1Liquidator`
    * `YearnYVaultV2Liquidator`
    * `UniswapLpTokenLiquidator`
    * `PoolTogetherLiquidator`
    * `CurveSwapLiquidator`
    * `BalancerPoolTokenLiquidator`
    * `CErc20Liquidator`
    * `CEtherLiquidator`
    * `AlphaHomoraV2SafeBoxLiquidator`
    * `AlphaHomoraV2SafeBoxETHLiquidator`
    * `CustomLiquidator`
    * `SynthetixSynthLiquidator`
    * `AlphaHomoraV1BankLiquidator`
* Confirm functions called in `FuseFeeDistributor._callPool` do not revert. 

## `v1.0.5` (contracts deployed; all code pushed)

* Created `ChainlinkPriceOracleV2`.

## `v1.0.4` (contracts deployed; all code pushed)

* Fixed bug in `FuseSafeLiquidator`.

## `v1.0.3` (contracts deployed 2021-04-06; all code pushed 2021-04-17)

* Created `UniswapTwapPriceOracle`.

## `v1.0.2` (contracts deployed 2021-04-02; all code pushed 2021-04-17)

* Created `Keep3rV2PriceOracle`.

## `v1.0.1` (contracts deployed 2021-03-21; all code pushed 2021-04-17)

* Added `_callPool` functions to `FuseFeeDistributor`.
