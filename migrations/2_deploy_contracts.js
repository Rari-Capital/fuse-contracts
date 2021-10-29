// SPDX-License-Identifier: UNLICENSED
const { deployProxy, upgradeProxy, admin } = require('@openzeppelin/truffle-upgrades');
require('dotenv').config();

var FusePoolDirectory = artifacts.require("./FusePoolDirectory.sol");
var FuseSafeLiquidator = artifacts.require("./FuseSafeLiquidator.sol");
var FuseFeeDistributor = artifacts.require("./FuseFeeDistributor.sol");
var FusePoolLens = artifacts.require("./FusePoolLens.sol");

module.exports = async function(deployer, network, accounts) {
  // Validate .env
  if (["live", "live-fork"].indexOf(network) >= 0) {
    if (!process.env.LIVE_GAS_PRICE) return console.error("LIVE_GAS_PRICE is missing for live deployment");
    if (!process.env.LIVE_OWNER) return console.error("LIVE_OWNER is missing for live deployment");
  }

  if (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0) {
    // TODO: Deploy `UniswapV3TwapPriceOracle`
  } else {
    // Deploy FusePoolDirectory
    var fusePoolDirectory = await deployProxy(FusePoolDirectory, [["live", "live-fork"].indexOf(network) >= 0, ["live", "live-fork"].indexOf(network) >= 0 ? [process.env.LIVE_OWNER] : []], { deployer, unsafeAllowCustomTypes: true });
    
    // Deploy FuseSafeLiquidator
    await deployer.deploy(FuseSafeLiquidator);
    
    // Deploy FuseFeeDistributor
    var fuseFeeDistributor = await deployProxy(FuseFeeDistributor, [web3.utils.toBN(10e16).toString()], { deployer });
    
    // Deploy FusePoolLens
    await deployProxy(FusePoolLens, [FusePoolDirectory.address], { deployer, unsafeAllowCustomTypes: true });

    // Set pool limits
    await fuseFeeDistributor._setPoolLimits(web3.utils.toBN(1e18), web3.utils.toBN(2).pow(web3.utils.toBN(256)).subn(1), web3.utils.toBN(2).pow(web3.utils.toBN(256)).subn(1));

    // Live network: transfer ownership of deployed contracts from the deployer to the owner
    if (["live", "live-fork"].indexOf(network) >= 0) {
      await fusePoolDirectory.transferOwnership(process.env.LIVE_OWNER);
      await fuseFeeDistributor.transferOwnership(process.env.LIVE_OWNER);
      await admin.transferProxyAdminOwnership(process.env.LIVE_OWNER);
    }
  }
};
