// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface ISynth {
    function currencyKey() external view returns (bytes32);
}
