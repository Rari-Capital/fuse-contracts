# Fuse Contracts: Deployed Smart Contracts

As follows are all deployments of our smart contracts on the Ethereum mainnet.

## Latest Core

### `FusePoolDirectory`

`FusePoolDirectory` deploys and catalogs all Fuse interest rate pools.

**v1.2.0**: `0x835482FE0532f169024d5E9410199369aAD5C77E`

### `FuseSafeLiquidator`

`FuseSafeLiquidator` safely liquidates unhealthy borrowers (with flashloan support).

**v1.1.0**: `0x1bbf310c8707bc2248c0b46a2cd073c81f2cd76c`

### `FusePoolLens`

`FusePoolLens` returns data on Fuse interest rate pools in mass for viewing by dApps, bots, etc.

**v1.2.0**: `0x6Dc585Ad66A10214Ef0502492B0CC02F0e836eec`

### `FusePoolLensSecondary`

`FusePoolLensSecondary` returns data on Fuse interest rate pools in mass for viewing by dApps, bots, etc.

**v1.2.0**: `0xc76190E04012f26A364228Cfc41690429C44165d`

### `FuseFeeDistributor`

`FuseFeeDistributor` controls and receives protocol fees from Fuse pools and relays admin actions to Fuse pools.

**v1.2.0**: `0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85`

# Latest Oracles

### `ChainlinkPriceOracle`

`ChainlinkPriceOracle` reads prices from hardcoded Chainlink feeds.

**v1.0.0**: `0xe102421A85D9C0e71C0Ef1870DaC658EB43E1493`

### `ChainlinkPriceOracleV2`

`ChainlinkPriceOracle` reads prices from Chainlink feeds set by an admin.

**v1.0.5**: `0xb0602af43Ca042550ca9DA3c33bA3aC375d20Df4`

### `Keep3rPriceOracle`

