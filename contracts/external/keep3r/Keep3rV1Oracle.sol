// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface Keep3rV1Oracle {
    function current(address tokenIn, uint amountIn, address tokenOut) external view returns (uint amountOut);
}
