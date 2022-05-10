// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IERC20ExtendedUpgradeable is IERC20Upgradeable {
    function decimals() external view returns(uint8);
    function symbol() external view returns(string memory);
    function name() external view returns(string memory);
}

interface IOneTokenV1Base is IERC20ExtendedUpgradeable {
    function init(string memory name_, string memory symbol_, address oneTokenOracle_, address controller_,  address mintMaster_, address memberToken_, address collateral_) external;
    function changeController(address controller_) external;
    function changeMintMaster(address mintMaster_, address oneTokenOracle) external;
    function addAsset(address token, address oracle) external;
    function removeAsset(address token) external;
    function setStrategy(address token, address strategy, uint256 allowance) external;
    function executeStrategy(address token) external;
    function removeStrategy(address token) external;
    function closeStrategy(address token) external;
    function increaseStrategyAllowance(address token, uint256 amount) external;
    function decreaseStrategyAllowance(address token, uint256 amount) external;
    function setFactory(address newFactory) external;

    function MODULE_TYPE() external view returns(bytes32);
    function oneTokenFactory() external view returns(address);
    function controller() external view returns(address);
    function mintMaster() external view returns(address);
    function memberToken() external view returns(address);
    function assets(address) external view returns(address, address);
    function balances(address token) external view returns(uint256 inVault, uint256 inStrategy);
    function collateralTokenCount() external view returns(uint256);
    function collateralTokenAtIndex(uint256 index) external view returns(address);
    function isCollateral(address token) external view returns(bool);
    function otherTokenCount() external view  returns(uint256);
    function otherTokenAtIndex(uint256 index) external view returns(address); 
    function isOtherToken(address token) external view returns(bool);
    function assetCount() external view returns(uint256);
    function assetAtIndex(uint256 index) external view returns(address); 
    function isAsset(address token) external view returns(bool);
}

interface IOneTokenV1 is IOneTokenV1Base {
    function mintingFee() external view returns(uint);
    function redemptionFee() external view returns(uint);
    function mint(address collateral, uint oneTokens) external;
    function redeem(address collateral, uint amount) external;
    function setMintingFee(uint fee) external;
    function setRedemptionFee(uint fee) external;
    function updateMintingRatio(address collateralToken) external returns(uint ratio, uint maxOrderVolume);
    function getMintingRatio(address collateralToken) external view returns(uint ratio, uint maxOrderVolume);
    function getHoldings(address token) external view returns(uint vaultBalance, uint strategyBalance);
}