`Keep3rPriceOracle` reads TWAPs from [`Keep3rV1Oracle`](https://etherscan.io/address/0x73353801921417f465377c8d898c6f4c0270282c) and [`SushiswapV1Oracle`](https://etherscan.io/address/0xf67Ab1c914deE06Ba0F264031885Ea7B276a7cDa#code).

**v1.0.0** (Uniswap): `0xb90de476d438b37a4a143bf729a9b2237e544af6`

**v1.0.0** (SushiSwap): `0x08d415f90ccfb971dfbfdd6266f9a7cb1c166fc0`

### `Keep3rV2PriceOracle`

`Keep3rPriceOracle` reads TWAPs from a `Keep3rV2OracleFactory`. (Our factory is deployed at [`0x31e43cEe5433945dBa82C09dFfe8aE29edbb27c3`](https://etherscan.io/address/0x31e43cEe5433945dBa82C09dFfe8aE29edbb27c3).)

**v1.0.2** (Uniswap): `0xd6a8cac634e59c00a3d4163f839d068458e39869`

### `UniswapTwapPriceOracle`

`UniswapTwapPriceOracle` wraps the `UniswapTwapPriceOracleRoot` logic contract and contains all TWAP reading logic. Supports Uniswap/SushiSwap/etc.

**v1.0.3** (Uniswap): `0xCd8f1c72Ff98bFE3B307869dDf66f5124D57D3a9`

**v1.0.3** (SushiSwap): `0xfD4B4552c26CeBC54cD80B1BDABEE2AC3E7eB324`

### `UniswapTwapPriceOracleRoot`

`UniswapTwapPriceOracleRoot` sits at the root of the `UniswapTwapPriceOracle` wrapper contracts and contains all TWAP storage logic. Supports Uniswap/SushiSwap/etc.

**v1.0.3**: `0xa170dba2cd1f68cdd7567cf70184d5492d2e8138`

### `MasterPriceOracle`

`MasterPriceOracle` maps ERC20 tokens to specific underlying price oracle contracts.

**v1.0.0**: `0x1887118E49e0F4A78Bd71B792a49dE03504A764D`

### `CurveLpTokenPriceOracle`

`CurveLpTokenPriceOracle` is a price oracle for Curve LP tokens (using the sender as a root oracle).

**v1.1.0**: `0x43c534203339bbf15f62b8dde91e7d14195e7a60`

### `CurveLiquidityGaugeV2PriceOracle`

`CurveLiquidityGaugeV2PriceOracle` is a price oracle for Curve LiquidityGaugeV2 tokens (using the sender as a root oracle).

**v1.1.0**: `0xd9eefdb09d75ca848433079ea72ef609a1c1ea21`

### `YVaultV1PriceOracle`

`YVaultV1PriceOracle` returns prices for V1 yVaults (using the sender as a root oracle).

**v1.1.0**: `0xb04be6165cf1879310e48f8900ad8c647b9b5c5d`

### `YVaultV2PriceOracle`

`YVaultV2PriceOracle` returns prices for V2 yVaults (using the sender as a root oracle).

**v1.1.0**: `0xb669d0319fb9de553e5c206e6fbebd58512b668b`

### `FixedEthPriceOracle`

`FixedEthPriceOracle` returns fixed prices of 1 ETH for all tokens (expected to be used under a `MasterPriceOracle`).

**v1.1.0**: `0xffc9ec4adbf75a537e4d233720f06f0df01fb7f5`

### `FixedEurPriceOracle`

`FixedEurPriceOracle` returns fixed prices of 1 EUR in terms of ETH for all tokens (expected to be used under a `MasterPriceOracle`).

**v1.1.0**: `0x817158553F4391B0d53d242fC332f2eF82463e2a`

### `FixedTokenPriceOracle`

`FixedTokenPriceOracle` returns token prices using the prices for another token (expected to be used under a `MasterPriceOracle`).

**v1.1.2** (OHM): `0x71FE48562B816D03Ce9e2bbD5aB28674A8807CC5`

### `UniswapTwapPriceOracleV2`

`UniswapTwapPriceOracleV2` returns TWAPs for assets on Uniswap V2 pairs (to be used with `UniswapTwapPriceOracleV2Root`).

**v1.1.2** (SushiSwap, DAI): `0x72fd4c801f5845ab672a12bce1b05bdba1fd851a`
**v1.1.3** (SushiSwap, USDC): `0x9ee412a83a52f033d23a0b7e2e030382b3e53208`
**v1.1.3** (SushiSwap, CRV): `0x552163f2a63f82bb47b686ffc665ddb3ceaca0ea`

### `UniswapTwapPriceOracleV2Root`

`UniswapTwapPriceOracleV2Root` stores cumulative prices for assets on Uniswap V2 pairs (to be used with `UniswapTwapPriceOracleV2`).

**v1.1.2** (Uniswap, DAI): `0xf1860b3714f0163838cf9ee3adc287507824ebdb`

### `WSTEthPriceOracle`

`WSTEthPriceOracle` returns prices for wstETH based on stETH/ETH price (expected to be used under a `MasterPriceOracle`).

**v1.1.2**: `0xb11de4c003c80dc36a810254b433d727ac71c517`

### `SushiBarPriceOracle`

`SushiBarPriceOracle` returns prices for SushiBar (xSUSHI) based on SUSHI/ETH price (expected to be used under a `MasterPriceOracle`).

**v1.1.2**: `0x290E0f31e96e13f9c0DB14fD328a3C2A94557245`

### `UniswapV3TwapPriceOracle`

`UniswapV3TwapPriceOracle` stores cumulative prices and returns TWAPs for assets on Uniswap V3 pairs (with WETH as a base token).

**v1.1.1** (Uniswap, 0.3%): `0x80829b8A344741E28ae70374Be02Ec9d4b51CD89`

### `UniswapV3TwapPriceOracleV2`

`UniswapV3TwapPriceOracleV2` stores cumulative prices and returns TWAPs for assets on Uniswap V3 pairs (for base tokens other than WETH).

**v1.1.2** (Uniswap, 1.0%, USDC): `0x3288a2d5f11FcBefbf77754e073cAD2C10325dE2`

### `UniswapLpTokenPriceOracle`

`UniswapLpTokenPriceOracle` is a price oracle for Uniswap (and SushiSwap) LP tokens (expected to be used under a `MasterPriceOracle`).

**v1.0.0**: `0x50f42c004bd9b0e5acc65c33da133fbfbe86c7c0`

## Latest Liquidators

### `CurveLpTokenLiquidator`

`CurveLpTokenLiquidator` redeems seized Curve LP token collateral for underlying tokens for use as a step in a liquidation.

**v1.1.0**: `0xb5eEaeB4E7e0a9feD003ED402016342A09FC2784`

### `CurveLiquidityGaugeV2Liquidator`

`CurveLiquidityGaugeV2Liquidator` redeems seized Curve LiquidityGaugeV2 collateral for underlying tokens for use as a step in a liquidation.

**v1.1.0**: `0x97e6E953C9a9250c8e889D888158F27752e0aFe0`

### `YearnYVaultV2Liquidator`

`YearnYVaultV2Liquidator` redeems seized Yearn yVault V2 collateral for underlying tokens for use as a step in a liquidation.

**v1.1.0**: `0x50293EB96E90616faD66CEF227EDA2b344F592c0`

### `PoolTogetherLiquidator`

`PoolTogetherLiquidator` redeems seized PoolTogether PcTokens for underlying tokens for use as a step in a liquidation.

**v1.1.0**: `0xDDB0d86fDBF33210Ba6EFc97757fFcdBF26B5530`

### `WSTEthLiquidator`

`WSTEthLiquidator` redeems seized PoolTogether PcTokens for underlying tokens for use as a step in a liquidation.

**v1.1.2**: `0xca844845a3578296b3fcfe50fc3a1064a2922fbc`

### `CurveSwapLiquidator`

`CurveSwapLiquidator` redeems seized PoolTogether PcTokens for underlying tokens for use as a step in a liquidation.

**v1.1.0**: `0xebea141052d759b75c4c9eeaad28f07f329d0163`

### `UniswapV1Liquidator`

`UniswapV1Liquidator` redeems seized PoolTogether PcTokens for underlying tokens for use as a step in a liquidation.

**v1.1.2**: `0x9fa9ffa397be8e33930571dcd9f5f92b629b0fad`

### `UniswapV2Liquidator`

`UniswapV2Liquidator` redeems seized PoolTogether PcTokens for underlying tokens for use as a step in a liquidation.

**v1.1.2**: `0x8db1884def49b001c0b9b2fd5ba8e8b71f69b958`

### `UniswapV3Liquidator`

`UniswapV3Liquidator` redeems seized PoolTogether PcTokens for underlying tokens for use as a step in a liquidation.

**v1.1.2**: `0x5E829D997294F7f1d40a45C0f6431aF13a381E63`

### `UniswapLpTokenLiquidator`

`UniswapLpTokenLiquidator` redeems seized PoolTogether PcTokens for underlying tokens for use as a step in a liquidation.

**v1.1.0**: `0x3659a0a9128ee84f143bdc83c4f3932cd8f552e7`

### `SushiBarLiquidator`

`SushiBarLiquidator` redeems seized PoolTogether PcTokens for underlying tokens for use as a step in a liquidation.

**v1.1.2**: `0x5F2dF200636e203863819CbEaA02017CFabEc4D6`

### `SOhmLiquidator`

`SOhmLiquidator` redeems seized PoolTogether PcTokens for underlying tokens for use as a step in a liquidation.

**v1.1.2**: `0xeBC0752232697F17EbfAA1f26aB8543EcEC35AE3`

## Older Versions

### `FusePoolDirectory`

* **v1.0.0**: `0x835482FE0532f169024d5E9410199369aAD5C77E`

### `FuseSafeLiquidator`

* **v1.0.4**: `0x41C7F2D48bde2397dFf43DadA367d2BD3527452F`
* **v1.0.0**: `0xcc29fe6a0e090d464abb616e1ae4ceea415c140e`

### `FusePoolLens`

* **v1.0.0**: `0x8dA38681826f4ABBe089643D2B3fE4C6e4730493`

### `FuseFeeDistributor`

* **v1.0.1**: `0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85`
* **v1.0.0**: `0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85`
