/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * No one is permitted to use the software for any purpose without the explicit permission of David Lucid of Rari Capital, Inc.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

const FuseFeeDistributor = artifacts.require("FuseFeeDistributor");
const IERC20Upgradeable = artifacts.require("IERC20Upgradeable");

contract("FuseFeeDistributor", accounts => {
  it("should withdraw ETH sent to the contract", async () => {
    let feeDistributorInstance = await FuseFeeDistributor.deployed();
    var amount = web3.utils.toBN(1e16);
    await web3.eth.sendTransaction({ from: process.env.DEVELOPMENT_ADDRESS, to: FuseFeeDistributor.address, value: amount, gasPrice: 0 });
    var accountBalanceBeforeWithdrawal = web3.utils.toBN(await web3.eth.getBalance(process.env.DEVELOPMENT_ADDRESS));
    await feeDistributorInstance._withdrawAssets("0x0000000000000000000000000000000000000000", { from: process.env.DEVELOPMENT_ADDRESS, gasPrice: 0 });
    var accountBalanceAfterWithdrawal = web3.utils.toBN(await web3.eth.getBalance(process.env.DEVELOPMENT_ADDRESS));
    assert(accountBalanceAfterWithdrawal.gte(accountBalanceBeforeWithdrawal.add(amount)));
  });

  it("should withdraw ERC20 tokens sent to the contract", async () => {
    let feeDistributorInstance = await FuseFeeDistributor.deployed();
    var usdcInstance = await IERC20Upgradeable.at("0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48");
    var amount = web3.utils.toBN(1e5);
    await usdcInstance.transfer(FuseFeeDistributor.address, amount, { from: process.env.DEVELOPMENT_ADDRESS });
    var accountBalanceBeforeWithdrawal = await usdcInstance.balanceOf.call(process.env.DEVELOPMENT_ADDRESS);
    await feeDistributorInstance._withdrawAssets(usdcInstance.address, { from: process.env.DEVELOPMENT_ADDRESS });
    var accountBalanceAfterWithdrawal = await usdcInstance.balanceOf.call(process.env.DEVELOPMENT_ADDRESS);
    assert(accountBalanceAfterWithdrawal.gte(accountBalanceBeforeWithdrawal.add(amount)));
  });
});
