/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * No one is permitted to use the software for any purpose without the explicit permission of David Lucid of Rari Capital, Inc.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

/**
 * @title FuseFeeDistributor
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FuseFeeDistributor controls and receives protocol fees from Fuse pools.
 */
contract FuseFeeDistributor is Initializable, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev Initializer that sets the proportion of Fuse pool interest taken as a protocol fee.
     * @param _interestFeeRate The proportion of Fuse pool interest taken as a protocol fee (scaled by 1e18).
     */
    function initialize(uint256 _interestFeeRate) public initializer {
        require(_interestFeeRate <= 1e18, "Interest fee rate cannot be more than 100%.");
        __Ownable_init();
        interestFeeRate = _interestFeeRate;
        maxSupplyEth = uint256(-1);
        maxUtilizationRate = uint256(-1);
    }

    /**
     * @notice The proportion of Fuse pool interest taken as a protocol fee (scaled by 1e18).
     */
    uint256 public interestFeeRate;

    /**
     * @dev Sets the proportion of Fuse pool interest taken as a protocol fee.
     * @param _interestFeeRate The proportion of Fuse pool interest taken as a protocol fee (scaled by 1e18).
     */
    function _setInterestFeeRate(uint256 _interestFeeRate) external onlyOwner {
        require(_interestFeeRate <= 1e18, "Interest fee rate cannot be more than 100%.");
        interestFeeRate = _interestFeeRate;
    }

    /**
     * @dev Withdraws accrued fees on interest.
     * @param erc20Contract The ERC20 token address to withdraw. Set to the zero address to withdraw ETH.
     */
    function _withdrawAssets(address erc20Contract) external {
        if (erc20Contract == address(0)) {
            uint256 balance = address(this).balance;
            require(balance > 0, "No balance available to withdraw.");
            (bool success, ) = owner().call{value: balance}("");
            require(success, "Failed to transfer ETH balance to msg.sender.");
        } else {
            IERC20Upgradeable token = IERC20Upgradeable(erc20Contract);
            uint256 balance = token.balanceOf(address(this));
            require(balance > 0, "No token balance available to withdraw.");
            token.safeTransfer(owner(), balance);
        }
    }

    /**
     * @dev Minimum borrow balance (in ETH) per user per Fuse pool asset (only checked on new borrows, not redemptions).
     */
    uint256 public minBorrowEth;

    /**
     * @dev Maximum supply balance (in ETH) per user per Fuse pool asset.
     */
    uint256 public maxSupplyEth;

    /**
     * @dev Maximum utilization rate (scaled by 1e18) for Fuse pool assets (only checked on new borrows, not redemptions).
     */
    uint256 public maxUtilizationRate;

    /**
     * @dev Sets the proportion of Fuse pool interest taken as a protocol fee.
     * @param _minBorrowEth Minimum borrow balance (in ETH) per user per Fuse pool asset (only checked on new borrows, not redemptions).
     * @param _maxSupplyEth Maximum supply balance (in ETH) per user per Fuse pool asset.
     * @param _maxUtilizationRate Maximum utilization rate (scaled by 1e18) for Fuse pool assets (only checked on new borrows, not redemptions).
     */
    function _setPoolLimits(uint256 _minBorrowEth, uint256 _maxSupplyEth, uint256 _maxUtilizationRate) external onlyOwner {
        minBorrowEth = _minBorrowEth;
        maxSupplyEth = _maxSupplyEth;
        maxUtilizationRate = _maxUtilizationRate;
    }

    /**
     * @dev Receives ETH fees.
     */
    receive() external payable { }

    /**
     * @dev Sends data to a contract.
     * @param targets The contracts to which `data` will be sent.
     * @param data The data to be sent to each of `targets`.
     */
    function _callPool(address[] calldata targets, bytes[] calldata data) external onlyOwner {
        require(targets.length > 0 && targets.length == data.length, "Array lengths must be equal and greater than 0.");
        for (uint256 i = 0; i < targets.length; i++) targets[i].call(data[i]);
    }

    /**
     * @dev Sends data to a contract.
     * @param targets The contracts to which `data` will be sent.
     * @param data The data to be sent to each of `targets`.
     */
    function _callPool(address[] calldata targets, bytes calldata data) external onlyOwner {
        require(targets.length > 0, "No target addresses specified.");
        for (uint256 i = 0; i < targets.length; i++) targets[i].call(data);
    }
}
