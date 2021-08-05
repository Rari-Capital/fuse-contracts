import "dotenv/config";
import { HardhatUserConfig } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "@openzeppelin/hardhat-upgrades";
import "./tasks/accounts";
import { parseEther } from "@ethersproject/units";

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
const compilerSettings = {
  metadata: {
    // Not including the metadata hash
    // https://github.com/paulrberg/solidity-template/issues/31
    bytecodeHash: "none",
  },
  // You should disable the optimizer when debugging
  // https://hardhat.org/hardhat-network/#solidity-optimizer-support
  optimizer: {
    enabled: true,
    runs: 800,
  },
};
const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.6.12",
        settings: compilerSettings,
      },
      {
        version: "0.7.0",
        settings: compilerSettings,
      },
    ],
  },

  networks: {
    hardhat: {
      forking: {
        url: process.env.FORK_RPC!,
      },
      accounts: [
        {
          privateKey: process.env.DEV_PRIVATE_KEY!,
          balance: parseEther("1000").toString(),
        },
      ],
    },
  },
};

export default config;
