// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "../../FuseSafeLiquidator.sol";

/**
 * @title FuseSafeLiquidatorArbitrum
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FuseSafeLiquidatorArbitrum safely liquidates unhealthy borrowers (with flashloan support) on Arbitrum.
 * @dev Do not transfer ETH or tokens directly to this address. Only send ETH here when using a method, and only approve tokens for transfer to here when using a method. Direct ETH transfers will be rejected and direct token transfers will be lost.
 */
contract FuseSafeLiquidatorArbitrum is FuseSafeLiquidator {
    /**
     * @dev Constructor to set immutable variables.
     */
    constructor() public {
        WETH_ADDRESS = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        WETH = IWETH(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        UNISWAP_V2_ROUTER_02_ADDRESS = 0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506; // SushiSwap on Arbitrum
        UNISWAP_V2_ROUTER_02 = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
        WETH_FLASHLOAN_BASE_TOKEN_1 = 0xFEa7a6a0B346362BF88A9e4A88416B77a57D6c2A; // MIM on Arbitrum
        WETH_FLASHLOAN_BASE_TOKEN_2 = 0x6C2C06790b3E3E3c38e12Ee22F8183b37a13EE55; // DPX on Arbitrum
    }
}
