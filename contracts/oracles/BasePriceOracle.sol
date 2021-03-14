/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * No one is permitted to use the software for any purpose without the explicit permission of David Lucid of Rari Capital, Inc.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

pragma solidity 0.6.12;

import "../external/compound/PriceOracle.sol";

/**
 * @title BasePriceOracle
 * @notice Returns prices of underlying tokens directly without the caller having to specify a cToken address.
 * @dev Implements the `PriceOracle` interface.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
interface BasePriceOracle is PriceOracle {
    /**
     * @notice Get the price of an underlying asset.
     * @param underlying The underlying asset to get the price of.
     * @return The underlying asset price in ETH as a mantissa (scaled by 1e18).
     * Zero means the price is unavailable.
     */
    function price(address underlying) external view returns (uint);
}
