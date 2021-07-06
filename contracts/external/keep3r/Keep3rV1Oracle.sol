// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

abstract contract Keep3rV1Oracle {
    struct Observation {
        uint timestamp;
        uint price0Cumulative;
        uint price1Cumulative;
    }

    function factory() external pure virtual returns (address);
    mapping(address => Observation[]) public observations;
    function observationLength(address pair) external view virtual returns (uint);
}
