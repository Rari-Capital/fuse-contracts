/**
 * COPYRIGHT © 2020 RARI CAPITAL, INC. ALL RIGHTS RESERVED.
 * No one is permitted to use the software for any purpose without the explicit permission of David Lucid of Rari Capital, Inc.
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
        return pools.length - 1;
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
        // Input validation
        require(implementation != address(0), "No Comptroller implementation contract address specified.");
        require(priceOracle != address(0), "No PriceOracle contract address specified.");

        // Deploy Unitroller using msg.sender, name, and block.number as a salt
        bytes memory unitrollerCreationCode = hex"60806040526001805460ff60a01b1916600160a01b17905534801561002357600080fd5b50600080546001600160a01b031916331790556106f8806100456000396000f3fe6080604052600436106100915760003560e01c8063c1e8033411610059578063c1e80334146101dd578063dcfbc0c7146101f2578063e992a04114610207578063e9c714f21461023a578063f851a4401461024f57610091565b80630a755ec214610114578063267822471461013d578063b71d1a0c1461016e578063bb82aa5e146101b3578063bf0f1d7b146101c8575b6002546040516000916001600160a01b031690829036908083838082843760405192019450600093509091505080830381855af49150503d80600081146100f4576040519150601f19603f3d011682016040523d82523d6000602084013e6100f9565b606091505b505090506040513d6000823e818015610110573d82f35b3d82fd5b34801561012057600080fd5b50610129610264565b604080519115158252519081900360200190f35b34801561014957600080fd5b50610152610274565b604080516001600160a01b039092168252519081900360200190f35b34801561017a57600080fd5b506101a16004803603602081101561019157600080fd5b50356001600160a01b0316610283565b60408051918252519081900360200190f35b3480156101bf57600080fd5b5061015261030f565b3480156101d457600080fd5b506101a161031e565b3480156101e957600080fd5b506101a161039b565b3480156101fe57600080fd5b5061015261048e565b34801561021357600080fd5b506101a16004803603602081101561022a57600080fd5b50356001600160a01b031661049d565b34801561024657600080fd5b506101a161051c565b34801561025b57600080fd5b50610152610602565b600154600160a01b900460ff1681565b6001546001600160a01b031681565b600061028d610611565b6102a45761029d60016010610656565b905061030a565b600180546001600160a01b038481166001600160a01b0319831681179093556040805191909216808252602082019390935281517fca4f2f25d0898edd99413412fb94012f9e54ec8142f9b093e7720646a95b16a9929181900390910190a160005b9150505b919050565b6002546001600160a01b031681565b6000610328610611565b61033f576103386001600e610656565b9050610398565b600154600160a01b900460ff1661035c576103386001600f610656565b6001805460ff60a01b191690556040517fc8ed31b431dd871a74f7e15bc645f3dbdd94636e59d7633a4407b044524eb45990600090a160005b90505b90565b6003546000906001600160a01b0316331415806103c157506003546001600160a01b0316155b156103d157610338600180610656565b60028054600380546001600160a01b038082166001600160a01b031980861682179687905590921690925560408051938316808552949092166020840152815190927fd604de94d45953f9138079ec1b82d533cb2160c906d1076d1f7ed54befbca97a92908290030190a1600354604080516001600160a01b038085168252909216602083015280517fe945ccee5d701fc83f9b8aa8ca94ea4219ec1fcbd4f4cab4f0ea57c5c3e1d8159281900390910190a160005b9250505090565b6003546001600160a01b031681565b60006104a7610611565b6104b75761029d60016011610656565b600380546001600160a01b038481166001600160a01b0319831617928390556040805192821680845293909116602083015280517fe945ccee5d701fc83f9b8aa8ca94ea4219ec1fcbd4f4cab4f0ea57c5c3e1d8159281900390910190a16000610306565b6001546000906001600160a01b031633141580610537575033155b156105485761033860016000610656565b60008054600180546001600160a01b038082166001600160a01b031980861682179687905590921690925560408051938316808552949092166020840152815190927ff9ffabca9c8276e99321725bcb43fb076a6c66a54b7f21c4e8146d8519b417dc92908290030190a1600154604080516001600160a01b038085168252909216602083015280517fca4f2f25d0898edd99413412fb94012f9e54ec8142f9b093e7720646a95b16a99281900390910190a16000610487565b6000546001600160a01b031681565b600080546001600160a01b0316331480156106355750600154600160a01b900460ff165b8061039557505033732279b7a0a67db372996a5fab50d91eaa73d2ebe61490565b60007f45b96fe442630264581b197e84bbada861235052c5a1aadfff9ea4e40a969aa083601181111561068557fe5b83601681111561069157fe5b604080519283526020830191909152600082820152519081900360600190a18260118111156106bc57fe5b939250505056fea265627a7a7231582023916d21b3bebd3df18a695d7a9e4f58a9627c1743c4b9b553516c8a38c00e5664736f6c63430005110032";
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, name, block.number));
        address proxy;

        assembly {
            proxy := create2(0, add(unitrollerCreationCode, 32), mload(unitrollerCreationCode), salt)
        }

        // Setup Unitroller
        Unitroller unitroller = Unitroller(proxy);
        unitroller._setPendingImplementation(implementation);
        Comptroller comptrollerImplementation = Comptroller(implementation);
        comptrollerImplementation._become(unitroller);
        Comptroller comptrollerProxy = Comptroller(proxy);

        // Set money market parameters
        comptrollerProxy._setCloseFactor(closeFactor);
        comptrollerProxy._setMaxAssets(maxAssets);
        comptrollerProxy._setLiquidationIncentive(liquidationIncentive);
        comptrollerProxy._setPriceOracle(PriceOracle(priceOracle));

        // Make msg.sender the admin
        unitroller._setPendingAdmin(msg.sender);

        // Register the pool with this FusePoolDirectory
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
     * @notice Returns arrays of all public Fuse pool indexes, data, total supply balances (in ETH), total borrow balances (in ETH), and booleans indicating if there was an error computing total supply and total borrow.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPublicPoolsWithData() external returns (uint256[] memory, FusePool[] memory, uint256[] memory, uint256[] memory, bool[] memory) {
        (uint256[] memory indexes, FusePool[] memory publicPools) = getPublicPools();
        uint256[] memory totalSupply = new uint256[](publicPools.length);
        uint256[] memory totalBorrow = new uint256[](publicPools.length);
        bool[] memory errored = new bool[](publicPools.length);
        
        for (uint256 i = 0; i < publicPools.length; i++) {
            try this.getPoolStats(Comptroller(publicPools[i].comptroller)) returns (uint256 _totalSupply, uint256 _totalBorrow) {
                totalSupply[i] = _totalSupply;
                totalBorrow[i] = _totalBorrow;
            } catch {
                errored[i] = true;
            }
        }

        return (indexes, publicPools, totalSupply, totalBorrow, errored);
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
    function getPoolsByAccountWithData(address account) external returns (uint256[] memory, FusePool[] memory, uint256[] memory, uint256[] memory, bool[] memory) {
        (uint256[] memory indexes, FusePool[] memory accountPools) = getPoolsByAccount(account);
        uint256[] memory totalSupply = new uint256[](accountPools.length);
        uint256[] memory totalBorrow = new uint256[](accountPools.length);
        bool[] memory errored = new bool[](accountPools.length);

        for (uint256 i = 0; i < accountPools.length; i++) {
            try this.getPoolStats(Comptroller(accountPools[i].comptroller)) returns (uint256 _totalSupply, uint256 _totalBorrow) {
                totalSupply[i] = _totalSupply;
                totalBorrow[i] = _totalBorrow;
            } catch {
                errored[i] = true;
            }
        }

        return (indexes, accountPools, totalSupply, totalBorrow, errored);
    }

    /**
     * @notice Returns total supply balance (in ETH) and total borrow balance (in ETH) of a Fuse pool.
     */
    function getPoolStats(Comptroller comptroller) external returns (uint256, uint256) {
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
     * @notice Returns the borrowers of the specified Fuse pool.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     * @param comptroller The Comptroller proxy contract of the Fuse pool.
     * @param maxHealth The maximum health (scaled by 1e18) for which to return data.
     * @return An array of Fuse pool users, the pool's close factor, and the pool's liquidation incentive.
     */
    function getPoolUsersWithData(Comptroller comptroller, uint256 maxHealth) public returns (FusePoolUser[] memory, uint256, uint256) {
        address[] memory users = comptroller.getAllBorrowers();
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

    /**
     * @notice Returns arrays of Fuse pool indexes and data supplied to by `account`.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     */
    function getPoolsBySupplier(address account) public view returns (uint256[] memory, FusePool[] memory) {
        uint256 arrayLength = 0;

        for (uint256 i = 0; i < pools.length; i++) {
            Comptroller comptroller = Comptroller(pools[i].comptroller);

            if (comptroller.suppliers(account)) {
                CToken[] memory allMarkets = comptroller.getAllMarkets();

                for (uint256 j = 0; j < allMarkets.length; j++) if (allMarkets[j].balanceOf(account) > 0) {
                    arrayLength++;
                    break;
                }
            }
        }

        uint256[] memory indexes = new uint256[](arrayLength);
        FusePool[] memory accountPools = new FusePool[](arrayLength);
        uint256 index = 0;

        for (uint256 i = 0; i < pools.length; i++) {
            Comptroller comptroller = Comptroller(pools[i].comptroller);

            if (comptroller.suppliers(account)) {
                CToken[] memory allMarkets = comptroller.getAllMarkets();

                for (uint256 j = 0; j < allMarkets.length; j++) if (allMarkets[j].balanceOf(account) > 0) {
                    indexes[index] = i;
                    accountPools[index] = pools[i];
                    index++;
                    break;
                }
            }
        }

        return (indexes, accountPools);
    }

    /**
     * @notice Returns arrays of the indexes of Fuse pools supplied to by `account`, data, total supply balances (in ETH), and total borrow balances (in ETH).
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPoolsBySupplierWithData(address account) external returns (uint256[] memory, FusePool[] memory, uint256[] memory, uint256[] memory, bool[] memory) {
        (uint256[] memory indexes, FusePool[] memory accountPools) = getPoolsBySupplier(account);
        uint256[] memory totalSupply = new uint256[](accountPools.length);
        uint256[] memory totalBorrow = new uint256[](accountPools.length);
        bool[] memory errored = new bool[](accountPools.length);

        for (uint256 i = 0; i < accountPools.length; i++) {
            try this.getPoolStats(Comptroller(accountPools[i].comptroller)) returns (uint256 _totalSupply, uint256 _totalBorrow) {
                totalSupply[i] = _totalSupply;
                totalBorrow[i] = _totalBorrow;
            } catch {
                errored[i] = true;
            }
        }

        return (indexes, accountPools, totalSupply, totalBorrow, errored);
    }

    /**
     * @dev Maps Ethereum accounts to arrays of Fuse pool Comptroller proxy contract addresses.
     */
    mapping(address => address[]) private _bookmarks;

    /**
     * @notice Returns arrays of Fuse pool Unitroller (Comptroller proxy) contract addresses bookmarked by `account`.
     */
    function getBookmarks(address account) external view returns (address[] memory) {
        return _bookmarks[account];
    }

    /**
     * @notice Bookmarks a Fuse pool Unitroller (Comptroller proxy) contract addresses.
     */
    function bookmarkPool(address comptroller) external {
        _bookmarks[msg.sender].push(comptroller);
    }
}
