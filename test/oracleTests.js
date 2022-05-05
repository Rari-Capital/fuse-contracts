//const hre = require("hardhat");
//require("@nomiclabs/hardhat-waffle");
const { expect } = require("chai");
const { ethers } = require("hardhat");




describe("oracle test", function() {
  it("returns oracle price", async function () {
    const [signer] = await ethers.getSigners();

    /*const ETHRISE = '0x46D06cf8052eA6FdbF71736AF33eD23686eA1452';
    const USDC = '0xff970a61a04b1ca14834a43f5de4533ebddb5cc8';
    const OHM = '0x6E6a3D8F1AfFAc703B1aEF1F43B8D2321bE40043';
    const GOHM = '0x8D9bA570D6cb60C7e3e0F31343Efe75AB8E65FB1';
    const JETH = '0x662d0f9ff837a51cf89a1fe7e0882a906dac08a3';
    const JGOHM = '0x5375616bb6c52a90439ff96882a986d8fcdce421';
    */
    const WETH = '0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2';
    const ETH = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE';
    const FRAX = '0x853d955acef822db058eb8505911ed77f175b99e';
    const DAI = '0x6b175474e89094c44da98b954eedeac495271d0f';
    const USDC = '0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48';
    const USDT = '0xdac17f958d2ee523a2206206994597c13d831ec7';
    const FEI = '0x956F47F50A910163D8BF957Cf5846D573E7f87CA';
    const alUSD = '0xbc6da0fe9ad5f3b0d58160288917aa56653660e9';
    const stETH = '0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84';
    const a3CRV = '0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490';
    const MIM = '0x99d8a9c45b2eca8864373a26d1459e3dff1e17f3';
    const UST = '0xa693B19d2931d498c5B318dF961919BB4aee87a5';
    const cvxCRV = '0x62B9c7356A2Dc64a1969e19C23e4f579F9810Aa7';
    const CRV = '0xd533a949740bb3306d119cc777fa900ba034cd52';
    const FXS = '0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0';
    const PUNK = '0x269616D549D7e8Eaa82DFb17028d0B212D11232A';
    const xPUNK = '0x08765C76C758Da951DC73D3a8863B34752Dd76FB';
    const xWIZARD = '0x1ea1ccfecc55938a71c67150c41e7eba0743e94c';
    const WIZARD = '0x87931E7AD81914e7898d07c68F145fC0A553D8Fb';
    const wstETH = '0x7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0';
    const rETH = '0xae78736cd615f374d3085123a210448e74fc6393';
    const ALCX = '0xdBdb4d16EdA451D0503b854CF79D55697F90c8DF';
    const gALCX = '0x93Dede06AE3B5590aF1d4c111BC54C3f717E4b35';
    const alcxLP = '0xc3f279090a47e80990fe3a9c30d24cb117ef91a8';
    const alETHlp = '0xc9da65931ABf0Ed1b74Ce5ad8c041C4220940368';
    const alETH = '0x0100546F2cD4C9D97f798fFC9755E47865FF7Ee6';
    const sETH = '0x5e74C9036fb86BD7eCdcb084a0673EFc32eA31cb';

    ////////////////////
    const D3 = '0xBaaa1F5DbA42C3389bDbc2c9D2dE134F5cD0Dc89';
    ////////////////////
    const FRAX3CRV = '0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B';
    const crvSTETH = '0x06325440d014e39736583c165c2963ba99faf14e';
    const MIM3CRV = '0x5a6a4d54456819380173272a5e8e9b9904bdf41b';
    const UST3POOL = '0xCEAF7747579696A2F0bb206a14210e3c9e6fB269';
    const CRV3CRYPTO = '0xc4AD29ba4B3c580e6D59105FFf484999997675Ff';
    const fei3crv = '0x06cb22615BA53E60D67Bf6C341a0fD5E718E1655';
    const alUSD3crv = '0x43b4FdFD4Ff969587185cDB6f0BD875c5Fc83f8c';
    const crvcvxLP = '0x9D0464996170c6B9e75eED71c68B99dDEDf279e8';
    const cvxFXS = '0xFEEf77d3f69374f66429C91d732A244f074bdf74';
    const cvxFXSFXS = '0xF3A43307DcAFa93275993862Aae628fCB50dC768';
    const cvxrETH = '0x447Ddd4960d9fdBF6af9a790560d0AF76795CB08';
    const ETHMAXY = '0x0FE20E0Fa9C78278702B05c333Cc000034bb69E2';
    const VOLT = '0x559eBC30b0E58a45Cc9fF573f77EF1e5eb1b3E18';
    const FIAT = '0x586Aa273F262909EEF8fA02d90Ab65F5015e0516';
    const FIAT3CRV = '0xdb8cc7eced700a4bffde98013760ff31ff9408d8';
    const fdt = '0xed1480d12be41d92f36f5f7bdd88212e381a3677';

    /*

    const FixedUSDPriceOracle = await ethers.getContractFactory("FixedUSDPriceOracle");
    const fixedUSDPriceOracle = await FixedUSDPriceOracle.deploy();
    await fixedUSDPriceOracle.deployed();

    const RiseOracle = await ethers.getContractFactory("EthRisePriceOracle");
    const riseOracle = await RiseOracle.deploy();
    await riseOracle.deployed();

    const ChainlinkOracle = await ethers.getContractFactory("ChainlinkPriceOracleV2");
    const chainlinkOracle = await ChainlinkOracle.deploy(signer.address, true);
    await chainlinkOracle.deployed();
    */

    const CurveLpOracle = await ethers.getContractFactory("CurveLpTokenPriceOracle");
    const curveLpOracle = await CurveLpOracle.deploy();
    await curveLpOracle.deployed();
    await curveLpOracle.registerPool(a3CRV);
    await curveLpOracle.registerPool(crvSTETH);
    //await curveLpOracle.registerPool(crvcvxLP);

    const CvxFXSPriceOracle = await ethers.getContractFactory("CvxFXSPriceOracle");
    const cvxFXSPriceOracle = await CvxFXSPriceOracle.deploy();
    await cvxFXSPriceOracle.deployed();

    const CurveTriCryptoOracle = await ethers.getContractFactory("CurveTriCryptoLpTokenPriceOracle");
    const curveTriCryptoOracle = await CurveTriCryptoOracle.deploy();
    await curveTriCryptoOracle.deployed();


    const CurveFactoryOracle = await ethers.getContractFactory("CurveFactoryLpTokenPriceOracle");
    const curveFactoryOracle = await CurveFactoryOracle.deploy();
    await curveFactoryOracle.deployed();
    await curveFactoryOracle.registerPool(D3);
    await curveFactoryOracle.registerPool(FRAX3CRV);
    await curveFactoryOracle.registerPool(MIM3CRV);
    await curveFactoryOracle.registerPool(UST3POOL);
    await curveFactoryOracle.registerPool(fei3crv);
    await curveFactoryOracle.registerPool(alUSD3crv);
    await curveFactoryOracle.registerPool(crvcvxLP);
    await curveFactoryOracle.registerPool(cvxrETH);

    //console.log(await curveFactoryOracle.underlyingTokens);



    const ChainlinkOracle = await ethers.getContractFactory("ChainlinkPriceOracleV3");
    const chainlinkOracle = await ChainlinkOracle.deploy();
    await chainlinkOracle.deployed();

    const ChainlinkOracleV2 = await ethers.getContractFactory("ChainlinkPriceOracleV2");
    const chainlinkOracleV2 = await ChainlinkOracleV2.deploy(signer.address, true);
    await chainlinkOracleV2.deployed();
    await chainlinkOracleV2.setPriceFeeds([UST, cvxCRV], ["0x8b6d9085f310396C6E4f0012783E9f850eaa8a82", "0x8b6d9085f310396C6E4f0012783E9f850eaa8a82"], 1)


    /*
    const GOHMOracle = await ethers.getContractFactory("GOhmPriceOracleArbitrum");
    const gOHMOracle = await GOHMOracle.deploy();
    await gOHMOracle.deployed();

    await chainlinkOracle.setPriceFeeds([USDC, OHM], ["0x50834F3163758fcC1Df9973b6e91f0F0F0434aD3", "0x761aaeBf021F19F198D325D7979965D0c7C9e53b"], 1);

    const SushiTwapWeth = await ethers.getContractFactory("UniswapTwapPriceOracleV2");
    const sushiTwapWeth = await SushiTwapWeth.deploy();
    await sushiTwapWeth.deployed();
    // base oracle weth
    await sushiTwapWeth.initialize('0xb085A25B8Cb99e467cE51C2C0e54f2Cfc4f713a1', '0xc35dadb65012ec5796536bd9864ed8773abc74c4', '0x82af49447d8a07e3bd95bd0d56f35241523fbab1');

    const SushiTwapGohm = await ethers.getContractFactory("UniswapTwapPriceOracleV2");
    const sushiTwapGohm = await SushiTwapGohm.deploy();
    await sushiTwapGohm.deployed();
    // base oracle weth
    await sushiTwapGohm.initialize('0xb085A25B8Cb99e467cE51C2C0e54f2Cfc4f713a1', '0xc35dadb65012ec5796536bd9864ed8773abc74c4', GOHM);
    */

    const XVaultOracle = await ethers.getContractFactory("XVaultPriceOracle");
    const xVaultOracle = await XVaultOracle.deploy();
    await xVaultOracle.deployed();

    const RocketEthOracle = await ethers.getContractFactory("REthPriceOracle");
    const rEthOracle = await RocketEthOracle.deploy();
    await rEthOracle.deployed();

    const ETHMAXYPriceOracle = await ethers.getContractFactory("ETHMAXYPriceOracle");
    const empriceoracle = await ETHMAXYPriceOracle.deploy();
    await empriceoracle.deployed();

    const GALCXPriceOracle = await ethers.getContractFactory("GAlcxPriceOracle");
    const gAlcxPriceOracle = await GALCXPriceOracle.deploy();
    await gAlcxPriceOracle.deployed();

    const SaddlePriceOracle = await ethers.getContractFactory("SaddleLpTokenPriceOracle");
    const saddlePriceOracle = await SaddlePriceOracle.deploy();
    await saddlePriceOracle.deployed();
    await saddlePriceOracle.registerPool(alETHlp);

    const VoltOracle = await ethers.getContractFactory("VoltPriceOracle");
    const voltOracle = await VoltOracle.deploy();
    await voltOracle.deployed();

    const BalancerPairOracle = await ethers.getContractFactory("BalancerV2PairTwapPriceOracle");
    const balancerPairOracle = await BalancerPairOracle.deploy();
    await balancerPairOracle.deployed();

    console.log('before register');
    balancerPairOracle.registerPool(fdt, "0x2D344A84BaC123660b021EEbE4eB6F12ba25fe86");
    console.log('after register');

    const MasterPriceOracle = await ethers.getContractFactory("MasterPriceOracle");
    const masterPriceOracle = await MasterPriceOracle.deploy();
    await masterPriceOracle.deployed();

    const underlyings = [fdt, VOLT, WETH, sETH, alETH, alETHlp, alcxLP, ALCX, gALCX, ETHMAXY, cvxrETH, rETH, wstETH, xWIZARD, WIZARD, xPUNK, PUNK, cvxFXS, cvxFXSFXS, FXS, CRV, crvcvxLP, cvxCRV, alUSD3crv, UST, MIM, ETH, stETH, FEI, alUSD, FRAX, DAI, USDC, USDT, D3, FRAX3CRV, a3CRV, crvSTETH, MIM3CRV, UST3POOL, CRV3CRYPTO, fei3crv];
    const oracles = [balancerPairOracle.address, voltOracle.address, "0xffc9ec4adbf75a537e4d233720f06f0df01fb7f5", "0xffc9ec4adbf75a537e4d233720f06f0df01fb7f5", "0xffc9ec4adbf75a537e4d233720f06f0df01fb7f5", saddlePriceOracle.address, "0x50f42c004bd9b0e5acc65c33da133fbfbe86c7c0", chainlinkOracle.address, gAlcxPriceOracle.address, empriceoracle.address, curveFactoryOracle.address, rEthOracle.address, '0xb11De4c003C80dC36A810254b433D727Ac71c517', xVaultOracle.address, '0xf411CD7c9bC70D37f194828ce71be00d9aEC9edF', xVaultOracle.address, '0xf411CD7c9bC70D37f194828ce71be00d9aEC9edF', cvxFXSPriceOracle.address, cvxFXSPriceOracle.address, chainlinkOracle.address, chainlinkOracle.address, /*cvxFXSPriceOracle.address*/curveFactoryOracle.address, "0x552163F2A63F82BB47b686FFC665Ddb3ceACA0EA", curveFactoryOracle.address, chainlinkOracleV2.address, chainlinkOracle.address, chainlinkOracle.address, chainlinkOracle.address, chainlinkOracle.address, chainlinkOracle.address, chainlinkOracle.address, chainlinkOracle.address, chainlinkOracle.address, chainlinkOracle.address, curveFactoryOracle.address, curveFactoryOracle.address, curveLpOracle.address, curveLpOracle.address, curveFactoryOracle.address, curveFactoryOracle.address, curveTriCryptoOracle.address, curveFactoryOracle.address];
    await masterPriceOracle.initialize(underlyings, oracles, masterPriceOracle.address, signer.address, true);

    /*
    const underlyings = [USDC, OHM, ETHRISE, GOHM, JETH, JGOHM];
    const oracles = [chainlinkOracle.address, chainlinkOracle.address, riseOracle.address, gOHMOracle.address, sushiTwapWeth.address, sushiTwapGohm.address];
    await masterPriceOracle.initialize(underlyings, oracles, masterPriceOracle.address, signer.address, true);
    */

    console.log('volt price', (await masterPriceOracle.price(VOLT)).toString());
    console.log('fdt price', (await masterPriceOracle.price(fdt)).toString());


    console.log('sEth price', (await masterPriceOracle.price(sETH)).toString());
    console.log('alEth price', (await masterPriceOracle.price(alETH)).toString());
    console.log('alEth lp price', (await masterPriceOracle.price(alETHlp)).toString());

    console.log('alcx lp price', (await masterPriceOracle.price(alcxLP)).toString());

    console.log('ALCX price', (await masterPriceOracle.price(ALCX)).toString());
    console.log('gALCX price', (await masterPriceOracle.price(gALCX)).toString());

    console.log('crvSTETH price', (await masterPriceOracle.price(crvSTETH)).toString());

    console.log('ETHMAXY', (await masterPriceOracle.price(ETHMAXY)).toString());

    console.log('cvxreth', (await masterPriceOracle.price(cvxrETH)).toString());
    console.log('wstETH', (await masterPriceOracle.price(wstETH)).toString());
    console.log('rETH', (await masterPriceOracle.price(rETH)).toString());


    console.log('WIZARD', (await masterPriceOracle.price(WIZARD)).toString());
    console.log('xWIZARD', (await masterPriceOracle.price(xWIZARD)).toString());
    console.log('PUNK', (await masterPriceOracle.price(PUNK)).toString());
    console.log('xPUNK', (await masterPriceOracle.price(xPUNK)).toString());

    console.log('FXS', (await masterPriceOracle.price(FXS)).toString());
    console.log('cvxFXS', (await masterPriceOracle.price(cvxFXS)).toString());
    console.log('cvxFXSFXS', (await masterPriceOracle.price(cvxFXSFXS)).toString());

    console.log('crvcvxlp', (await masterPriceOracle.price(crvcvxLP)).toString());
    console.log('fei3crv', (await masterPriceOracle.price(fei3crv)).toString());
    console.log('alusd3crv', (await masterPriceOracle.price(alUSD3crv)).toString());
    console.log('UST', (await masterPriceOracle.price(UST)).toString());
    console.log('MIM', (await masterPriceOracle.price(MIM)).toString());
    console.log('ETH', (await masterPriceOracle.price(ETH)).toString());
    console.log('steth', (await masterPriceOracle.price(stETH)).toString());
    console.log('usdc price', (await masterPriceOracle.price(USDC)).toString());
    console.log('dai price', (await masterPriceOracle.price(DAI)).toString());
    console.log('frax price', (await masterPriceOracle.price(FRAX)).toString());
    console.log('usdt price', (await masterPriceOracle.price(USDT)).toString());
    console.log('D3 price', (await masterPriceOracle.price(D3)).toString());
    console.log('3CRV price', (await masterPriceOracle.price(a3CRV)).toString());

    console.log('FRAX3CRV price', (await masterPriceOracle.price(FRAX3CRV)).toString());
    console.log('crvSTETH price', (await masterPriceOracle.price(crvSTETH)).toString());
    console.log('MIM3CRV price', (await masterPriceOracle.price(MIM3CRV)).toString());
    console.log('UST3Pool price', (await masterPriceOracle.price(UST3POOL)).toString());
    console.log('CRV3Crypto price', (await masterPriceOracle.price(CRV3CRYPTO)).toString());



    //console.log('crvSTETH price', (await masterPriceOracle.price(crvSTETH)).toString());


    /*
    //console.log('rise price', (await riseOracle.price(ETHRISE)).toString());
    console.log('usdc price', (await masterPriceOracle.price(USDC)).toString());
    console.log('rise price', (await masterPriceOracle.price(ETHRISE)).toString());
    console.log('OHM price', (await masterPriceOracle.price(OHM)).toString());
    console.log('gOHM price', (await masterPriceOracle.price(GOHM)).toString());
    console.log('jeth', (await masterPriceOracle.price(JETH)).toString());
    console.log('jgohm', (await masterPriceOracle.price(JGOHM)).toString());
    */    

    
  });
});