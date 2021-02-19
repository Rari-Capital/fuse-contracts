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
    }

    /**
     * @notice The proportion of Fuse pool interest taken as a protocol fee (scaled by 1e18).
     */
    uint256 public interestFeeRate;

    /**
     * @dev Sets the proportion of Fuse pool interest taken as a protocol fee.
     * @param _interestFeeRate The proportion of Fuse pool interest taken as a protocol fee (scaled by 1e18).
     */
    function setInterestFeeRate(uint256 _interestFeeRate) external onlyOwner {
        require(_interestFeeRate <= 1e18, "Interest fee rate cannot be more than 100%.");
        interestFeeRate = _interestFeeRate;
    }

    /**
     * @dev Withdraws accrued fees on interest.
     * @param erc20Contract The ERC20 token address to withdraw. Set to the zero address to withdraw ETH.
     */
    function withdrawAssets(address erc20Contract) external {
        if (erc20Contract == address(0)) {
            uint256 balance = address(this).balance;
            require(balance > 0, "No balance available to withdraw.");
            (bool success, ) = owner().call.value(balance)("");
            require(success, "Failed to transfer ETH balance to msg.sender.");
        } else {
            IERC20Upgradeable token = IERC20Upgradeable(erc20Contract);
            uint256 balance = token.balanceOf(address(this));
            require(balance > 0, "No token balance available to withdraw.");
            token.safeTransfer(owner(), balance);
        }
    }

    /**
     * @dev Receives ETH fees.
     */
    receive() external payable { }
}