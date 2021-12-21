// SPDX-License-Identifier: UNLICENSED
const { deployProxy, admin } = require('@openzeppelin/truffle-upgrades');
require('dotenv').config();

var FusePoolDirectory = artifacts.require("./FusePoolDirectory.sol");
var FuseSafeLiquidator = artifacts.require("./FuseSafeLiquidator.sol");
var FuseFeeDistributor = artifacts.require("./FuseFeeDistributor.sol");
var FusePoolLens = artifacts.require("./FusePoolLens.sol");
var FusePoolLensSecondary = artifacts.require("./FusePoolLensSecondary.sol");
var FusePoolDirectoryArbitrum = artifacts.require("./FusePoolDirectoryArbitrum.sol");
var FuseFeeDistributorArbitrum = artifacts.require("./FuseFeeDistributorArbitrum.sol");
var FuseSafeLiquidatorArbitrum = artifacts.require("./FuseSafeLiquidatorArbitrum.sol");

module.exports = async function(deployer, network, accounts) {
  // Validate .env
  if (["live", "live-fork"].indexOf(network) >= 0) {
    if (!process.env.LIVE_GAS_PRICE) return console.error("LIVE_GAS_PRICE is missing for live deployment");
    if (!process.env.LIVE_OWNER) return console.error("LIVE_OWNER is missing for live deployment");
  }

  if (parseInt(process.env.UPGRADE_FROM_LAST_VERSION) > 0) {
    // Upgrade from v1.0.0 (only modifying FuseFeeDistributor v1.0.0) to v1.1.0
    if (!process.env.UPGRADE_POOL_DIRECTORY_ADDRESS) return console.error("UPGRADE_POOL_DIRECTORY_ADDRESS is missing for upgrade");
    if (!process.env.UPGRADE_POOL_LENS_ADDRESS) return console.error("UPGRADE_POOL_LENS_ADDRESS is missing for upgrade");
    if (!process.env.UPGRADE_FEE_DISTRIBUTOR_ADDRESS) return console.error("UPGRADE_FEE_DISTRIBUTOR_ADDRESS is missing for upgrade");
  } else {
    // Deploy FusePoolDirectory
    var fusePoolDirectory = await deployProxy(["arbitrum", "arbitrum-fork", "arbitrum_rinkleby"].indexOf(network) >= 0 ? FusePoolDirectoryArbitrum : FusePoolDirectory, [false, []], { deployer, unsafeAllowCustomTypes: true });
    
    // Deploy FuseSafeLiquidator
    await deployer.deploy(["arbitrum", "arbitrum-fork", "arbitrum_rinkleby"].indexOf(network) >= 0 ? FuseSafeLiquidatorArbitrum : FuseSafeLiquidator);
    
    // Deploy FuseFeeDistributor
    var fuseFeeDistributor = await deployProxy(["arbitrum", "arbitrum-fork", "arbitrum_rinkleby"].indexOf(network) >= 0 ? FuseFeeDistributorArbitrum : FuseFeeDistributor, [web3.utils.toBN(10e16).toString()], { deployer });
    
    // Deploy FusePoolLens
    await deployProxy(FusePoolLens, [fusePoolDirectory.address], { deployer, unsafeAllowCustomTypes: true });
    await deployProxy(FusePoolLensSecondary, [fusePoolDirectory.address], { deployer, unsafeAllowCustomTypes: true });

    // Set pool limits
    await fuseFeeDistributor._setPoolLimits(web3.utils.toBN(0.001e18), web3.utils.toBN(2).pow(web3.utils.toBN(256)).subn(1), web3.utils.toBN(2).pow(web3.utils.toBN(256)).subn(1));

    // Live network: transfer ownership of deployed contracts from the deployer to the owner
    if (["live", "live-fork"].indexOf(network) >= 0) {
      await fusePoolDirectory.transferOwnership(process.env.LIVE_OWNER);
      await fuseFeeDistributor.transferOwnership(process.env.LIVE_OWNER);
      await admin.transferProxyAdminOwnership(process.env.LIVE_OWNER);
    }
  }
};
