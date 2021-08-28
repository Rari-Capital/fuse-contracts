// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "../external/mstable/IMasset.sol";
import "../external/mstable/ISavingsContractV2.sol";

import "./BasePriceOracle.sol";

/**
 * @title MStablePriceOracle
 * @notice Returns prices for the mStable imUSD ERC20 token.
 * @dev Implements `PriceOracle`.
 * @author David Lucid <david@rari.capital>
 */
contract MStablePriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev mStable mUSD ERC20 token contract object.
     */
    IMasset constant public MUSD = IMasset(0xe2f2a5C287993345a840Db3B0845fbC70f5935a5);

    /**
     * @dev mStable imUSD ERC20 token contract object.
     */
    ISavingsContractV2 constant public IMUSD = ISavingsContractV2(0x30647a72Dc82d7Fbb1123EA74716aB8A317Eac19);

    /**
     * @dev mStable mBTC ERC20 token contract object.
     */
    IMasset constant public MBTC = IMasset(0x945Facb997494CC2570096c74b5F66A3507330a1);

    /**
     * @dev mStable imBTC ERC20 token contract object.
     */
    ISavingsContractV2 constant public IMBTC = ISavingsContractV2(0x17d8CBB6Bce8cEE970a4027d1198F6700A7a6c24);

    /**
     * @notice Fetches the token/ETH price, with 18 decimals of precision.
     * @param underlying The underlying token address for which to get the price.
     * @return Price denominated in ETH (scaled by 1e18)
     */
    function price(address underlying) external override view returns (uint) {
        return _price(underlying);
    }

    /**
     * @notice Returns the price in ETH of the token underlying `cToken`.
     * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
     * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
     */
    function getUnderlyingPrice(CToken cToken) external override view returns (uint) {
        address underlying = CErc20(address(cToken)).underlying();
        // Comptroller needs prices to be scaled by 1e(36 - decimals)
        // Since `_price` returns prices scaled by 18 decimals, we must scale them by 1e(36 - 18 - decimals)
        return _price(underlying).mul(1e18).div(10 ** uint256(ERC20Upgradeable(underlying).decimals()));
    }

    /**
     * @notice Fetches the token/ETH price, with 18 decimals of precision.
     */
    function _price(address underlying) internal view returns (uint) {
        if (underlying == address(MUSD))
            return getMAssetEthPrice(MUSD);
        else if (underlying == address(IMUSD))
            return IMUSD.exchangeRate().mul(getMAssetEthPrice(MUSD)).div(1e18);
        else if (underlying == address(MBTC))
            return getMAssetEthPrice(MBTC);
        else if (underlying == address(IMBTC))
            return IMBTC.exchangeRate().mul(getMAssetEthPrice(MBTC)).div(1e18);
        else revert("Invalid token passed to MStablePriceOracle.");
    }

    /**
     * @dev Returns the price in ETH of the mAsset using `msg.sender` as a root price oracle for underlying bAssets.
     */
    function getMAssetEthPrice(IMasset mAsset) internal view returns (uint256) {
        (IMasset.BassetPersonal[] memory bAssetPersonal, IMasset.BassetData[] memory bAssetData) = mAsset.getBassets();
        uint256 underlyingValueInEthScaled = 0;
        for (uint256 i = 0; i < bAssetData.length; i++) underlyingValueInEthScaled = underlyingValueInEthScaled.add(uint256(bAssetData[i].vaultBalance).mul(uint256(bAssetData[i].ratio)).div(1e8).mul(BasePriceOracle(msg.sender).price(bAssetPersonal[i].addr)));
        return underlyingValueInEthScaled.div(ERC20Upgradeable(address(mAsset)).totalSupply());
    }
}
