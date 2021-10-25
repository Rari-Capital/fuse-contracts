# Changelog

## `v1.1.6` (contracts deployed; all code pushed)

* Created new oracles:
    * `ChainlinkPriceOracleV3`
    * `GelatoGUniPriceOracle`
    * `MStablePriceOracle`
    * `TokemakPoolTAssetPriceOracle`
* Created new liquidator collateral redemption strategies:
    * `GelatoGUniLiquidator`
    * `MStableLiquidator`
    * `DolaStabilizerLiquidator`
    * `CurveMetapoolLpTokenLiquidator`

## `v1.1.5` (contracts deployed; all code pushed)

* Created `StakedSdtPriceOracle` and `StakedSdtLiquidator`.

## `v1.1.4` (contracts deployed; all code pushed)

* Created new oracles:
    * `HarvestPriceOracle`
    * `BadgerPriceOracle`
* Created new liquidator collateral redemption strategies:
    * `HarvestLiquidator`
    * `BadgerSettLiquidator`
* Improvements to `PreferredPriceOracle`.
* Return output/profit in FuseSafeLiquidator.

## `v1.1.3` (contracts deployed; all code pushed)

* Minor fix to `UniswapTwapPriceOracleV2`.
* Fix QSP-1 on `ChainlinkPriceOracle` and `ChainlinkPriceOracleV2`.
* Add `maxSecondsBeforePriceIsStale` to `FixedEurPriceOracle`.

## `v1.1.2` (contracts deployed; all code pushed)

* Created new oracles:
    * `UniswapTwapPriceOracleV2`
    * `UniswapV3TwapPriceOracleV2`
    * `FixedTokenPriceOracle`
    * `SushiBarPriceOracle`
    * `WSTEthPriceOracle`
* Created new liquidator collateral redemption strategies:
    * `SOhmLiquidator`
    * `SushiBarLiquidator`
    * `WSTEthLiquidator`
    * `UniswapV1Liquidator`
    * `UniswapV2Liquidator`
    * `UniswapV3Liquidator`
* Improvements to `CustomLiquidator`.

## `v1.1.1` (contracts deployed; all code pushed)

* Created `UniswapV3TwapPriceOracle`.

## `v1.1.0` (contracts deployed; all code pushed)

* Created new oracles:
    * `CurveLpTokenPriceOracle`
    * `CurveLiquidityGaugeV2PriceOracle`
    * `YearnYVaultV1PriceOracle`
    * `YearnYVaultV2PriceOracle`
    * `FixedEthPriceOracle`
    * `FixedEurPriceOracle`
* Created new liquidator collateral redemption strategies:
    * `CurveLpTokenLiquidator`
    * `CurveLiquidityGaugeV2Liquidator`
    * `YearnYVaultV2Liquidator`
    * `PoolTogetherLiquidator`

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
