## How it works

With Fuse, the open interest rate protocol, anyone can create their own lending pool with virtually any combination of assets, any risk profile, any interest rate models, any parameters, etc. As a diverse and unlimited ecosystem of decentralized banks, Fuse hopes to be a utopia for lenders, borrowers, and liquidators alike.

* Optimize for any risk profile by choosing any combination of assets and customizing all available parameters (e.g. pool close factor, pool liquidation incentive, asset interest rate models, asset collateral factor, asset reserve factor, and admin interest fee rate).

* To support virtually any asset, Fuse employs a variety of shared price oracles, including Chainlink, Uniswap and Sushiswap TWAPs, and Coinbase (anchored by Uniswap). If desired, private oracles (anchored by Uniswap) can be used as well. You can also use combinations of price oracles. Special oracles for tokens like Uniswap LP tokens, Alpha Homora positions, etc. are coming soon!

* Each Fuse pool is its own instance of a modified version of the Compound Protocol, with optimized proxy storage patterns to minimize the gas required for pool and asset deployment. This means each Fuse pool is completely independent from other Fuse pools.

* For maximum transparency and security, we provide detailed scores with market parameter verification, asset validation, oracle validation, market creator validation, market "lockdown" (no upgradeability) or delegation of governance/upgradeability to Rari or whoever else, etc.

* Safe and efficient liquidations using flash swaps/flash loans for capital to liquidate unhealthy borrows--profit is guaranteed for liquidators; and they can liquidate any pool with any assets and Fuse will automatically exchange the seized collateral to whatever currency the liquidator desires.

* Generate fees on interest if desired.
