# Fuse Contracts: Deployed Smart Contracts

As follows are all deployments of our smart contracts on the Ethereum mainnet.

## Latest Versions

### `FusePoolDirectory`

`FusePoolDirectory` deploys and catalogs all Fuse interest rate pools.

**v1.0.0**: `0x835482FE0532f169024d5E9410199369aAD5C77E`

### `FuseSafeLiquidator`

`FuseSafeLiquidator` safely liquidates unhealthy borrowers (with flashloan support).

**v1.0.4**: `0x41C7F2D48bde2397dFf43DadA367d2BD3527452F`

### `FusePoolLens`

`FusePoolLens` returns data on Fuse interest rate pools in mass for viewing by dApps, bots, etc.

**v1.0.0**: `0x8dA38681826f4ABBe089643D2B3fE4C6e4730493`

### `FuseFeeDistributor`

`FuseFeeDistributor` controls and receives protocol fees from Fuse pools and relays admin actions to Fuse pools.

**v1.0.1**: `0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85`

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

## Older Versions

### `FuseSafeLiquidator`

* **v1.0.0**: `0xcc29fe6a0e090d464abb616e1ae4ceea415c140e`

### `FuseFeeDistributor`

* **v1.0.0**: `0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85`
