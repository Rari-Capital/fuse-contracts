const ganache = require("ganache-core");
require('dotenv').config();
var unlocked_accounts = [process.env.DEVELOPMENT_ADDRESS];
if (process.env.UPGRADE_FUSE_OWNER_ADDRESS) unlocked_accounts.push(process.env.UPGRADE_FUSE_OWNER_ADDRESS);
const server = ganache.server({ fork: process.env.DEVELOPMENT_WEB3_PROVIDER_URL_TO_BE_FORKED, gasLimit: 12.5e6, gasPrice: 1e6, unlocked_accounts, logger: console });
server.listen(8546);
