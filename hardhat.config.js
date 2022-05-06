require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-ethers");
require("@nomiclabs/hardhat-etherscan");
//require('hardhat-abi-exporter');
require('dotenv').config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.6.12"
      }
    ],
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  abiExporter: {
    path: './abi/',
    clear: true,
  },
  networks: {
    hardhat: {
      gasPrice: 470000000000,
      chainId: 43112,
    },
    mainnet: {
      url: process.env.ALCHEMY_MAINNET,
      accounts: [process.env.ETH_PRIVATE_KEY]
    },
    arbitrum : {
      url: process.env.ALCHEMY_ARBITRUM
    },
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    //apiKey: process.env.ETHERSCAN_API_KEY
    apiKey: process.env.ETHERSCAN_API_KEY
  },
};
