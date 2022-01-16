// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "../../../external/chainlink/FlagsInterface.sol";

import "../../../oracles/ChainlinkPriceOracleV2.sol";

/**
 * @title ChainlinkPriceOracleV2Arbitrum
 * @notice Returns prices from Chainlink (checking Arbitrum Layer 2 Health Sequencer Flag).
 * @dev Implements `PriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract ChainlinkPriceOracleV2Arbitrum is ChainlinkPriceOracleV2 {
    /**
     * @dev Identifier of the Sequencer offline flag on the Flags contract.
     */
    address constant internal FLAG_ARBITRUM_SEQ_OFFLINE = address(bytes20(bytes32(uint256(keccak256("chainlink.flags.arbitrum-seq-offline")) - 1)));

    /**
     * @dev Chainlink Flags contract.
     */
    FlagsInterface constant public CHAINLINK_FLAGS = FlagsInterface(0x3C14e07Edd0dC67442FA96f1Ec6999c57E810a83);
    
    /**
     * @dev Constructor to set admin and canAdminOverwrite.
     */
    constructor (address _admin, bool _canAdminOverwrite) public ChainlinkPriceOracleV2(_admin, _canAdminOverwrite) { }

    /**
     * @dev Internal function returning the price in ETH of `underlying`.
     */
    function _price(address underlying) internal view override returns (uint) {
        bool isRaised = CHAINLINK_FLAGS.getFlag(FLAG_ARBITRUM_SEQ_OFFLINE);
        require(!isRaised, "Arbitrum Chainlink feeds are not being updated.");
        return super._price(underlying);
    }
}
