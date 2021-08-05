import {ethers, upgrades} from 'hardhat';

async function main() {
    const [signer] = await ethers.getSigners();
    const FusePoolDirectoryFactory = await ethers.getContractFactory("FusePoolDirectory");
    const FuseSafeLiquidatorFactory = await ethers.getContractFactory(
        "FuseSafeLiquidator"
    );
    const FusePoolLensFactory = await ethers.getContractFactory("FusePoolLens");


    const fusePoolDirectory = await upgrades.deployProxy(
        FusePoolDirectoryFactory,
        [true, [signer.address]],
        {
            unsafeAllow: ["struct-definition", "enum-definition"]
        }
    )
    console.log("Fuse Pool Directory: ", fusePoolDirectory.address);

    const fuseSafeLiquidator = await FuseSafeLiquidatorFactory.deploy();
    console.log("Fuse Safe Liquidator: ", fuseSafeLiquidator.address);
    const fusePoolLens = await upgrades.deployProxy(FusePoolLensFactory, [fusePoolDirectory.address], {
        unsafeAllow: ["struct-definition", "enum-definition"]
    });

    console.log("Fuse Pool Lens: ", fusePoolLens.address);
}

main()
    .then(() => console.log("✅ finished deployer execution"))
    .catch((err) => console.log("❌ failed to deploy: ", err));
