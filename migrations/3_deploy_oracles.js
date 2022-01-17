// SPDX-License-Identifier: UNLICENSED
require('dotenv').config();

var MasterPriceOracle = artifacts.require("./MasterPriceOracle.sol");
var InitializableClones = artifacts.require("./InitializableClones.sol");
var ChainlinkPriceOracleV2Arbitrum = artifacts.require("./ChainlinkPriceOracleV2Arbitrum.sol");
var UniswapV3TwapPriceOracleV2 = artifacts.require("./UniswapV3TwapPriceOracleV2.sol");
var UniswapV3TwapPriceOracleV2Factory = artifacts.require("./UniswapV3TwapPriceOracleV2Factory.sol");
var UniswapTwapPriceOracleV2 = artifacts.require("./UniswapTwapPriceOracleV2.sol");
var UniswapTwapPriceOracleV2Root = artifacts.require("./UniswapTwapPriceOracleV2Root.sol");
var UniswapTwapPriceOracleV2Factory = artifacts.require("./UniswapTwapPriceOracleV2Factory.sol");
var FixedEthPriceOracle = artifacts.require("./FixedEthPriceOracle.sol");

module.exports = async function(deployer, network, accounts) {
  // Deploy MasterPriceOracle implementation and InitializableClones
  var mpoImplementation = await deployer.deploy(MasterPriceOracle);
  var initializableClones = await deployer.deploy(InitializableClones);

  // Deploy UniswapTwapPriceOracleV2
  var uniswapTwapPriceOracleV2 = await deployer.deploy(UniswapTwapPriceOracleV2);
  var uniswapTwapPriceOracleV2Root = await deployer.deploy(UniswapTwapPriceOracleV2Root);
  await deployer.deploy(UniswapTwapPriceOracleV2Factory, UniswapTwapPriceOracleV2Root.address, UniswapTwapPriceOracleV2.address);

  // Deploy UniswapV3TwapPriceOracleV2Factory
  var uniswapV3TwapPriceOracleV2 = await deployer.deploy(UniswapV3TwapPriceOracleV2);
  await deployer.deploy(UniswapV3TwapPriceOracleV2Factory, UniswapV3TwapPriceOracleV2.address);

  // Prepare default MPO constructor args
  var defaultMpoUnderlyings = [];
  var defaultMpoOracles = [];

  // Arbitrum only
  if (["arbitrum", "arbitrum-fork", "arbitrum_rinkleby"].indexOf(network) >= 0) {
    // Deploy ChainlinkPriceOracleV2Arbitrum
    var chainlinkPriceOracleV2 = await deployer.deploy(ChainlinkPriceOracleV2Arbitrum, process.env.LIVE_DEPLOYER_ADDRESS, true);

    // Set WBTC to BTC/ETH feed
    await chainlinkPriceOracleV2.setPriceFeeds(
      [
        "0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f", // WBTC
      ],
      [
        "0xc5a90A6d7e4Af242dA238FFe279e9f2BA0c64B2e", // BTC / ETH
      ],
      0
    );

    // Set USD-based feeds
    await chainlinkPriceOracleV2.setPriceFeeds(
      [
        "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1", // DAI
        "0x69eb4fa4a2fbd498c257c57ea8b7655a2559a581", // DODO
        "0x17fc002b466eec40dae837fc4be5c67993ddbd6f", // FRAX
        "0xf97f4df75117a78c1a5a0dbb814af92458539fb4", // LINK
        "0xfea7a6a0b346362bf88a9e4a88416b77a57d6c2a", // MIM
        "0x6e6a3d8f1affac703b1aef1f43b8d2321be40043", // OHMv2
        "0x3e6648c5a70a150a88bce65f4ad4d506fe15d2af", // SPELL
        "0xd4d42f0b6def4ce0383636770ef773390d85c61a", // SUSHI
        "0xfa7f8980b0f1e64a2062791cc3b0871572f1f7f0", // UNI
        "0xff970a61a04b1ca14834a43f5de4533ebddb5cc8", // USDC
        "0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9", // USDT
        "0x82e3a8f066a6989666b031d916c43672085b1582", // YFI
      ],
      [
        // "0xaD1d5344AaDE45F43E596773Bcc4c423EAbdD034", // AAVE / USD
        "0xc5C8E77B397E531B8EC06BFb0048328B30E9eCfB", // DAI / USD
        "0xA33a06c119EC08F92735F9ccA37e07Af08C4f281", // DODO / USD
        "0x0809E3d38d1B4214958faf06D8b1B1a2b73f2ab8", // FRAX / USD
        "0x86E53CF1B870786351Da77A57575e79CB55812CB", // LINK / USD
        "0x87121F6c9A9F6E90E59591E4Cf4804873f54A95b", // MIM / USD
        "0x761aaeBf021F19F198D325D7979965D0c7C9e53b", // OHMv2 / USD
        "0x383b3624478124697BEF675F07cA37570b73992f", // SPELL / USD
        "0xb2A8BA74cbca38508BA1632761b56C897060147C", // SUSHI / USD
        // "0x4CfC4AB701cF5E45EF12F50458dA6bB279D7ed5B", // TOKE / USD
        "0x9C917083fDb403ab5ADbEC26Ee294f6EcAda2720", // UNI / USD
        "0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3", // USDC / USD
        "0x3f3f5dF88dC9F13eac63DF89EC16ef6e7E25DdE7", // USDT / USD
        "0x745Ab5b69E01E2BE1104Ca84937Bb71f96f5fB21", // YFI / USD
      ],
      1
    );

    // Deploy FixedEthPriceOracle for WETH
    var fixedEthPriceOracle = await deployer.deploy(FixedEthPriceOracle);

    // Deploy official Rari DAO MasterPriceOracle
    defaultMpoUnderlyings = [
      "0x82af49447d8a07e3bd95bd0d56f35241523fbab1", // WETH
      "0x2f2a2543b76a4166549f7aab2e75bef0aefc5b0f", // WBTC
      "0xda10009cbd5d07dd0cecc66161fc93d7c9000da1", // DAI
      "0x69eb4fa4a2fbd498c257c57ea8b7655a2559a581", // DODO
      "0x17fc002b466eec40dae837fc4be5c67993ddbd6f", // FRAX
      "0xf97f4df75117a78c1a5a0dbb814af92458539fb4", // LINK
      "0xfea7a6a0b346362bf88a9e4a88416b77a57d6c2a", // MIM
      "0x6e6a3d8f1affac703b1aef1f43b8d2321be40043", // OHMv2
      "0x3e6648c5a70a150a88bce65f4ad4d506fe15d2af", // SPELL
      "0xd4d42f0b6def4ce0383636770ef773390d85c61a", // SUSHI
      "0xfa7f8980b0f1e64a2062791cc3b0871572f1f7f0", // UNI
      "0xff970a61a04b1ca14834a43f5de4533ebddb5cc8", // USDC
      "0xfd086bc7cd5c481dcc9c85ebe478a1c0b69fcbb9", // USDT
      "0x82e3a8f066a6989666b031d916c43672085b1582", // YFI
    ];
    defaultMpoOracles = [FixedEthPriceOracle.address].concat(Array(13).fill(ChainlinkPriceOracleV2Arbitrum.address));
  } else {
    // Deploy ChainlinkPriceOracleV2
    var chainlinkPriceOracleV2 = await deployer.deploy(ChainlinkPriceOracleV2, process.env.LIVE_DEPLOYER_ADDRESS, true);

    // Deploy ChainlinkPriceOracleV3
    var chainlinkPriceOracleV3 = await deployer.deploy(ChainlinkPriceOracleV3, process.env.LIVE_DEPLOYER_ADDRESS, true);
  }

  // Deploy official Rari DAO MasterPriceOracle
  var sentTx = await initializableClones.clone(MasterPriceOracle.address, web3.eth.abi.encodeFunctionSignature("initialize(address[],address[],address,address,bool)") + web3.eth.abi.encodeParameters(["address[]", "address[]", "address", "address", "bool"], [
    defaultMpoUnderlyings,
    defaultMpoOracles,
    "0x0000000000000000000000000000000000000000",
    process.env.LIVE_DEPLOYER_ADDRESS,
    true
  ]).substring(2));

  // Get deployed MPO from receipt
  var defaultMasterPriceOracle;
  for (const log of sentTx.logs)
    if (log.address.toLowerCase() === initializableClones.address.toLowerCase() && log.event == "Deployed")
      defaultMasterPriceOracle = await MasterPriceOracle.at(log.args.instance);
  console.log("Default MasterPriceOracle:", defaultMasterPriceOracle.address);

  // Live network: transfer ownership of deployed contracts from the deployer to the owner
  if (["live", "live-fork"].indexOf(network) >= 0 && process.env.LIVE_OWNER && process.env.LIVE_DEPLOYER_ADDRESS.toLowerCase() !== process.env.LIVE_OWNER.toLowerCase()) {
    await chainlinkPriceOracleV2.changeAdmin(process.env.LIVE_OWNER);
    await defaultMasterPriceOracle.changeAdmin(process.env.LIVE_OWNER);
  }
};
