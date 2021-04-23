# Fuse by Rari Capital: Smart Contracts

This repository contains the Solidity source code for the smart contracts behind the pool deployer, directory, lens, liquidator, and oracles for Fuse's open ecosystem of interest rate pools, built on top of our fork of [`compound-protocol`](https://github.com/Rari-Capital/compound-protocol/tree/fuse-v1.0.1). See [here for the Rari dApp](https://github.com/Rari-Capital/rari-dapp) or [here for the Fuse SDK](https://github.com/Rari-Capital/rari-dApp/tree/master/src/fuse-sdk).

## How it works

Fuse by Rari Capital is a decentralized ecosystem of interest rate pools based on the Ethereum blockchain. At the core of Fuse is our fork of [`compound-protocol`](https://github.com/Rari-Capital/compound-protocol/tree/fuse-v1.0.1), and on top of Fuse is `fuse-contracts`, containing our pool deployer, directory, lens, liquidator, and oracles. A high-level overview of how Fuse works is available in [`CONCEPT.md`](CONCEPT.md). Find out more about Fuse and Rari Capital at [rari.capital](https://rari.capital).

## Installation (for development and deployment)

We, as well as others, had success using Truffle on Node.js `v12.18.2` with the latest version of NPM.

To install the latest version of Truffle: `npm install -g truffle`

*Though the latest version of Truffle should work, to compile, deploy, and test our contracts, we used Truffle `v5.1.45` (which should use `solc` version `0.6.12+commit.27d51765.Emscripten.clang` and Web3.js `v1.2.1`).*

To install all our dependencies: `npm install`

## Compiling the contracts

`npm run compile`

## Testing the contracts

In `.env`, set `DEVELOPMENT_ADDRESS=0x45D54B22582c79c8Fb8f4c4F2663ef54944f397a` to test deployment and run automated tests.

To test the contracts, first fork the Ethereum mainnet. Begin by configuring `DEVELOPMENT_WEB3_PROVIDER_URL_TO_BE_FORKED` in `.env` (set to any mainnet Web3 HTTP provider JSON-RPC URL; we use a local `geth` instance, specifically a light client started with `geth --syncmode light --rpc --rpcapi eth,web3,debug,net`; Infura works too, but beware of latency and rate limiting). To start the fork, run `npm run ganache`. *If you would like to change the port, make sure to configure `scripts/ganache.js`, `scripts/test.sh`, and the `development` network in `truffle-config.js`.* Note that you will likely have to regularly restart your fork, especially when forking from a node without archive data or when using live 0x API responses to make currency exchanges.

To deploy the contracts to your private mainnet fork: `truffle migrate --network development --skip-dry-run --reset`

To run automated tests on the contracts on your private mainnet fork, run `npm test` (which runs `npm run ganache` in the background for you).

## Live deployment

In `.env`, configure `LIVE_DEPLOYER_ADDRESS`, `LIVE_DEPLOYER_PRIVATE_KEY`, `LIVE_WEB3_PROVIDER_URL`, `LIVE_GAS_PRICE` (ideally, use the "fast" price listed by [ETH Gas Station](https://www.ethgasstation.info/)), and `LIVE_OWNER` to deploy to the mainnet.

Then, migrate: `truffle migrate --network live`

## License

See `LICENSE`.

## Credits

Fuse's smart contracts are developed by [David Lucid](https://github.com/davidlucid) of Rari Capital. Find out more about Rari Capital at [rari.capital](https://rari.capital).
