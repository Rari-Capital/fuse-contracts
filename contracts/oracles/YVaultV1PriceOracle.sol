pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/yearn/IVault.sol";

import "./BasePriceOracle.sol";

/**
 * @title YVaultV1PriceOracle
 * @notice Returns prices for yVaults using the sender as a root oracle.
 * @dev Implements the `PriceOracle` interface.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract YVaultV1PriceOracle is PriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Returns the price in ETH of the token underlying `cToken` (implements `PriceOracle`).
     */
    function getUnderlyingPrice(CToken cToken) external override view returns (uint) {
        // Get price of token underlying yVault
        IVault yVault = IVault(CErc20(address(cToken)).underlying());
        address underlyingToken = yVault.token();
        uint underlyingPrice = underlyingToken == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 ? 1e18 : BasePriceOracle(msg.sender).price(underlyingToken);

        // yVault/ETH = yVault/token * token/ETH
        return yVault.getPricePerFullShare().mul(underlyingPrice).div(10 ** uint256(yVault.decimals()));
    }
}
