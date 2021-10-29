// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.6.12;

interface Stabilizer {
    function buyFee() external view returns (uint256);
    function synth() external view returns (address);
    function reserve() external view returns (address);
    function buy(uint amount) external;
    function sell(uint amount) external;
}
