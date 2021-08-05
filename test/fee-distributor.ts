// SPDX-License-Identifier: UNLICENSED

import { ContractFactory } from "@ethersproject/contracts";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { expect } from "chai";
import { ethers } from "hardhat";


test('FuseFeeDistributor', () => {

  let feeDistributorFactory: ContractFactory;
  let IERC20UpgradeableFactory: ContractFactory;
  let signer: SignerWithAddress;
  before(async () => {
    [signer] = await ethers.getSigners();
    feeDistributorFactory = await ethers.getContractFactory("FuseFeeDistributor");
    IERC20UpgradeableFactory = await ethers.getContractFactory("IERC20Upgradeable");
  });


  it("should withdraw ETH sent to the contract", async () => {
    let feeDistributor = await feeDistributorFactory.deploy();
    const amt = ethers.utils.parseEther("0.1"); // 1E17
    await signer.sendTransaction({
      to: feeDistributor.address,
      value: amt,
    });
    var accountBalanceBeforeWithdrawal = await signer.getBalance();

    await feeDistributor._withdrawAssets("0x0000000000000000000000000000000000000000");
    var accountBalanceAfterWithdrawal = await signer.getBalance();
    expect(accountBalanceAfterWithdrawal).to.gte(accountBalanceBeforeWithdrawal.add(amt))
  });

  it("should withdraw ERC20 tokens sent to the contract", async () => {
    let feeDistributor = await feeDistributorFactory.deploy();
    let usdcInstance = await IERC20UpgradeableFactory.attach("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48");

    let amt = ethers.utils.parseUnits("0.1", 6); // 1e5
    await usdcInstance.transfer(feeDistributor.address, amt);
    var accountBalanceBeforeWithdrawal = await  usdcInstance.balanceOf(signer.address);
    await feeDistributor._withdrawAssets(usdcInstance.address);
    var accountBalanceAfterWithdrawal = await usdcInstance.balanceOf(signer.address);
    expect(accountBalanceAfterWithdrawal).to.gte(accountBalanceBeforeWithdrawal.add(accountBalanceBeforeWithdrawal));
  });
})