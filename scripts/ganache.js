const ganache = require("ganache-core");
require('dotenv').config();
const server = ganache.server({ fork: process.env.DEVELOPMENT_WEB3_PROVIDER_URL_TO_BE_FORKED, gasLimit: 12.5e6, gasPrice: 1e6, unlocked_accounts: [process.env.DEVELOPMENT_ADDRESS, process.env.DEVELOPMENT_ADDRESS_SECONDARY], logger: console });
server.listen(8546);
