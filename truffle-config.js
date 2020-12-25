const HDWalletProvider = require("@truffle/hdwallet-provider");
require('dotenv').config();

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // for more about customizing your Truffle configuration!
  networks: {
    development: {
      host: "127.0.0.1",
      port: "8546",
      network_id: "*",
      gasPrice: 1e6,
      from: process.env.DEVELOPMENT_ADDRESS
    },
    live: {
      provider: function() {
        var keys = [process.env.LIVE_DEPLOYER_PRIVATE_KEY];
        return new HDWalletProvider(keys, process.env.LIVE_WEB3_PROVIDER_URL);
      },
      network_id: 1,
      gasPrice: parseInt(process.env.LIVE_GAS_PRICE),
      from: process.env.LIVE_DEPLOYER_ADDRESS
    }
  },
  compilers: {
    solc: {
      version: "0.6.12",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200
        }
      }
    }
  }
};
