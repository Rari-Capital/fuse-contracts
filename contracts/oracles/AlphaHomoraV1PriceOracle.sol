pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "../external/alpha/Bank.sol";

/**
 * @title AlphaHomoraV1PriceOracle
 * @notice Returns prices the Alpha Homora V1 ibETH ERC20 token.
 * @dev Implements the `PriceOracle` interface.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract AlphaHomoraV1PriceOracle is PriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Alpha Homora ibETH token contract object.
     */
    Bank constant public IBETH = Bank(0x67B66C99D3Eb37Fa76Aa3Ed1ff33E8e39F0b9c7A);

    /**
     * @notice Returns the price in ETH of the token underlying `cToken`.
     * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
     * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
     */
    function getUnderlyingPrice(CToken cToken) external override view returns (uint) {
        require(CErc20(address(cToken)).underlying() == address(IBETH));
        return IBETH.totalETH().mul(1e18).div(IBETH.totalSupply());
    }
}
