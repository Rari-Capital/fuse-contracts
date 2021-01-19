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

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "./external/compound/CToken.sol";
import "./external/compound/CErc20.sol";
import "./external/compound/CEther.sol";

import "./external/aave/LendingPool.sol";
import "./external/aave/IFlashLoanReceiver.sol";
import "./external/aave/IWETH.sol";

import "./external/uniswap/IUniswapV2Router02.sol";
import "./external/uniswap/IUniswapV2Callee.sol";
import "./external/uniswap/IUniswapV2Pair.sol";
import "./external/uniswap/UniswapV2Library.sol";

/**
 * @title FusePoolDirectory
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FuseSafeLiquidator safely liquidates unhealthy borrowers (with flashloan support).
 */
contract FuseSafeLiquidator is Initializable, OwnableUpgradeable, IFlashLoanReceiver, IUniswapV2Callee {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev Constructor that initializes the owner to `msg.sender`.
     */
    function initialize(uint16 aaveReferralCode) public initializer {
        __Ownable_init();
        _aaveReferralCode = aaveReferralCode;
    }

    /**
     * @notice Safely liquidate an unhealthy loan (using capital from the sender), confirming that at least `minOutputAmount` in collateral is seized (or outputted by exchange if applicable). 
     * @param borrower The borrower's Ethereum address.
     * @param repayAmount The amount to repay to liquidate the unhealthy loan.
     * @param cErc20 The borrowed cErc20 to repay.
     * @param cTokenCollateral The cToken collateral to be liquidated.
     * @param minOutputAmount The minimum amount of collateral to seize (or the minimum exchange output if applicable) required for execution. Reverts if this condition is not met.
     * @param exchangeSeizedTo If set to an address other than `cTokenCollateral`, exchange seized collateral to this ERC20 token contract address (or the zero address for ETH).
     */
    function safeLiquidate(address borrower, uint256 repayAmount, CErc20 cErc20, CToken cTokenCollateral, uint256 minOutputAmount, address exchangeSeizedTo) external {
        // Transfer tokens in, approve to cErc20, and liquidate borrow
        require(repayAmount > 0, "Repay amount (transaction value) must be greater than 0.");
        IERC20Upgradeable underlying = IERC20Upgradeable(cErc20.underlying());
        underlying.safeTransferFrom(msg.sender, address(this), repayAmount);
        uint256 allowance = underlying.allowance(address(this), address(cErc20));

        if (allowance < repayAmount) {
            if (repayAmount > 0 && allowance > 0) underlying.safeApprove(address(cErc20), 0);
            underlying.safeApprove(address(cErc20), uint256(-1));
        }

        cErc20.liquidateBorrow(borrower, repayAmount, cTokenCollateral);

        // Redeem and exchange seized collateral if necessary
        if (exchangeSeizedTo != address(cTokenCollateral)) {
            uint256 seizedCTokenAmount = cTokenCollateral.balanceOf(address(this));

            if (seizedCTokenAmount > 0) {
                uint256 redeemResult = cTokenCollateral.redeem(seizedCTokenAmount);
                require(redeemResult == 0, "Error calling redeeming seized cToken: error code not equal to 0");

                if (exchangeSeizedTo == address(0)) {
                    if (!cTokenCollateral.isCEther()) {
                        address underlyingCollateral = CErc20(address(cTokenCollateral)).underlying();
                        UNISWAP_V2_ROUTER_02.swapExactTokensForETH(IERC20Upgradeable(underlyingCollateral).balanceOf(address(this)), minOutputAmount, array(underlyingCollateral, UNISWAP_V2_ROUTER_02.WETH()), address(this), block.timestamp);
                    }
                } else {
                    if (cTokenCollateral.isCEther()) UNISWAP_V2_ROUTER_02.swapExactETHForTokens.value(address(this).balance)(minOutputAmount, array(UNISWAP_V2_ROUTER_02.WETH(), exchangeSeizedTo), address(this), block.timestamp);
                    else {
                        address underlyingCollateral = CErc20(address(cTokenCollateral)).underlying();
                        if (exchangeSeizedTo != underlyingCollateral) UNISWAP_V2_ROUTER_02.swapExactTokensForTokens(IERC20Upgradeable(underlyingCollateral).balanceOf(address(this)), minOutputAmount, array(underlyingCollateral, exchangeSeizedTo), address(this), block.timestamp);
                    }
                }
            }
        }

        // Transfer seized amount to sender
        transferSeizedFunds(exchangeSeizedTo, minOutputAmount);
    }

    /**
     * @notice Safely liquidate an unhealthy loan (using capital from the sender), confirming that at least `minOutputAmount` in collateral is seized (or outputted by exchange if applicable). 
     * @param borrower The borrower's Ethereum address.
     * @param cEther The borrowed cEther contract to repay.
     * @param cErc20Collateral The cErc20 collateral contract to be liquidated.
     * @param minOutputAmount The minimum amount of collateral to seize (or the minimum exchange output if applicable) required for execution. Reverts if this condition is not met.
     * @param exchangeSeizedTo If set to an address other than `cTokenCollateral`, exchange seized collateral to this ERC20 token contract address (or the zero address for ETH).
     */
    function safeLiquidate(address borrower, CEther cEther, CErc20 cErc20Collateral, uint256 minOutputAmount, address exchangeSeizedTo) external payable {
        require(msg.value > 0, "Repay amount (transaction value) must be greater than 0.");
        cEther.liquidateBorrow.value(msg.value)(borrower, CToken(cErc20Collateral));

        // Redeem and exchange seized collateral if necessary
        if (exchangeSeizedTo != address(cErc20Collateral)) {
            uint256 seizedCTokenAmount = cErc20Collateral.balanceOf(address(this));

            if (seizedCTokenAmount > 0) {
                uint256 redeemResult = cErc20Collateral.redeem(seizedCTokenAmount);
                require(redeemResult == 0, "Error calling redeeming seized cToken: error code not equal to 0");
                address underlyingCollateral = cErc20Collateral.underlying();

                if (exchangeSeizedTo != underlyingCollateral) {
                    if (exchangeSeizedTo == address(0)) UNISWAP_V2_ROUTER_02.swapExactTokensForETH(IERC20Upgradeable(underlyingCollateral).balanceOf(address(this)), minOutputAmount, array(underlyingCollateral, UNISWAP_V2_ROUTER_02.WETH()), address(this), block.timestamp);
                    else UNISWAP_V2_ROUTER_02.swapExactTokensForTokens(IERC20Upgradeable(underlyingCollateral).balanceOf(address(this)), minOutputAmount, array(underlyingCollateral, exchangeSeizedTo), address(this), block.timestamp);
                }
            }
        }

        // Transfer seized amount to sender
        transferSeizedFunds(exchangeSeizedTo, minOutputAmount);
    }

    /**
     * @dev Transfers seized funds to the sender.
     * @param exchangeSeizedTo The address of the token to transfer.
     * @param minOutputAmount The minimum amount to transfer.
     */
    function transferSeizedFunds(address exchangeSeizedTo, uint256 minOutputAmount) internal {
        // Transfer seized amount to sender
        if (exchangeSeizedTo == address(0)) {
            uint256 seizedOutputAmount = address(this).balance;
            require(seizedOutputAmount >= minOutputAmount, "Minimum ETH output amount not satisfied.");

            if (seizedOutputAmount > 0) {
                (bool success, ) = msg.sender.call.value(seizedOutputAmount)("");
                require(success, "Failed to transfer ETH to msg.sender after liquidation.");
            }
        } else {
            IERC20Upgradeable exchangeSeizedToToken = IERC20Upgradeable(exchangeSeizedTo);
            uint256 seizedOutputAmount = exchangeSeizedToToken.balanceOf(address(this));
            require(seizedOutputAmount >= minOutputAmount, "Minimum token output amount not satified.");
            if (seizedOutputAmount > 0) exchangeSeizedToToken.safeTransfer(msg.sender, seizedOutputAmount);
        }
    }

    /**
     * @dev Aave LendingPool contract address.
     */
    address constant private LENDING_POOL_ADDRESS = 0x398eC7346DcD622eDc5ae82352F02bE94C62d119;

    /**
     * @dev Aave LendingPool contract object.
     */
    LendingPool constant private LENDING_POOL = LendingPool(LENDING_POOL_ADDRESS);

    /**
     * @dev WETH contract address.
     */
    address constant private WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @dev WETH contract object.
     */
    IWETH constant private WETH = IWETH(WETH_ADDRESS);

    /**
     * @dev Referral code for Aave flashloans.
     */
    uint16 _aaveReferralCode;

    /**
     * @dev Sets the referral code for Aave flashloans.
     * @param referralCode The referral code.
     */
    function setAaveReferralCode(uint16 referralCode) external onlyOwner {
        _aaveReferralCode = referralCode;
    }

    /**
     * @dev UniswapV2Router02 contract address.
     */
    address constant private UNISWAP_V2_ROUTER_02_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    /**
     * @dev UniswapV2Router02 contract object.
     */
    IUniswapV2Router02 constant private UNISWAP_V2_ROUTER_02 = IUniswapV2Router02(UNISWAP_V2_ROUTER_02_ADDRESS);

    /**
     * @dev UniswapV2Factory contract address.
     */
    address constant private UNISWAP_V2_FACTORY_ADDRESS = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    /**
     * @dev Flash loan providers.
     */
    enum FlashLoanProvider {
        Aave,
        Uniswap
    }

    /**
     * @notice Safely liquidate an unhealthy loan, confirming that at least `minProfitAmount` in ETH profit is seized. 
     * @param borrower The borrower's Ethereum address.
     * @param repayAmount The amount to repay to liquidate the unhealthy loan.
     * @param cErc20 The borrowed CErc20 contract to repay.
     * @param cTokenCollateral The cToken collateral contract to be liquidated.
     * @param minProfitAmount The minimum amount of profit required for execution (in terms of `exchangeProfitTo`). Reverts if this condition is not met.
     * @param exchangeProfitTo If set to an address other than `cTokenCollateral`, exchange seized collateral to this ERC20 token contract address (or the zero address for ETH).
     * @param flashLoanProvider The flashloan provider.
     */
    function safeLiquidateToTokensWithFlashLoan(address borrower, uint256 repayAmount, CErc20 cErc20, CToken cTokenCollateral, uint256 minProfitAmount, address exchangeProfitTo, FlashLoanProvider flashLoanProvider) external {
        require(repayAmount > 0, "Repay amount must be greater than 0.");
        address underlyingBorrow = cErc20.underlying();
        if (flashLoanProvider == FlashLoanProvider.Aave) LENDING_POOL.flashLoan(address(this), array(underlyingBorrow), array(repayAmount), array(0), address(0), msg.data, _aaveReferralCode);
        else if (flashLoanProvider == FlashLoanProvider.Uniswap) {
            IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(UNISWAP_V2_FACTORY_ADDRESS, underlyingBorrow, WETH_ADDRESS));
            address token0 = pair.token0();
            pair.swap(token0 == underlyingBorrow ? repayAmount : 0, token0 != underlyingBorrow ? repayAmount : 0, address(this), msg.data);
        }
        else revert("Invalid flashloan provider.");
    }

    /**
     * @notice Safely liquidate an unhealthy loan, confirming that at least `minProfitAmount` in ETH profit is seized. 
     * @param borrower The borrower's Ethereum address.
     * @param repayAmount The ETH amount to repay to liquidate the unhealthy loan.
     * @param cEther The borrowed CEther contract to repay.
     * @param cErc20Collateral The CErc20 collateral contract to be liquidated.
     * @param minProfitAmount The minimum amount of profit required for execution (in terms of `exchangeProfitTo`). Reverts if this condition is not met.
     * @param exchangeProfitTo If set to an address other than `cErc20Collateral`, exchange seized collateral to this ERC20 token contract address (or the zero address for ETH).
     * @param flashLoanProvider The flashloan provider.
     */
    function safeLiquidateToEthWithFlashLoan(address borrower, uint256 repayAmount, CEther cEther, CErc20 cErc20Collateral, uint256 minProfitAmount, address exchangeProfitTo, FlashLoanProvider flashLoanProvider) external {
        require(repayAmount > 0, "Repay amount must be greater than 0.");
        if (flashLoanProvider == FlashLoanProvider.Aave) LENDING_POOL.flashLoan(address(this), array(WETH_ADDRESS), array(repayAmount), array(0), address(0), msg.data, _aaveReferralCode);
        else if (flashLoanProvider == FlashLoanProvider.Uniswap) {
            IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(UNISWAP_V2_FACTORY_ADDRESS, cErc20Collateral.underlying(), WETH_ADDRESS));
            address token0 = pair.token0();
            pair.swap(token0 == WETH_ADDRESS ? repayAmount : 0, token0 != WETH_ADDRESS ? repayAmount : 0, address(this), msg.data);
        }
        else revert("Invalid flashloan provider.");
    }

    /**
     * @dev Receives ETH from liquidations and flashloans.
     */
    receive() external payable { }

    /**
     * @dev Callback function for Aave flashloans.
     */
    function executeOperation(address[] calldata assets, uint256[] calldata amounts, uint256[] calldata premiums, address initiator, bytes calldata params) external override returns (bool) {
        require(msg.sender == LENDING_POOL_ADDRESS);
        require(initiator == address(this));
        postFlashLoan(params);
        return true;
    }

    /**
     * @dev Callback function for Uniswap flashloans.
     */
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external override {
        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();
        require(msg.sender == UniswapV2Library.pairFor(UNISWAP_V2_FACTORY_ADDRESS, token0, token1));
        require(sender == address(this));
        postFlashLoan(data);
    }

    /**
     * @dev Internal callback function for all flashloans.
     */
    function postFlashLoan(bytes calldata params) private {
        // Decode params
        (address borrower, uint256 repayAmount, address cToken, address cTokenCollateral, uint256 minProfitAmount, address exchangeProfitTo, FlashLoanProvider flashLoanProvider) = abi.decode(params[4:], (address, uint256, address, address, uint256, address, FlashLoanProvider));

        // Calculate flashloan return amount
        uint256 flashLoanReturnAmount;

        if (flashLoanProvider == FlashLoanProvider.Uniswap) {
            flashLoanReturnAmount = repayAmount.mul(1000).div(997);
            if (repayAmount.mul(1000).mod(997) > 0) flashLoanReturnAmount++; // Round up if division resulted in a remainder
        } else flashLoanReturnAmount = repayAmount.add(repayAmount.mul(35).div(10000));

        // Liquidate unhealthy borrow, exchange seized collateral, return flashloaned funds, and exchange profit
        if (CToken(cToken).isCEther()) postFlashLoanWeth(borrower, repayAmount, CEther(cToken), CErc20(cTokenCollateral), minProfitAmount, exchangeProfitTo, flashLoanReturnAmount);
        else postFlashLoanTokens(borrower, repayAmount, CErc20(cToken), CToken(cTokenCollateral), minProfitAmount, exchangeProfitTo, flashLoanReturnAmount);

        // Transfer profit to msg.sender
        if (exchangeProfitTo == address(0)) {
            uint256 profit = address(this).balance;
            require(profit >= minProfitAmount, "Minimum profit amount condition not satisfied.");

            if (profit > 0) {
                (bool success, ) = msg.sender.call.value(profit)("");
                require(success, "Failed to transfer profited ETH to msg.sender after liquidation.");
            }
        } else {
            IERC20Upgradeable exchangeProfitToToken = IERC20Upgradeable(exchangeProfitTo);
            uint256 profit = exchangeProfitToToken.balanceOf(address(this));
            require(profit >= minProfitAmount, "Minimum profit amount condition not satisfied.");
            if (profit > 0) exchangeProfitToToken.safeTransfer(msg.sender, profit);
        }
    }

    /**
     * @dev Liquidate unhealthy ETH borrow, exchange seized collateral, return flashloaned funds, and exchange profit.
     */
    function postFlashLoanWeth(address borrower, uint256 repayAmount, CEther cEther, CErc20 cErc20Collateral, uint256 minProfitAmount, address exchangeProfitTo, uint256 flashLoanReturnAmount) private {
        // Unwrap WETH
        WETH.withdraw(repayAmount);

        // Liquidate ETH borrow using flashloaned ETH
        cEther.liquidateBorrow.value(repayAmount)(borrower, CToken(cErc20Collateral));

        // Redeem seized cTokens for underlying asset
        uint256 seizedCTokenAmount = cErc20Collateral.balanceOf(address(this));
        require(seizedCTokenAmount > 0, "No cTokens seized.");
        uint256 redeemResult = cErc20Collateral.redeem(seizedCTokenAmount);
        require(redeemResult == 0, "Error calling redeeming seized cToken: error code not equal to 0");

        // Check underlying collateral seized
        IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(cErc20Collateral.underlying());
        uint256 underlyingCollateralSeized = underlyingCollateral.balanceOf(address(this));

        // Approve to Uniswap router
        uint256 allowance = underlyingCollateral.allowance(address(this), UNISWAP_V2_ROUTER_02_ADDRESS);

        if (allowance < underlyingCollateralSeized) {
            if (underlyingCollateralSeized > 0 && allowance > 0) underlyingCollateral.safeApprove(UNISWAP_V2_ROUTER_02_ADDRESS, 0);
            underlyingCollateral.safeApprove(UNISWAP_V2_ROUTER_02_ADDRESS, uint256(-1));
        }

        // Swap collateral tokens for ETH via Uniswap router
        if (exchangeProfitTo == address(underlyingCollateral)) UNISWAP_V2_ROUTER_02.swapTokensForExactETH(flashLoanReturnAmount, underlyingCollateralSeized, array(address(underlyingCollateral), UNISWAP_V2_ROUTER_02.WETH()), address(this), block.timestamp);
        else UNISWAP_V2_ROUTER_02.swapExactTokensForETH(underlyingCollateralSeized, flashLoanReturnAmount, array(address(underlyingCollateral), UNISWAP_V2_ROUTER_02.WETH()), address(this), block.timestamp);

        // Repay flashloan
        require(flashLoanReturnAmount <= address(this).balance, "Flashloan return amount greater than ETH exchanged from seized collateral.");
        WETH.deposit.value(flashLoanReturnAmount)();
        require(WETH.transfer(msg.sender, flashLoanReturnAmount), "Failed to transfer WETH back to flashlender.");

        // Exchange profit if necessary
        if (exchangeProfitTo != address(0) && exchangeProfitTo != address(underlyingCollateral)) UNISWAP_V2_ROUTER_02.swapExactETHForTokens.value(address(this).balance)(minProfitAmount, array(UNISWAP_V2_ROUTER_02.WETH(), exchangeProfitTo), address(this), block.timestamp);
    }

    /**
     * @dev Liquidate unhealthy token borrow, exchange seized collateral, return flashloaned funds, and exchange profit.
     */
    function postFlashLoanTokens(address borrower, uint256 repayAmount, CErc20 cErc20, CToken cTokenCollateral, uint256 minProfitAmount, address exchangeProfitTo, uint256 flashLoanReturnAmount) private {
        // Approve repayAmount to cErc20
        IERC20Upgradeable underlyingBorrow = IERC20Upgradeable(cErc20.underlying());
        uint256 allowance = underlyingBorrow.allowance(address(this), address(cErc20));

        if (allowance < repayAmount) {
            if (repayAmount > 0 && allowance > 0) underlyingBorrow.safeApprove(address(cErc20), 0);
            underlyingBorrow.safeApprove(address(cErc20), uint256(-1));
        }

        // Liquidate ETH borrow using flashloaned ETH
        cErc20.liquidateBorrow(borrower, repayAmount, cTokenCollateral);

        // Redeem seized cTokens for underlying asset
        uint256 seizedCTokenAmount = cTokenCollateral.balanceOf(address(this));
        require(seizedCTokenAmount > 0, "No cTokens seized.");
        uint256 redeemResult = cTokenCollateral.redeem(seizedCTokenAmount);
        require(redeemResult == 0, "Error calling redeeming seized cToken: error code not equal to 0");

        // Swap cTokenCollateral for cErc20 via Uniswap
        if (cTokenCollateral.isCEther()) {
            // Swap collateral ETH for tokens via Uniswap router
            uint256 underlyingCollateralSeized = address(this).balance;
            if (exchangeProfitTo == address(underlyingBorrow)) UNISWAP_V2_ROUTER_02.swapExactETHForTokens.value(underlyingCollateralSeized)(flashLoanReturnAmount.add(minProfitAmount), array(UNISWAP_V2_ROUTER_02.WETH(), address(underlyingBorrow)), address(this), block.timestamp);
            else UNISWAP_V2_ROUTER_02.swapETHForExactTokens.value(underlyingCollateralSeized)(flashLoanReturnAmount, array(UNISWAP_V2_ROUTER_02.WETH(), address(underlyingBorrow)), address(this), block.timestamp);
        } else {
            // Check underlying collateral seized
            IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(CErc20(address(cTokenCollateral)).underlying());
            uint256 underlyingCollateralSeized = underlyingCollateral.balanceOf(address(this));

            // Approve to Uniswap router
            allowance = underlyingCollateral.allowance(address(this), UNISWAP_V2_ROUTER_02_ADDRESS);

            if (allowance < underlyingCollateralSeized) {
                if (underlyingCollateralSeized > 0 && allowance > 0) underlyingCollateral.safeApprove(UNISWAP_V2_ROUTER_02_ADDRESS, 0);
                underlyingCollateral.safeApprove(UNISWAP_V2_ROUTER_02_ADDRESS, uint256(-1));
            }

            // Swap collateral tokens for tokens via Uniswap router
            if (exchangeProfitTo == address(underlyingBorrow)) UNISWAP_V2_ROUTER_02.swapExactTokensForTokens(underlyingCollateralSeized, flashLoanReturnAmount.add(minProfitAmount), array(address(underlyingCollateral), address(underlyingBorrow)), address(this), block.timestamp);
            else UNISWAP_V2_ROUTER_02.swapTokensForExactTokens(flashLoanReturnAmount, underlyingCollateralSeized, array(address(underlyingCollateral), address(underlyingBorrow)), address(this), block.timestamp);
        }

        // Repay flashloan
        require(repayAmount <= underlyingBorrow.balanceOf(address(this)), "Repay amount greater than ETH exchanged from seized collateral.");
        underlyingBorrow.safeTransfer(msg.sender, repayAmount);

        // Exchange profit if necessary
        if (exchangeProfitTo != address(underlyingBorrow)) {
            if (exchangeProfitTo == address(0)) {
                if (!cTokenCollateral.isCEther()) {
                    address underlyingCollateral = CErc20(address(cTokenCollateral)).underlying();
                    UNISWAP_V2_ROUTER_02.swapExactTokensForETH(IERC20Upgradeable(underlyingCollateral).balanceOf(address(this)), minProfitAmount, array(underlyingCollateral, UNISWAP_V2_ROUTER_02.WETH()), address(this), block.timestamp);
                }
            } else {
                if (cTokenCollateral.isCEther()) UNISWAP_V2_ROUTER_02.swapExactETHForTokens.value(address(this).balance)(minProfitAmount, array(UNISWAP_V2_ROUTER_02.WETH(), exchangeProfitTo), address(this), block.timestamp);
                else {
                    address underlyingCollateral = CErc20(address(cTokenCollateral)).underlying();
                    if (exchangeProfitTo != underlyingCollateral) UNISWAP_V2_ROUTER_02.swapExactTokensForTokens(IERC20Upgradeable(underlyingCollateral).balanceOf(address(this)), minProfitAmount, array(underlyingCollateral, exchangeProfitTo), address(this), block.timestamp);
                }
            }
        }
    }

    /**
     * @dev Returns an array containing the parameters supplied.
     */
    function array(uint256 a) private pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](1);
        arr[0] = a;
        return arr;
    }

    /**
     * @dev Returns an array containing the parameters supplied.
     */
    function array(address a) private pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = a;
        return arr;
    }

    /**
     * @dev Returns an array containing the parameters supplied.
     */
    function array(address a, address b) private pure returns (address[] memory) {
        address[] memory arr = new address[](2);
        arr[0] = a;
        arr[1] = b;
        return arr;
    }
}
