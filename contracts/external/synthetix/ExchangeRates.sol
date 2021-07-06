// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface ExchangeRates {
    function effectiveValue(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey
    ) external view returns (uint value);
}
