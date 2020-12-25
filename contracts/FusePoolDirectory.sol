/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * Anyone is free to integrate the public (i.e., non-administrative) application programming interfaces (APIs) of the official Ethereum smart contract instances deployed by Rari Capital, Inc. in any application (commercial or noncommercial and under any license), provided that the application does not abuse the APIs or act against the interests of Rari Capital, Inc.
 * Anyone is free to study, review, and analyze the source code contained in this package.
 * Reuse (including deployment of smart contracts other than private testing on a private network), modification, redistribution, or sublicensing of any source code contained in this package is not permitted without the explicit permission of David Lucid of Rari Capital, Inc.
 * No one is permitted to use the software for any purpose other than those allowed by this license.
 * This license is liable to change at any time at the sole discretion of David Lucid of Rari Capital, Inc.
 */

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./compound/Comptroller.sol";
import "./compound/CToken.sol";
import "./compound/CErc20.sol";

/**
 * @title FusePoolDirectory
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FusePoolDirectory is a directory for Fuse money market pools.
 */
contract FusePoolDirectory {
    using SafeMathUpgradeable for uint256;

    /**
     * @dev Struct for a Fuse money market pool.
     */
    struct FusePool {
        string name;
        address creator;
        address comptroller;
        bool isPrivate;
        uint256 blockPosted;
        uint256 timestampPosted;
    }

    /**
     * @dev Array of Fuse money market pools.
     */
    FusePool[] public pools;

    /**
     * @dev Maps Ethereum accounts to arrays of Fuse pool indexes.
     */
    mapping(address => uint256[]) private _poolsByAccount;

    /**
     * @dev Maps Fuse pool Comptroller addresses to bools indicating if they have been posted to the directory.
     */
    mapping(address => bool) public poolExists;

    /**
     * @dev Emitted when a new Fuse pool is added to the directory.
     */
    event PoolRegistered(uint256 index, FusePool pool);

    /**
     * @dev Adds a new Fuse pool to the directory.
     * @param name The name of the pool.
     * @param comptroller The pool's Comptroller contract address.
     * @param isPrivate Boolean indicating if the pool is private.
     * @return The index of the registered Fuse pool.
     */
    function registerPool(string memory name, address comptroller, bool isPrivate) external returns (uint256) {
        require(!poolExists[comptroller], "Pool already exists in the directory.");
        require(msg.sender == Comptroller(comptroller).admin(), "Pool admin is not the sender.");
        FusePool memory pool = FusePool(name, msg.sender, comptroller, isPrivate, block.number, block.timestamp);
        pools.push(pool);
        _poolsByAccount[msg.sender].push(pools.length - 1);
        poolExists[comptroller] = true;
        emit PoolRegistered(pools.length - 1, pool);
    }

    /**
     * @dev Array of Fuse money market pools.
     */
    address[][] public assets;

    /**
     * @dev Maps Fuse pool indexes to asset addresses to bools indicating if they have been posted to the directory.
     */
    mapping(address => bool)[] public assetExists;

    /**
     * @dev Emitted when a new asset is added to a Fuse pool in the directory.
     */
    event AssetRegistered(uint256 index, address cToken);

    /**
     * @dev Adds a new asset to a Fuse pool.
     * @param pool The index of the Fuse pool.
     * @param cToken The pool's Comptroller contract address.
     * @return The index of the registered asset in the Fuse pool.
     */
    function registerAsset(uint256 pool, address cToken) external returns (uint256) {
        require(!assetExists[pool][cToken], "Pool already exists in the directory.");
        require(msg.sender == Comptroller(pools[pool].comptroller).admin(), "Pool admin is not the sender.");
        assets[pool].push(cToken);
        assetExists[pool][cToken] = true;
        emit AssetRegistered(assets[pool].length - 1, cToken);
    }

    /**
     * @notice Returns arrays of all public Fuse pool indexes and data.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     */
    function getPublicPools() external view returns (uint256[] memory, FusePool[] memory) {
        uint256 arrayLength = 0;
        for (uint256 i = 0; i < pools.length; i++) if (!pools[i].isPrivate) arrayLength++;
        uint256[] memory indexes = new uint256[](arrayLength);
        FusePool[] memory publicPools = new FusePool[](arrayLength);
        uint256 index = 0;

        for (uint256 i = 0; i < pools.length; i++) if (!pools[i].isPrivate) {
            indexes[index] = i;
            publicPools[index] = pools[i];
            index++;
        }

        return (indexes, publicPools);
    }

    /**
     * @notice Returns an array of Fuse pools created by `account`.
     */
    function getPoolsByAccount(address account) external view returns (FusePool[] memory) {
        FusePool[] memory accountPools = new FusePool[](_poolsByAccount[account].length);
        for (uint256 i = 0; i < _poolsByAccount[account].length; i++) accountPools[i] = pools[_poolsByAccount[account][i]];
        return accountPools;
    }

    /**
     * @dev Struct for a Fuse money market pool asset.
     */
    struct FuseAsset {
        address cToken;
        address underlyingToken;
        string underlyingName;
        string underlyingSymbol;
        uint256 underlyingDecimal;
        uint256 underlyingBalance;
        uint256 supplyRatesPerBlock;
        uint256 borrowRatesPerBlock;
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 supplyBalance;
        uint256 borrowBalance;
        uint256 liquidity;
        bool membership;
    }

    /**
     * @notice Returns the assets of the specified Fuse pool.
     * @dev Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     * @param pool The index of the Fuse pool.
     * @return An array of cToken addresses, underlying names, underlying symbols, underlying decimals, and APRs (scaled by 1e18)
     */
    function getPoolAssetsWithData(uint256 pool) external returns (uint256[] memory, FuseAsset[] memory) {
        Comptroller comptroller = Comptroller(pools[pool].comptroller);

        uint256[] memory indexes = new uint256[](assets[pool].length);
        FuseAsset[] memory detailedAssets = new FuseAsset[](assets[pool].length);

        for (uint256 i = 0; i < assets[pool].length; i++) {
            FuseAsset memory asset;
            CToken cToken = CToken(assets[pool][i]);

            if (cToken.isCEther()) {
                asset.underlyingName = "Ethereum";
                asset.underlyingSymbol = "ETH";
                asset.underlyingDecimal = 18;
                asset.underlyingBalance = msg.sender.balance;
            } else {
                asset.underlyingToken = CErc20(assets[pool][i]).underlying();
                ERC20Upgradeable underlying = ERC20Upgradeable(asset.underlyingToken);
                asset.underlyingName = underlying.name();
                asset.underlyingSymbol = underlying.symbol();
                asset.underlyingDecimal = underlying.decimals();
                asset.underlyingBalance = underlying.balanceOf(msg.sender);
            }

            asset.supplyRatesPerBlock = cToken.supplyRatePerBlock();
            asset.borrowRatesPerBlock = cToken.borrowRatePerBlock();
            asset.liquidity = cToken.getCash();
            asset.totalBorrow = cToken.totalBorrowsCurrent();
            asset.totalSupply = asset.liquidity.add(asset.totalBorrow).sub(cToken.totalReserves());
            asset.supplyBalance = cToken.balanceOfUnderlying(msg.sender);
            asset.borrowBalance = cToken.borrowBalanceCurrent(msg.sender);
            asset.membership = comptroller.checkMembership(msg.sender, cToken);
        }

        return (indexes, detailedAssets);
    }
}
