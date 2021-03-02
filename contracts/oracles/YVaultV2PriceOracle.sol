pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CErc20.sol";

import "../external/yearn/IVaultV2.sol";

import "./BasePriceOracle.sol";

/**
 * @title YVaultV2PriceOracle
 * @notice Returns prices for yVaults using the sender as a root oracle.
 * @dev Implements the `PriceOracle` interface.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract YVaultV2PriceOracle is PriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Returns the price in ETH of the token underlying `cToken` (implements `PriceOracle`).
     */
    function getUnderlyingPrice(CToken cToken) external override view returns (uint256) {
        // Get price of token underlying yVault
        IVaultV2 yVault = IVaultV2(CErc20(address(cToken)).underlying());
        address underlyingToken = yVault.token();
        uint underlyingPrice = underlyingToken == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 ? 1e18 : BasePriceOracle(msg.sender).price(underlyingToken);

        // yVault/ETH = yVault/token * token/ETH
        // Return value = yVault/ETH scaled by 1e(36 - yVault decimals)
        // `pricePerShare` = yVault/token scaled by 1e(yVault decimals)
        // `underlyingPrice` = token/ETH scaled by 1e18
        // Return value = `pricePerShare` * `underlyingPrice` * 1e(18 - (yVault decimals * 2))
        uint256 baseUnit = 10 ** uint256(yVault.decimals());
        return yVault.pricePerShare().mul(underlyingPrice).div(baseUnit).mul(1e18).div(baseUnit);
    }
}
