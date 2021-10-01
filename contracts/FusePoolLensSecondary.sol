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
import "./external/compound/RewardsDistributor.sol";

import "./external/uniswap/IUniswapV2Pair.sol";

import "./FusePoolDirectory.sol";
import "./oracles/MasterPriceOracle.sol";

/**
 * @title FusePoolLensSecondary
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FusePoolLensSecondary returns data on Fuse interest rate pools in mass for viewing by dApps, bots, etc.
 */
contract FusePoolLensSecondary is Initializable {
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
     * @notice Struct for ownership over a CToken.
     */
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
            
            address cTokenAdmin;
            try cToken.admin() returns (address _cTokenAdmin) {
                cTokenAdmin = _cTokenAdmin;
            } catch {
                continue;
            }
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
            
            address cTokenAdmin;
            try cToken.admin() returns (address _cTokenAdmin) {
                cTokenAdmin = _cTokenAdmin;
            } catch {
                continue;
            }
            bool cTokenAdminHasRights = cToken.adminHasRights();
            bool cTokenFuseAdminHasRights = cToken.fuseAdminHasRights();

            // If outlier, push to array and increment array index
            if (cTokenAdmin != comptrollerAdmin || cTokenAdminHasRights != comptrollerAdminHasRights || cTokenFuseAdminHasRights != comptrollerFuseAdminHasRights) {
                outliers[arrayIndex] = CTokenOwnership(address(cToken), cTokenAdmin, cTokenAdminHasRights, cTokenFuseAdminHasRights);
                arrayIndex++;
            }
        }
        
        return (comptrollerAdmin, comptrollerAdminHasRights, comptrollerFuseAdminHasRights, outliers);
    }
    
    /**
     * @notice Determine the maximum redeem amount of a cToken.
     * @param cTokenModify The market to hypothetically redeem in.
     * @param account The account to determine liquidity for.
     * @return Maximum redeem amount.
     */
    function getMaxRedeem(address account, CToken cTokenModify) external returns (uint256) {
        return getMaxRedeemOrBorrow(account, cTokenModify, false);
    }

    /**
     * @notice Determine the maximum borrow amount of a cToken.
     * @param cTokenModify The market to hypothetically borrow in.
     * @param account The account to determine liquidity for.
     * @return Maximum borrow amount.
     */
    function getMaxBorrow(address account, CToken cTokenModify) external returns (uint256) {
        return getMaxRedeemOrBorrow(account, cTokenModify, true);
    }

    /**
     * @dev Internal function to determine the maximum borrow/redeem amount of a cToken.
     * @param cTokenModify The market to hypothetically borrow/redeem in.
     * @param account The account to determine liquidity for.
     * @return Maximum borrow/redeem amount.
     */
    function getMaxRedeemOrBorrow(address account, CToken cTokenModify, bool isBorrow) internal returns (uint256) {
        // Accrue interest
        uint256 balanceOfUnderlying = cTokenModify.balanceOfUnderlying(account);

        // Get account liquidity
        Comptroller comptroller = Comptroller(cTokenModify.comptroller());
        (uint256 err, uint256 liquidity, uint256 shortfall) = comptroller.getAccountLiquidity(account);
        require(err == 0, "Comptroller error when calculating account liquidity.");
        if (shortfall > 0) return 0; // Shortfall, so no more borrow/redeem

        // Get max borrow/redeem
        uint256 maxBorrowOrRedeemAmount;

        if (!isBorrow && !comptroller.checkMembership(msg.sender, cTokenModify)) {
            // Max redeem = balance of underlying if not used as collateral
            maxBorrowOrRedeemAmount = balanceOfUnderlying;
        } else {
            // Avoid "stack too deep" error by separating this logic
            maxBorrowOrRedeemAmount = _getMaxRedeemOrBorrow(liquidity, cTokenModify, isBorrow);

            // Redeem only: max out at underlying balance
            if (!isBorrow && balanceOfUnderlying < maxBorrowOrRedeemAmount) maxBorrowOrRedeemAmount = balanceOfUnderlying;
        }

        // Get max borrow or redeem considering cToken liquidity
        uint256 cTokenLiquidity = cTokenModify.getCash();

        // Return the minimum of the two maximums
        return maxBorrowOrRedeemAmount <= cTokenLiquidity ? maxBorrowOrRedeemAmount : cTokenLiquidity;
    }

    /**
     * @dev Portion of the logic in `getMaxRedeemOrBorrow` above separated to avoid "stack too deep" errors.
     */
    function _getMaxRedeemOrBorrow(uint256 liquidity, CToken cTokenModify, bool isBorrow) internal view returns (uint256) {
        if (liquidity <= 0) return 0; // No available account liquidity, so no more borrow/redeem

        // Get the normalized price of the asset
        Comptroller comptroller = Comptroller(cTokenModify.comptroller());
        uint256 conversionFactor = comptroller.oracle().getUnderlyingPrice(cTokenModify);
        require(conversionFactor > 0, "Oracle price error.");

        // Pre-compute a conversion factor from tokens -> ether (normalized price value)
        if (!isBorrow) {
            (, uint256 collateralFactorMantissa) = comptroller.markets(address(cTokenModify));
            conversionFactor = collateralFactorMantissa.mul(conversionFactor).div(1e18);
        }

        // Get max borrow or redeem considering excess account liquidity
        return liquidity.mul(1e18).div(conversionFactor);
    }

    /**
     * @notice Returns an array of all markets, an array of all `RewardsDistributor` contracts, an array of reward token addresses for each `RewardsDistributor`, an array of supply speeds for each distributor for each, and their borrow speeds.
     * @param comptroller The Fuse pool Comptroller to check.
     */
    function getRewardSpeedsByPool(Comptroller comptroller) public view returns (CToken[] memory, RewardsDistributor[] memory, address[] memory, uint256[][] memory, uint256[][] memory) {
        CToken[] memory allMarkets = comptroller.getAllMarkets();
        RewardsDistributor[] memory distributors;

        try comptroller.getRewardsDistributors() returns (RewardsDistributor[] memory _distributors) {
            distributors = _distributors;
        } catch {
            distributors = new RewardsDistributor[](0);
        }

        address[] memory rewardTokens = new address[](distributors.length);
        uint256[][] memory supplySpeeds = new uint256[][](allMarkets.length);
        uint256[][] memory borrowSpeeds = new uint256[][](allMarkets.length);

        // Get reward tokens for each distributor
        for (uint256 i = 0; i < distributors.length; i++) rewardTokens[i] = distributors[i].rewardToken();

        // Get reward speeds for each market for each distributor
        for (uint256 i = 0; i < allMarkets.length; i++) {
            address cToken = address(allMarkets[i]);
            supplySpeeds[i] = new uint256[](distributors.length);
            borrowSpeeds[i] = new uint256[](distributors.length);

            for (uint256 j = 0; j < distributors.length; j++) {
                RewardsDistributor distributor = distributors[j];
                supplySpeeds[i][j] = distributor.compSupplySpeeds(cToken);
                borrowSpeeds[i][j] = distributor.compBorrowSpeeds(cToken);
            }
        }

        return (allMarkets, distributors, rewardTokens, supplySpeeds, borrowSpeeds);
    }

    /**
     * @notice For each `Comptroller`, returns an array of all markets, an array of all `RewardsDistributor` contracts, an array of reward token addresses for each `RewardsDistributor`, an array of supply speeds for each distributor for each, and their borrow speeds.
     * @param comptrollers The Fuse pool Comptrollers to check.
     */
    function getRewardSpeedsByPools(Comptroller[] memory comptrollers) external view returns (CToken[][] memory, RewardsDistributor[][] memory, address[][] memory, uint256[][][] memory, uint256[][][] memory) {
        CToken[][] memory allMarkets = new CToken[][](comptrollers.length);
        RewardsDistributor[][] memory distributors = new RewardsDistributor[][](comptrollers.length);
        address[][] memory rewardTokens = new address[][](comptrollers.length);
        uint256[][][] memory supplySpeeds = new uint256[][][](comptrollers.length);
        uint256[][][] memory borrowSpeeds = new uint256[][][](comptrollers.length);
        for (uint256 i = 0; i < comptrollers.length; i++) (allMarkets[i], distributors[i], rewardTokens[i], supplySpeeds[i], borrowSpeeds[i]) = getRewardSpeedsByPool(comptrollers[i]);
        return (allMarkets, distributors, rewardTokens, supplySpeeds, borrowSpeeds);
    }

    /**
     * @notice Returns unaccrued rewards by `holder` from `cToken` on `distributor`.
     * @param holder The address to check.
     * @param distributor The RewardsDistributor to check.
     * @param cToken The CToken to check.
     * @return Unaccrued (unclaimed) supply-side rewards and unaccrued (unclaimed) borrow-side rewards.
     */
    function getUnaccruedRewards(address holder, RewardsDistributor distributor, CToken cToken) internal returns (uint256, uint256) {
        // Get unaccrued supply rewards
        uint256 compAccruedPrior = distributor.compAccrued(holder);
        distributor.flywheelPreSupplierAction(address(cToken), holder);
        uint256 supplyRewardsUnaccrued = distributor.compAccrued(holder).sub(compAccruedPrior);

        // Get unaccrued borrow rewards
        compAccruedPrior = distributor.compAccrued(holder);
        distributor.flywheelPreBorrowerAction(address(cToken), holder);
        uint256 borrowRewardsUnaccrued = distributor.compAccrued(holder).sub(compAccruedPrior);

        // Return both
        return (supplyRewardsUnaccrued, borrowRewardsUnaccrued);
    }

    /**
     * @notice Returns all unclaimed rewards accrued by the `holder` on `distributors`.
     * @param holder The address to check.
     * @param distributors The `RewardsDistributor` contracts to check.
     * @return For each of `distributors`: total quantity of unclaimed rewards, array of cTokens, array of unaccrued (unclaimed) supply-side and borrow-side rewards per cToken, and quantity of funds available in the distributor.
     */
    function getUnclaimedRewardsByDistributors(address holder, RewardsDistributor[] memory distributors) external returns (address[] memory, uint256[] memory, CToken[][] memory, uint256[2][][] memory, uint256[] memory) {
        address[] memory rewardTokens = new address[](distributors.length);
        uint256[] memory compUnclaimedTotal = new uint256[](distributors.length);
        CToken[][] memory allMarkets = new CToken[][](distributors.length);
        uint256[2][][] memory rewardsUnaccrued = new uint256[2][][](distributors.length);
        uint256[] memory distributorFunds = new uint256[](distributors.length);

        for (uint256 i = 0; i < distributors.length; i++) {
            RewardsDistributor distributor = distributors[i];
            rewardTokens[i] = distributor.rewardToken();
            allMarkets[i] = distributor.getAllMarkets();
            rewardsUnaccrued[i] = new uint256[2][](allMarkets[i].length);
            for (uint256 j = 0; j < allMarkets[i].length; j++) (rewardsUnaccrued[i][j][0], rewardsUnaccrued[i][j][1]) = getUnaccruedRewards(holder, distributor, allMarkets[i][j]);
            compUnclaimedTotal[i] = distributor.compAccrued(holder);
            distributorFunds[i] = IERC20Upgradeable(rewardTokens[i]).balanceOf(address(distributor));
        }

        return (rewardTokens, compUnclaimedTotal, allMarkets, rewardsUnaccrued, distributorFunds);
    }

    /**
     * @notice Returns arrays of indexes, `Comptroller` proxy contracts, and `RewardsDistributor` contracts for Fuse pools supplied to by `account`.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     */
    function getRewardsDistributorsBySupplier(address supplier) external view returns (uint256[] memory, Comptroller[] memory, RewardsDistributor[][] memory) {
        // Get array length
        FusePoolDirectory.FusePool[] memory pools = directory.getAllPools();
        uint256 arrayLength = 0;

        for (uint256 i = 0; i < pools.length; i++) {
            try Comptroller(pools[i].comptroller).suppliers(supplier) returns (bool isSupplier) {
                if (isSupplier) arrayLength++;
            } catch {}
        }

        // Build array
        uint256[] memory indexes = new uint256[](arrayLength);
        Comptroller[] memory comptrollers = new Comptroller[](arrayLength);
        RewardsDistributor[][] memory distributors = new RewardsDistributor[][](arrayLength);
        uint256 index = 0;

        for (uint256 i = 0; i < pools.length; i++) {
            Comptroller comptroller = Comptroller(pools[i].comptroller);

            try comptroller.suppliers(supplier) returns (bool isSupplier) {
                if (isSupplier) {
                    indexes[index] = i;
                    comptrollers[index] = comptroller;

                    try comptroller.getRewardsDistributors() returns (RewardsDistributor[] memory _distributors) {
                        distributors[index] = _distributors;
                    } catch {}

                    index++;
                }
            } catch {}
        }

        // Return distributors
        return (indexes, comptrollers, distributors);
    }
}
