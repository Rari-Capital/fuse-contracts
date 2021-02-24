/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * No one is permitted to use the software for any purpose without the explicit permission of David Lucid of Rari Capital, Inc.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

const { deployProxy, admin } = require('@openzeppelin/truffle-upgrades');
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
  
  // Deploy FusePoolDirectory
  await deployProxy(FusePoolDirectory, [], { deployer, unsafeAllowCustomTypes: true });
  
  // Deploy FuseSafeLiquidator
  await deployer.deploy(FuseSafeLiquidator);
  
  // Deploy FuseFeeDistributor
  await deployProxy(FuseFeeDistributor, [web3.utils.toBN(10e16).toString()], { deployer });
  
  // Deploy FusePoolLens
  await deployProxy(FusePoolLens, [FusePoolDirectory.address], { deployer, unsafeAllowCustomTypes: true });

  // Live network: transfer ownership of deployed contracts from the deployer to the owner
  if (["live", "live-fork"].indexOf(network) >= 0) await admin.transferProxyAdminOwnership(process.env.LIVE_OWNER);
};
