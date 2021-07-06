// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "./external/compound/Comptroller.sol";
import "./external/compound/PriceOracle.sol";
import "./external/compound/CToken.sol";
import "./external/compound/CErc20.sol";

import "./external/uniswap/IUniswapV2Pair.sol";

import "./FusePoolDirectory.sol";
import "./oracles/MasterPriceOracle.sol";

/**
 * @title FusePoolLens
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FusePoolLens is a lens for Fuse money market pools.
 */
contract FusePoolLens is Initializable {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice Constructor to set the `FusePoolDirectory` contract object.
     */
    function initialize(FusePoolDirectory _directory) public initializer {
        require(address(_directory) != address(0), "FusePoolDirectory instance cannot be the zero address.");
        directory = _directory;
    }

    /**
     * @notice `FusePoolDirectory` contract object.
     */
    FusePoolDirectory public directory;

    /**
     * @notice Returns arrays of all public Fuse pool indexes, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPublicPoolsWithData() external returns (uint256[] memory, FusePoolDirectory.FusePool[] memory, uint256[] memory, uint256[] memory, address[][] memory, string[][] memory, bool[] memory) {
        (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory publicPools) = directory.getPublicPools();
        return getPoolsWithData(indexes, publicPools);
    }

    /**
     * @notice Returns arrays of the indexes of Fuse pools created by `account`, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPoolsByAccountWithData(address account) external returns (uint256[] memory, FusePoolDirectory.FusePool[] memory, uint256[] memory, uint256[] memory, address[][] memory, string[][] memory, bool[] memory) {
        (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory accountPools) = directory.getPoolsByAccount(account);
        return getPoolsWithData(indexes, accountPools);
    }

    /**
     * @notice Internal function returning arrays of requested Fuse pool indexes, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPoolsWithData(uint256[] memory indexes, FusePoolDirectory.FusePool[] memory pools) internal returns (uint256[] memory, FusePoolDirectory.FusePool[] memory, uint256[] memory, uint256[] memory, address[][] memory, string[][] memory, bool[] memory) {
        uint256[] memory totalSupply = new uint256[](pools.length);
        uint256[] memory totalBorrow = new uint256[](pools.length);
        address[][] memory underlyingTokens = new address[][](pools.length);
        string[][] memory underlyingSymbols = new string[][](pools.length);
        bool[] memory errored = new bool[](pools.length);
        
        for (uint256 i = 0; i < pools.length; i++) {
            try this.getPoolSummary(Comptroller(pools[i].comptroller)) returns (uint256 _totalSupply, uint256 _totalBorrow, address[] memory _underlyingTokens, string[] memory _underlyingSymbols) {
                totalSupply[i] = _totalSupply;
                totalBorrow[i] = _totalBorrow;
                underlyingTokens[i] = _underlyingTokens;
                underlyingSymbols[i] = _underlyingSymbols;
            } catch {
                errored[i] = true;
            }
        }

        return (indexes, pools, totalSupply, totalBorrow, underlyingTokens, underlyingSymbols, errored);
    }

    /**
     * @notice Returns total supply balance (in ETH), total borrow balance (in ETH), underlying token addresses, and underlying token symbols of a Fuse pool.
     */
    function getPoolSummary(Comptroller comptroller) external returns (uint256, uint256, address[] memory, string[] memory) {
        uint256 totalBorrow = 0;
        uint256 totalSupply = 0;
        CToken[] memory cTokens = comptroller.getAllMarkets();
        address[] memory underlyingTokens = new address[](cTokens.length);
        string[] memory underlyingSymbols = new string[](cTokens.length);
        PriceOracle oracle = comptroller.oracle();

        for (uint256 i = 0; i < cTokens.length; i++) {
            CToken cToken = cTokens[i];
            (bool isListed, ) = comptroller.markets(address(cToken));
            if (!isListed) continue;
            uint256 assetTotalBorrow = cToken.totalBorrowsCurrent();
            uint256 assetTotalSupply = cToken.getCash().add(assetTotalBorrow).sub(cToken.totalReserves().add(cToken.totalAdminFees()).add(cToken.totalFuseFees()));
            uint256 underlyingPrice = oracle.getUnderlyingPrice(cToken);
            totalBorrow = totalBorrow.add(assetTotalBorrow.mul(underlyingPrice).div(1e18));
            totalSupply = totalSupply.add(assetTotalSupply.mul(underlyingPrice).div(1e18));

            if (cToken.isCEther()) {
                underlyingTokens[i] = address(0);
                underlyingSymbols[i] = "ETH";
            } else {
                underlyingTokens[i] = CErc20(address(cToken)).underlying();
                (, underlyingSymbols[i]) = getTokenNameAndSymbol(underlyingTokens[i]);
            }
        }

        return (totalSupply, totalBorrow, underlyingTokens, underlyingSymbols);
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
        address oracle;
        uint256 collateralFactor;
        uint256 reserveFactor;
        uint256 adminFee;
        uint256 fuseFee;
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
        PriceOracle oracle = comptroller.oracle();

        for (uint256 i = 0; i < cTokens.length; i++) {
            // Check if market is listed and get collateral factor
            (bool isListed, uint256 collateralFactorMantissa) = comptroller.markets(address(cTokens[i]));
            if (!isListed) continue;

            // Start adding data to FusePoolAsset
            FusePoolAsset memory asset;
            CToken cToken = cTokens[i];
            asset.cToken = address(cToken);

            // Get underlying asset data
            if (cToken.isCEther()) {
                asset.underlyingName = "Ethereum";
                asset.underlyingSymbol = "ETH";
                asset.underlyingDecimals = 18;
                asset.underlyingBalance = user.balance;
            } else {
                asset.underlyingToken = CErc20(address(cToken)).underlying();
                ERC20Upgradeable underlying = ERC20Upgradeable(asset.underlyingToken);
                (asset.underlyingName, asset.underlyingSymbol) = getTokenNameAndSymbol(asset.underlyingToken);
                asset.underlyingDecimals = underlying.decimals();
                asset.underlyingBalance = underlying.balanceOf(user);
            }

            // Get cToken data
            asset.supplyRatePerBlock = cToken.supplyRatePerBlock();
            asset.borrowRatePerBlock = cToken.borrowRatePerBlock();
            asset.liquidity = cToken.getCash();
            asset.totalBorrow = cToken.totalBorrowsCurrent();
            asset.totalSupply = asset.liquidity.add(asset.totalBorrow).sub(cToken.totalReserves().add(cToken.totalAdminFees()).add(cToken.totalFuseFees()));
            asset.supplyBalance = cToken.balanceOfUnderlying(user);
            asset.borrowBalance = cToken.borrowBalanceStored(user); // We would use borrowBalanceCurrent but we already accrue interest above
            asset.membership = comptroller.checkMembership(user, cToken);
            asset.exchangeRate = cToken.exchangeRateStored(); // We would use exchangeRateCurrent but we already accrue interest above
            asset.underlyingPrice = oracle.getUnderlyingPrice(cToken);

            // Get oracle for this cToken
            asset.oracle = address(oracle);

            try MasterPriceOracle(asset.oracle).oracles(asset.underlyingToken) returns (PriceOracle _oracle) {
                asset.oracle = address(_oracle);
            } catch { }

            // More cToken data
            asset.collateralFactor = collateralFactorMantissa;
            asset.reserveFactor = cToken.reserveFactorMantissa();
            asset.adminFee = cToken.adminFeeMantissa();
            asset.fuseFee = cToken.fuseFeeMantissa();

            // Add to assets array and increment index
            detailedAssets[index] = asset;
            index++;
        }

        return (detailedAssets);
    }

    /**
     * @notice Returns the `name` and `symbol` of `token`.
     * Supports Uniswap V2 and SushiSwap LP tokens as well as MKR.
     * @param token An ERC20 token contract object.
     * @return The `name` and `symbol`.
     */
    function getTokenNameAndSymbol(address token) internal view returns (string memory, string memory) {
        // MKR is a DSToken and uses bytes32
        if (token == 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2) return ("Maker", "MKR");
        if (token == 0xB8c77482e45F1F44dE1745F52C74426C631bDD52) return ("BNB", "BNB");

        // Get name and symbol from token contract
        ERC20Upgradeable tokenContract = ERC20Upgradeable(token);
        string memory name = tokenContract.name();
        string memory symbol = tokenContract.symbol();

        // Check for Uniswap V2/SushiSwap pair
        try IUniswapV2Pair(token).token0() returns (address _token0) {
            bool isUniswapToken = keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked("Uniswap V2")) && keccak256(abi.encodePacked(symbol)) == keccak256(abi.encodePacked("UNI-V2"));
            bool isSushiSwapToken = !isUniswapToken && keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked("SushiSwap LP Token")) && keccak256(abi.encodePacked(symbol)) == keccak256(abi.encodePacked("SLP"));

            if (isUniswapToken || isSushiSwapToken) {
                ERC20Upgradeable token0 = ERC20Upgradeable(_token0);
                ERC20Upgradeable token1 = ERC20Upgradeable(IUniswapV2Pair(token).token1());
                name = string(abi.encodePacked(isSushiSwapToken ? "SushiSwap " : "Uniswap ", token0.symbol(), "/", token1.symbol(), " LP"));
                symbol = string(abi.encodePacked(token0.symbol(), "-", token1.symbol()));
            }
        } catch { }

        return (name, symbol);
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
     * @return An array of pools' Comptroller proxy addresses, an array of arrays of Fuse pool users, an array of pools' close factors, an array of pools' liquidation incentives, and an array of booleans indicating if retrieving each pool's data failed.
     */
    function getPublicPoolUsersWithData(uint256 maxHealth) external returns (address[] memory, FusePoolUser[][] memory, uint256[] memory, uint256[] memory, bool[] memory) {
        (, FusePoolDirectory.FusePool[] memory publicPools) = directory.getPublicPools();
        address[] memory comptrollers = new address[](publicPools.length);
        FusePoolUser[][] memory users = new FusePoolUser[][](publicPools.length);
        uint256[] memory closeFactors = new uint256[](publicPools.length);
        uint256[] memory liquidationIncentives = new uint256[](publicPools.length);
        bool[] memory errored = new bool[](publicPools.length);

        for (uint256 i = 0; i < publicPools.length; i++) {
            comptrollers[i] = publicPools[i].comptroller;

            try this.getPoolUsersWithData(Comptroller(publicPools[i].comptroller), maxHealth) returns (FusePoolUser[] memory _users, uint256 closeFactor, uint256 liquidationIncentive) {
                users[i] = _users;
                closeFactors[i] = closeFactor;
                liquidationIncentives[i] = liquidationIncentive;
            } catch {
                errored[i] = true;
            }
        }

        return (comptrollers, users, closeFactors, liquidationIncentives, errored);
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
    function getPoolsBySupplier(address account) public view returns (uint256[] memory, FusePoolDirectory.FusePool[] memory) {
        FusePoolDirectory.FusePool[] memory pools = directory.getAllPools();
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
        FusePoolDirectory.FusePool[] memory accountPools = new FusePoolDirectory.FusePool[](arrayLength);
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
     * @notice Returns arrays of the indexes of Fuse pools supplied to by `account`, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPoolsBySupplierWithData(address account) external returns (uint256[] memory, FusePoolDirectory.FusePool[] memory, uint256[] memory, uint256[] memory, address[][] memory, string[][] memory, bool[] memory) {
        (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory accountPools) = getPoolsBySupplier(account);
        return getPoolsWithData(indexes, accountPools);
    }

    /**
     * @notice Returns the total supply balance (in ETH) and the total borrow balance (in ETH) of the caller across all pools.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getUserSummary(address account) external returns (uint256, uint256, bool) {
        FusePoolDirectory.FusePool[] memory pools = directory.getAllPools();
        uint256 borrowBalance = 0;
        uint256 supplyBalance = 0;
        bool errors = false;

        for (uint256 i = 0; i < pools.length; i++) {
            try this.getPoolUserSummary(Comptroller(pools[i].comptroller), account) returns (uint256 poolSupplyBalance, uint256 poolBorrowBalance) {
                supplyBalance = supplyBalance.add(poolSupplyBalance);
                borrowBalance = borrowBalance.add(poolBorrowBalance);
            } catch {
                errors = true;
            }
        }

        return (supplyBalance, borrowBalance, errors);
    }

    /**
     * @notice Returns the total supply balance (in ETH) and the total borrow balance (in ETH) of the caller in the specified pool.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPoolUserSummary(Comptroller comptroller, address account) external returns (uint256, uint256) {
        uint256 borrowBalance = 0;
        uint256 supplyBalance = 0;

        if (!comptroller.suppliers(account)) return (0, 0);
        CToken[] memory cTokens = comptroller.getAllMarkets();
        PriceOracle oracle = comptroller.oracle();

        for (uint256 i = 0; i < cTokens.length; i++) {
            CToken cToken = cTokens[i];
            (bool isListed, ) = comptroller.markets(address(cToken));
            if (!isListed) continue;
            uint256 assetSupplyBalance = cToken.balanceOfUnderlying(account);
            uint256 assetBorrowBalance = cToken.borrowBalanceStored(account); // We would use borrowBalanceCurrent but we already accrue interest above
            uint256 underlyingPrice = oracle.getUnderlyingPrice(cToken);
            borrowBalance = borrowBalance.add(assetBorrowBalance.mul(underlyingPrice).div(1e18));
            supplyBalance = supplyBalance.add(assetSupplyBalance.mul(underlyingPrice).div(1e18));
        }

        return (supplyBalance, borrowBalance);
    }

    /**
     * @notice Returns arrays of Fuse pool indexes and data with a whitelist containing `account`.
     * Note that the whitelist does not have to be enforced.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     */
    function getWhitelistedPoolsByAccount(address account) public view returns (uint256[] memory, FusePoolDirectory.FusePool[] memory) {
        FusePoolDirectory.FusePool[] memory pools = directory.getAllPools();
        uint256 arrayLength = 0;

        for (uint256 i = 0; i < pools.length; i++) {
            Comptroller comptroller = Comptroller(pools[i].comptroller);

            if (comptroller.whitelist(account)) arrayLength++;
        }

        uint256[] memory indexes = new uint256[](arrayLength);
        FusePoolDirectory.FusePool[] memory accountPools = new FusePoolDirectory.FusePool[](arrayLength);
        uint256 index = 0;

        for (uint256 i = 0; i < pools.length; i++) {
            Comptroller comptroller = Comptroller(pools[i].comptroller);

            if (comptroller.whitelist(account)) {
                indexes[index] = i;
                accountPools[index] = pools[i];
                index++;
                break;
            }
        }

        return (indexes, accountPools);
    }

    /**
     * @notice Returns arrays of the indexes of Fuse pools with a whitelist containing `account`, data, total supply balances (in ETH), total borrow balances (in ETH), arrays of underlying token addresses, arrays of underlying asset symbols, and booleans indicating if retrieving each pool's data failed.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getWhitelistedPoolsByAccountWithData(address account) external returns (uint256[] memory, FusePoolDirectory.FusePool[] memory, uint256[] memory, uint256[] memory, address[][] memory, string[][] memory, bool[] memory) {
        (uint256[] memory indexes, FusePoolDirectory.FusePool[] memory accountPools) = getWhitelistedPoolsByAccount(account);
        return getPoolsWithData(indexes, accountPools);
    }

    struct CTokenOwnership {
        address cToken;
        address admin;
        bool adminHasRights;
        bool fuseAdminHasRights;
    }

    /**
     * @notice Returns the admin, admin rights, Fuse admin (constant), Fuse admin rights, and an array of cTokens with differing properties.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     * Ideally, we can add the `view` modifier, but many cToken functions potentially modify the state.
     */
    function getPoolOwnership(Comptroller comptroller) external view returns (address, bool, bool, CTokenOwnership[] memory) {
        // Get pool ownership
        address comptrollerAdmin = comptroller.admin();
        bool comptrollerAdminHasRights = comptroller.adminHasRights();
        bool comptrollerFuseAdminHasRights = comptroller.fuseAdminHasRights();

        // Get cToken ownership
        CToken[] memory cTokens = comptroller.getAllMarkets();
        uint256 arrayLength = 0;

        for (uint256 i = 0; i < cTokens.length; i++) {
            CToken cToken = cTokens[i];
            (bool isListed, ) = comptroller.markets(address(cToken));
            if (!isListed) continue;
            
            address cTokenAdmin = cToken.admin();
            bool cTokenAdminHasRights = cToken.adminHasRights();
            bool cTokenFuseAdminHasRights = cToken.fuseAdminHasRights();

            // If outlier, push to array
            if (cTokenAdmin != comptrollerAdmin || cTokenAdminHasRights != comptrollerAdminHasRights || cTokenFuseAdminHasRights != comptrollerFuseAdminHasRights)
                arrayLength++;
        }

        CTokenOwnership[] memory outliers = new CTokenOwnership[](arrayLength);
        uint256 arrayIndex = 0;

        for (uint256 i = 0; i < cTokens.length; i++) {
            CToken cToken = cTokens[i];
            (bool isListed, ) = comptroller.markets(address(cToken));
            if (!isListed) continue;
            
            address cTokenAdmin = cToken.admin();
            bool cTokenAdminHasRights = cToken.adminHasRights();
            bool cTokenFuseAdminHasRights = cToken.fuseAdminHasRights();

            // If outlier, push to array and increment array index
            if (cTokenAdmin != comptrollerAdmin || cTokenAdminHasRights != comptrollerAdminHasRights || cTokenFuseAdminHasRights != comptrollerFuseAdminHasRights)
                outliers[arrayIndex] = CTokenOwnership(address(cToken), cTokenAdmin, cTokenAdminHasRights, cTokenFuseAdminHasRights);
            arrayIndex++;
        }
        
        return (comptrollerAdmin, comptrollerAdminHasRights, comptrollerFuseAdminHasRights, outliers);
    }
}
