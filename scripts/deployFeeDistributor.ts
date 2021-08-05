const {ethers, upgrades} = require("hardhat");

async function main() {
    const FuseFeeDistributorFactory = await ethers.getContractFactory("FuseFeeDistributor");
    const fuseFeeDistributor = await upgrades.deployProxy(FuseFeeDistributorFactory, [ethers.utils.parseUnits("1", 16)])
    const MAX_UINT_256 = ethers.BigNumber.from(2).pow(ethers.BigNumber.from(256)).sub(1);

    /**
     * @notice we're setting parameters such as minBorrowETH, maxSupplyETH and maxUtilizationRate
     */
    await fuseFeeDistributor._setPoolLimits(
        ethers.utils.parseEther("1"),
        MAX_UINT_256,
        MAX_UINT_256
    );
    console.log("Fuse Fee Distributor is at:", fuseFeeDistributor.address);
}
main()
    .then(() => console.log("✅ finished deployer execution"))
    .catch((err) => console.log("❌ failed to deploy: ", err));
