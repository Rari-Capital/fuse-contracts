// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
// If this script is run directly usig `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // Deploy CErc20PluginDelegate
  const RewardsDistributorDelegator = await ethers.getContractFactory("UniswapV3TwapPriceOracleV2");
  const rewardsDistributorDelegator = await RewardsDistributorDelegator.deploy();
  await rewardsDistributorDelegator.deployed();
  //const CErc20PluginDelegate = await ethers.getContractFactory("CErc20PluginRewardsDelegate");

  //const pluginDelegate = await CErc20PluginDelegate.deploy();
  //await pluginDelegate.deployed();

  console.log("oracle", rewardsDistributorDelegator.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
