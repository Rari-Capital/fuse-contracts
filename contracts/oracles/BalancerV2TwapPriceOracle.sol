// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/balancer/IBalancerPriceOracle.sol";
import "../external/balancer/IBalancerV2Vault.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "./BasePriceOracle.sol";

/**
 * @title BalancerV2TwapPriceOracle
 * @notice Stores cumulative prices and returns TWAPs for BalancerV2 assets.
 * @author sri yantra @RariCapital
 */
contract BalancerV2TwapPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev WETH token contract address.
     */
    address constant public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @dev BalancerV2 Vault contract address
     */
    IBalancerV2Vault constant balancerV2Vault = IBalancerV2Vault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);

    /**
     * @dev Ideal TWAP interval in seconds (10 minutes).
     */
    uint256 public constant TWAP_PERIOD = 600;

    /**
     * @dev Returns the price in ETH of `underlying` with 18 decimals of precision.
     */
    function _price(address underlying) internal view returns (uint) {
        IBalancerPriceOracle pool = IBalancerPriceOracle(underlying);

        require(TWAP_PERIOD < pool.getLargestSafeQueryWindow(), 'TWAP period must be less than largest safe query window');

        IBalancerPriceOracle.OracleAverageQuery[] memory queries = new IBalancerPriceOracle.OracleAverageQuery[](1);

        queries[0] = IBalancerPriceOracle.OracleAverageQuery({
            variable: IBalancerPriceOracle.Variable.BPT_PRICE, 
            secs: TWAP_PERIOD,
            ago: 0
        });

        uint256[] memory results = pool.getTimeWeightedAverage(
            queries
        );

        (address[] memory poolTokens, ,) = balancerV2Vault.getPoolTokens(IBalancerPriceOracle(pool).getPoolId());
        return poolTokens[0] == address(WETH) ? results[0] : results[0].mul(BasePriceOracle(msg.sender).price(poolTokens[0])).div(1e18);
    }

    /**
     * @notice Returns the price in ETH of the token underlying `cToken`.
     * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
     * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
     */
    function getUnderlyingPrice(CToken cToken) external override view returns (uint) {
        // Get underlying ERC20 token address
        address underlying = CErc20(address(cToken)).underlying();

        // Get price and return
        return _price(underlying);
    }

    /**
     * @dev Returns the price in ETH of `underlying` (implements `BasePriceOracle`).
     */
    function price(address underlying) external override view returns (uint) {
        return _price(underlying);
    }
}
