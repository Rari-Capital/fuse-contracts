// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

interface IGnosis {
    function isOwner(address owner) external view returns (bool);
}
