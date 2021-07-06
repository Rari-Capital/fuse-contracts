# Fuse Contracts: Deployed Smart Contracts

As follows are all deployments of our smart contracts on the Ethereum mainnet.

## Latest Versions

### `FusePoolDirectory`

`FusePoolDirectory` deploys and catalogs all Fuse interest rate pools.

**v1.0.0**: `0x835482FE0532f169024d5E9410199369aAD5C77E`

### `FuseSafeLiquidator`

`FuseSafeLiquidator` safely liquidates unhealthy borrowers (with flashloan support).

**v1.0.0**: `0xcc29fe6a0e090d464abb616e1ae4ceea415c140e`

### `FusePoolLens`

`FusePoolLens` returns data on Fuse interest rate pools in mass for viewing by dApps, bots, etc.

**v1.0.0**: `0x8dA38681826f4ABBe089643D2B3fE4C6e4730493`

### `FuseFeeDistributor`

`FuseFeeDistributor` controls and receives protocol fees from Fuse pools and relays admin actions to Fuse pools.

**v1.0.1**: `0xa731585ab05fC9f83555cf9Bff8F58ee94e18F85`

### `ChainlinkPriceOracle`

`ChainlinkPriceOracle` reads prices from hardcoded Chainlink feeds.

**v1.0.0**: `0xe102421A85D9C0e71C0Ef1870DaC658EB43E1493`

### `Keep3rPriceOracle`

`Keep3rPriceOracle` reads TWAPs from [`Keep3rV1Oracle`](https://etherscan.io/address/0x73353801921417f465377c8d898c6f4c0270282c) and [`SushiswapV1Oracle`](https://etherscan.io/address/0xf67Ab1c914deE06Ba0F264031885Ea7B276a7cDa#code).

**v1.0.0** (Uniswap): `0xb90de476d438b37a4a143bf729a9b2237e544af6`

**v1.0.0** (SushiSwap): `0x08d415f90ccfb971dfbfdd6266f9a7cb1c166fc0`

### `Keep3rV2PriceOracle`

`Keep3rPriceOracle` reads TWAPs from a `Keep3rV2OracleFactory`. (Our factory is deployed at [`0x31e43cEe5433945dBa82C09dFfe8aE29edbb27c3`](https://etherscan.io/address/0x31e43cEe5433945dBa82C09dFfe8aE29edbb27c3).)

**v1.0.2** (Uniswap): `0xd6a8cac634e59c00a3d4163f839d068458e39869`

### `MasterPriceOracle`

`MasterPriceOracle` maps ERC20 tokens to specific underlying price oracle contracts.

**v1.0.0**: `0x1887118E49e0F4A78Bd71B792a49dE03504A764D`
