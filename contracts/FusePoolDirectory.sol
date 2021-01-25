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

import "./external/compound/Comptroller.sol";
import "./external/compound/Unitroller.sol";
import "./external/compound/PriceOracle.sol";
import "./external/compound/CToken.sol";
import "./external/compound/CErc20.sol";

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
     * @param comptroller The pool's Comptroller proxy contract address.
     * @param isPrivate Boolean indicating if the pool is private.
     * @return The index of the registered Fuse pool.
     */
    function registerPool(string memory name, address comptroller, bool isPrivate) external returns (uint256) {
        require(msg.sender == Comptroller(comptroller).admin(), "Pool admin is not the sender.");
        return _registerPool(name, comptroller, isPrivate);
    }

    /**
     * @dev Adds a new Fuse pool to the directory (without checking msg.sender).
     * @param name The name of the pool.
     * @param comptroller The pool's Comptroller proxy contract address.
     * @param isPrivate Boolean indicating if the pool is private.
     * @return The index of the registered Fuse pool.
     */
    function _registerPool(string memory name, address comptroller, bool isPrivate) internal returns (uint256) {
        require(!poolExists[comptroller], "Pool already exists in the directory.");
        FusePool memory pool = FusePool(name, msg.sender, comptroller, isPrivate, block.number, block.timestamp);
        pools.push(pool);
        _poolsByAccount[msg.sender].push(pools.length - 1);
        poolExists[comptroller] = true;
        emit PoolRegistered(pools.length - 1, pool);
    }

    /**
     * @dev Deploys a new Fuse pool and adds to the directory.
     * @param name The name of the pool.
     * @param implementation The Comptroller implementation contract address.
     * @param isPrivate Boolean indicating if the pool is private.
     * @param closeFactor The pool's close factor (scaled by 1e18).
     * @param maxAssets Maximum number of assets in the pool.
     * @param liquidationIncentive The pool's liquidation incentive (scaled by 1e18).
     * @param priceOracle The pool's PriceOracle contract address.
     * @return The index of the registered Fuse pool and the Unitroller proxy address.
     */
    function deployPool(string memory name, address implementation, bool isPrivate, uint256 closeFactor, uint256 maxAssets, uint256 liquidationIncentive, address priceOracle) external returns (uint256, address) {
        bytes memory unitrollerCreationCode = hex"608060405234801561001057600080fd5b50600080546001600160a01b031916331790556105e4806100326000396000f3fe60806040526004361061007b5760003560e01c8063dcfbc0c71161004e578063dcfbc0c71461019e578063e992a041146101b3578063e9c714f2146101e6578063f851a440146101fb5761007b565b806326782247146100fe578063b71d1a0c1461012f578063bb82aa5e14610174578063c1e8033414610189575b6002546040516000916001600160a01b031690829036908083838082843760405192019450600093509091505080830381855af49150503d80600081146100de576040519150601f19603f3d011682016040523d82523d6000602084013e6100e3565b606091505b505090506040513d6000823e8180156100fa573d82f35b3d82fd5b34801561010a57600080fd5b50610113610210565b604080516001600160a01b039092168252519081900360200190f35b34801561013b57600080fd5b506101626004803603602081101561015257600080fd5b50356001600160a01b031661021f565b60408051918252519081900360200190f35b34801561018057600080fd5b506101136102b0565b34801561019557600080fd5b506101626102bf565b3480156101aa57600080fd5b506101136103ba565b3480156101bf57600080fd5b50610162600480360360208110156101d657600080fd5b50356001600160a01b03166103c9565b3480156101f257600080fd5b5061016261044d565b34801561020757600080fd5b50610113610533565b6001546001600160a01b031681565b600080546001600160a01b031633146102455761023e6001600e610542565b90506102ab565b600180546001600160a01b038481166001600160a01b0319831681179093556040805191909216808252602082019390935281517fca4f2f25d0898edd99413412fb94012f9e54ec8142f9b093e7720646a95b16a9929181900390910190a160005b9150505b919050565b6002546001600160a01b031681565b6003546000906001600160a01b0316331415806102e557506003546001600160a01b0316155b156102fc576102f5600180610542565b90506103b7565b60028054600380546001600160a01b038082166001600160a01b031980861682179687905590921690925560408051938316808552949092166020840152815190927fd604de94d45953f9138079ec1b82d533cb2160c906d1076d1f7ed54befbca97a92908290030190a1600354604080516001600160a01b038085168252909216602083015280517fe945ccee5d701fc83f9b8aa8ca94ea4219ec1fcbd4f4cab4f0ea57c5c3e1d8159281900390910190a160005b925050505b90565b6003546001600160a01b031681565b600080546001600160a01b031633146103e85761023e6001600f610542565b600380546001600160a01b038481166001600160a01b0319831617928390556040805192821680845293909116602083015280517fe945ccee5d701fc83f9b8aa8ca94ea4219ec1fcbd4f4cab4f0ea57c5c3e1d8159281900390910190a160006102a7565b6001546000906001600160a01b031633141580610468575033155b15610479576102f560016000610542565b60008054600180546001600160a01b038082166001600160a01b031980861682179687905590921690925560408051938316808552949092166020840152815190927ff9ffabca9c8276e99321725bcb43fb076a6c66a54b7f21c4e8146d8519b417dc92908290030190a1600154604080516001600160a01b038085168252909216602083015280517fca4f2f25d0898edd99413412fb94012f9e54ec8142f9b093e7720646a95b16a99281900390910190a160006103b2565b6000546001600160a01b031681565b60007f45b96fe442630264581b197e84bbada861235052c5a1aadfff9ea4e40a969aa083601181111561057157fe5b83601381111561057d57fe5b604080519283526020830191909152600082820152519081900360600190a18260118111156105a857fe5b939250505056fea265627a7a7231582086afd96b7d6afd4c8d4cd4aba0835a0f03aadf3e5b7fad67357442286d69370964736f6c63430005110032";
        bytes32 salt = keccak256(abi.encodePacked(name));
        address proxy;

        assembly {
            proxy := create2(0, add(unitrollerCreationCode, 32), mload(unitrollerCreationCode), salt)
        }

        Unitroller unitroller = Unitroller(proxy);
        unitroller._setPendingImplementation(implementation);
        Comptroller comptrollerImplementation = Comptroller(implementation);
        comptrollerImplementation._become(unitroller);
        Comptroller comptrollerProxy = Comptroller(proxy);
        comptrollerProxy._setCloseFactor(closeFactor);
        comptrollerProxy._setMaxAssets(maxAssets);
        comptrollerProxy._setLiquidationIncentive(liquidationIncentive);
        comptrollerProxy._setPriceOracle(PriceOracle(priceOracle));
        unitroller._setPendingAdmin(msg.sender);
        return (_registerPool(name, proxy, isPrivate), proxy);
    }

    /**
     * @notice Returns arrays of all public Fuse pool indexes and data.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     */
    function getPublicPools() public view returns (uint256[] memory, FusePool[] memory) {
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
     * @notice Returns arrays of all public Fuse pool indexes, data, total supply balances (in ETH), and total borrow balances (in ETH).
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPublicPoolsWithData() external returns (uint256[] memory, FusePool[] memory, uint256[] memory, uint256[] memory) {
        (uint256[] memory indexes, FusePool[] memory publicPools) = getPublicPools();
        uint256[] memory totalSupply = new uint256[](publicPools.length);
        uint256[] memory totalBorrow = new uint256[](publicPools.length);
        for (uint256 i = 0; i < publicPools.length; i++) (totalSupply[i], totalBorrow[i]) = getPoolStats(Comptroller(publicPools[i].comptroller));
        return (indexes, publicPools, totalSupply, totalBorrow);
    }


    /**
     * @notice Returns arrays of Fuse pool indexes and data created by `account`.
     */
    function getPoolsByAccount(address account) public view returns (uint256[] memory, FusePool[] memory) {
        uint256[] memory indexes = new uint256[](_poolsByAccount[account].length);
        FusePool[] memory accountPools = new FusePool[](_poolsByAccount[account].length);

        for (uint256 i = 0; i < _poolsByAccount[account].length; i++) {
            indexes[i] = _poolsByAccount[account][i];
            accountPools[i] = pools[_poolsByAccount[account][i]];
        }

        return (indexes, accountPools);
    }

    /**
     * @notice Returns arrays of the indexes of Fuse pools created by `account`, data, total supply balances (in ETH), and total borrow balances (in ETH).
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPoolsByAccountWithData(address account) external returns (uint256[] memory, FusePool[] memory, uint256[] memory, uint256[] memory) {
        (uint256[] memory indexes, FusePool[] memory accountPools) = getPoolsByAccount(account);
        uint256[] memory totalSupply = new uint256[](accountPools.length);
        uint256[] memory totalBorrow = new uint256[](accountPools.length);
        for (uint256 i = 0; i < accountPools.length; i++) (totalSupply[i], totalBorrow[i]) = getPoolStats(Comptroller(accountPools[i].comptroller));
        return (indexes, accountPools, totalSupply, totalBorrow);
    }

    /**
     * @notice Returns total supply balance (in ETH) and total borrow balance (in ETH) of a Fuse pool.
     */
    function getPoolStats(Comptroller comptroller) internal returns (uint256, uint256) {
        uint256 totalBorrow = 0;
        uint256 totalSupply = 0;
        CToken[] memory cTokens = comptroller.getAllMarkets();
        PriceOracle oracle = comptroller.oracle();

        for (uint256 i = 0; i < cTokens.length; i++) {
            CToken cToken = cTokens[i];
            (bool isListed, ) = comptroller.markets(address(cToken));
            if (!isListed) continue;
            uint256 assetTotalBorrow = cToken.totalBorrowsCurrent();
            uint256 assetTotalSupply = cToken.getCash().add(assetTotalBorrow).sub(cToken.totalReserves());
            uint256 underlyingPrice = oracle.getUnderlyingPrice(cToken);
            totalBorrow = totalBorrow.add(assetTotalBorrow.mul(underlyingPrice).div(1e18));
            totalSupply = totalSupply.add(assetTotalSupply.mul(underlyingPrice).div(1e18));
        }

        return (totalSupply, totalBorrow);
    }

    /**
     * @dev Struct for a Fuse money market pool asset.
     */
    struct FusePoolAsset {
        address cToken;
        address underlyingToken;
        string underlyingName;
        string underlyingSymbol;
        uint256 underlyingDecimals;
        uint256 underlyingBalance;
        uint256 supplyRatePerBlock;
        uint256 borrowRatePerBlock;
        uint256 totalSupply;
        uint256 totalBorrow;
        uint256 supplyBalance;
        uint256 borrowBalance;
        uint256 liquidity;
        bool membership;
        uint256 exchangeRate; // Price of cTokens in terms of underlying tokens
        uint256 underlyingPrice; // Price of underlying tokens in ETH (scaled by 1e18)
        uint256 collateralFactor;
    }

    /**
     * @notice Returns data on the specified assets of the specified Fuse pool.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     * @param comptroller The Comptroller proxy contract address of the Fuse pool.
     * @param cTokens The cToken contract addresses of the assets to query.
     * @param user The user for which to get account data.
     * @return An array of Fuse pool assets.
     */
    function getPoolAssetsWithData(Comptroller comptroller, CToken[] memory cTokens, address user) internal returns (FusePoolAsset[] memory) {
        uint256 arrayLength = 0;

        for (uint256 i = 0; i < cTokens.length; i++) {
            (bool isListed, ) = comptroller.markets(address(cTokens[i]));
            if (isListed) arrayLength++;
        }

        FusePoolAsset[] memory detailedAssets = new FusePoolAsset[](arrayLength);
        uint256 index = 0;

        for (uint256 i = 0; i < cTokens.length; i++) {
            (bool isListed, uint256 collateralFactorMantissa) = comptroller.markets(address(cTokens[i]));
            if (!isListed) continue;

            FusePoolAsset memory asset;
            CToken cToken = cTokens[i];
            asset.cToken = address(cToken);

            if (cToken.isCEther()) {
                asset.underlyingName = "Ethereum";
                asset.underlyingSymbol = "ETH";
                asset.underlyingDecimals = 18;
                asset.underlyingBalance = user.balance;
            } else {
                asset.underlyingToken = CErc20(address(cToken)).underlying();
                ERC20Upgradeable underlying = ERC20Upgradeable(asset.underlyingToken);
                asset.underlyingName = underlying.name();
                asset.underlyingSymbol = underlying.symbol();
                asset.underlyingDecimals = underlying.decimals();
                asset.underlyingBalance = underlying.balanceOf(user);
            }

            asset.supplyRatePerBlock = cToken.supplyRatePerBlock();
            asset.borrowRatePerBlock = cToken.borrowRatePerBlock();
            asset.liquidity = cToken.getCash();
            asset.totalBorrow = cToken.totalBorrowsCurrent();
            asset.totalSupply = asset.liquidity.add(asset.totalBorrow).sub(cToken.totalReserves());
            asset.supplyBalance = cToken.balanceOfUnderlying(user);
            asset.borrowBalance = cToken.borrowBalanceCurrent(user);
            asset.membership = comptroller.checkMembership(user, cToken);
            asset.exchangeRate = cToken.exchangeRateCurrent();
            asset.underlyingPrice = comptroller.oracle().getUnderlyingPrice(cToken);
            asset.collateralFactor = collateralFactorMantissa;

            detailedAssets[index] = asset;
            index++;
        }

        return (detailedAssets);
    }

    /**
     * @notice Returns the assets of the specified Fuse pool.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     * @param comptroller The Comptroller proxy contract of the Fuse pool.
     * @return An array of Fuse pool assets.
     */
    function getPoolAssetsWithData(Comptroller comptroller) external returns (FusePoolAsset[] memory) {
        return getPoolAssetsWithData(comptroller, comptroller.getAllMarkets(), msg.sender);
    }

    /**
     * @dev Struct for a Fuse money market pool user.
     */
    struct FusePoolUser {
        address account;
        uint256 totalBorrow;
        uint256 totalCollateral;
        uint256 health;
        FusePoolAsset[] assets;
    }

    /**
     * @notice Returns the users of the specified Fuse pool.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     * @param comptroller The Comptroller proxy contract of the Fuse pool.
     * @param maxHealth The maximum health (scaled by 1e18) for which to return data.
     * @return An array of Fuse pool users, the pool's close factor, and the pool's liquidation incentive.
     */
    function getPoolUsersWithData(Comptroller comptroller, uint256 maxHealth) public returns (FusePoolUser[] memory, uint256, uint256) {
        address[] memory users = comptroller.getAllUsers();
        uint256 arrayLength = 0;

        for (uint256 i = 0; i < users.length; i++) {
            uint256 totalBorrow = 0;
            uint256 totalCollateral = 0;
            FusePoolAsset[] memory assets = getPoolAssetsWithData(comptroller, comptroller.getAssetsIn(users[i]), users[i]);

            for (uint256 j = 0; j < assets.length; j++) {
                totalBorrow = totalBorrow.add(assets[j].borrowBalance.mul(assets[j].underlyingPrice).div(1e18));
                if (assets[j].membership) totalCollateral = totalCollateral.add(assets[j].supplyBalance.mul(assets[j].underlyingPrice).div(1e18).mul(assets[j].collateralFactor).div(1e18));
            }

            uint256 health = totalBorrow > 0 ? totalCollateral.mul(1e18).div(totalBorrow) : 1e36;
            if (health <= maxHealth) arrayLength++;
        }

        FusePoolUser[] memory detailedUsers = new FusePoolUser[](arrayLength);
        uint256 index = 0;

        for (uint256 i = 0; i < users.length; i++) {
            uint256 totalBorrow = 0;
            uint256 totalCollateral = 0;
            FusePoolAsset[] memory assets = getPoolAssetsWithData(comptroller, comptroller.getAssetsIn(users[i]), users[i]);

            for (uint256 j = 0; j < assets.length; j++) {
                totalBorrow = totalBorrow.add(assets[j].borrowBalance.mul(assets[j].underlyingPrice).div(1e18));
                if (assets[j].membership) totalCollateral = totalCollateral.add(assets[j].supplyBalance.mul(assets[j].underlyingPrice).div(1e18).mul(assets[j].collateralFactor).div(1e18));
            }

            uint256 health = totalBorrow > 0 ? totalCollateral.mul(1e18).div(totalBorrow) : 1e36;
            if (health > maxHealth) continue;
            detailedUsers[index] = FusePoolUser(users[i], totalBorrow, totalCollateral, health, assets);
            index++;
        }

        return (detailedUsers, comptroller.closeFactorMantissa(), comptroller.liquidationIncentiveMantissa());
    }

    /**
     * @notice Returns the users of each public Fuse pool.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     * @param maxHealth The maximum health (scaled by 1e18) for which to return data.
     * @return An array of pools' Comptroller proxy addresses, an array of arrays of Fuse pool users, an array of pools' close factors, and an array of pools' liquidation incentives.
     */
    function getPublicPoolUsersWithData(uint256 maxHealth) external returns (address[] memory, FusePoolUser[][] memory, uint256[] memory, uint256[] memory) {
        (, FusePool[] memory publicPools) = getPublicPools();
        address[] memory comptrollers = new address[](publicPools.length);
        FusePoolUser[][] memory users = new FusePoolUser[][](publicPools.length);
        uint256[] memory closeFactors = new uint256[](publicPools.length);
        uint256[] memory liquidationIncentives = new uint256[](publicPools.length);

        for (uint256 i = 0; i < publicPools.length; i++) {
            comptrollers[i] = publicPools[i].comptroller;
            (users[i], closeFactors[i], liquidationIncentives[i]) = getPoolUsersWithData(Comptroller(publicPools[i].comptroller), maxHealth);
        }

        return (comptrollers, users, closeFactors, liquidationIncentives);
    }

    /**
     * @notice Returns the users of the specified Fuse pools.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     * @param comptrollers The Comptroller proxy contracts of the Fuse pools.
     * @param maxHealth The maximum health (scaled by 1e18) for which to return data.
     * @return An array of arrays of Fuse pool users, an array of pools' close factors, and an array of pools' liquidation incentives.
     */
    function getPoolUsersWithData(Comptroller[] calldata comptrollers, uint256 maxHealth) external returns (FusePoolUser[][] memory, uint256[] memory, uint256[] memory) {
        FusePoolUser[][] memory users = new FusePoolUser[][](comptrollers.length);
        uint256[] memory closeFactors = new uint256[](comptrollers.length);
        uint256[] memory liquidationIncentives = new uint256[](comptrollers.length);

        for (uint256 i = 0; i < comptrollers.length; i++) {
            (users[i], closeFactors[i], liquidationIncentives[i]) = getPoolUsersWithData(Comptroller(comptrollers[i]), maxHealth);
        }

        return (users, closeFactors, liquidationIncentives);
    }
}
