// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "./liquidators/IRedemptionStrategy.sol";

import "./external/compound/CToken.sol";
import "./external/compound/CErc20.sol";
import "./external/compound/CEther.sol";

import "./external/aave/IWETH.sol";

import "./external/uniswap/IUniswapV2Router02.sol";
import "./external/uniswap/IUniswapV2Callee.sol";
import "./external/uniswap/IUniswapV2Pair.sol";
import "./external/uniswap/IUniswapV2Factory.sol";
import "./external/uniswap/UniswapV2Library.sol";

/**
 * @title FuseSafeLiquidator
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FuseSafeLiquidator safely liquidates unhealthy borrowers (with flashloan support).
 * @dev Do not transfer ETH or tokens directly to this address. Only send ETH here when using a method, and only approve tokens for transfer to here when using a method. Direct ETH transfers will be rejected and direct token transfers will be lost.
 */
contract FuseSafeLiquidator is Initializable, IUniswapV2Callee {
    using SafeMathUpgradeable for uint256;
    using AddressUpgradeable for address payable;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev Internal function to approve unlimited tokens of `erc20Contract` to `to`.
     */
    function safeApprove(IERC20Upgradeable token, address to, uint256 minAmount) private {
        uint256 allowance = token.allowance(address(this), to);

        if (allowance < minAmount) {
            if (allowance > 0) token.safeApprove(to, 0);
            token.safeApprove(to, uint256(-1));
        }
    }

    /**
     * @dev Internal function to exchange the entire balance of `from` to at least `minOutputAmount` of `to`.
     * @param from The input ERC20 token address (or the zero address if ETH) to exchange from.
     * @param to The output ERC20 token address (or the zero address if ETH) to exchange to.
     * @param minOutputAmount The minimum output amount of `to` necessary to complete the exchange without reversion.
     * @param uniswapV2Router The UniswapV2Router02 to use.
     */
    function exchangeAllEthOrTokens(address from, address to, uint256 minOutputAmount, IUniswapV2Router02 uniswapV2Router) private {
        if (to == from) return;

        // From ETH, WETH, or something else?
        if (from == address(0)) {
            if (to == WETH_ADDRESS) {
                // Deposit all ETH to WETH
                WETH.deposit{value: address(this).balance}();
            } else {
                // Exchange from ETH to tokens
                uniswapV2Router.swapExactETHForTokens{value: address(this).balance}(minOutputAmount, array(WETH_ADDRESS, to), address(this), block.timestamp);
            }
        } else if (from == WETH_ADDRESS && to == address(0)) {
            // Withdraw all WETH to ETH
            WETH.withdraw(IERC20Upgradeable(WETH_ADDRESS).balanceOf(address(this)));
        } else {
            // Approve input tokens
            IERC20Upgradeable fromToken = IERC20Upgradeable(from);
            uint256 inputBalance = fromToken.balanceOf(address(this));
            safeApprove(fromToken, address(uniswapV2Router), inputBalance);

            // Exchange from tokens to ETH or tokens
            if (to == address(0)) uniswapV2Router.swapExactTokensForETH(inputBalance, minOutputAmount, array(from, WETH_ADDRESS), address(this), block.timestamp);
            else uniswapV2Router.swapExactTokensForTokens(inputBalance, minOutputAmount, from == WETH_ADDRESS || to == WETH_ADDRESS ? array(from, to) : array(from, WETH_ADDRESS, to), address(this), block.timestamp); // Put WETH in the middle of the path if not already a part of the path
        }
    }

    /**
     * @dev Internal function to exchange the entire balance of `from` to at least `minOutputAmount` of `to`.
     * @param from The input ERC20 token address (or the zero address if ETH) to exchange from.
     * @param outputAmount The output amount of ETH.
     * @param uniswapV2Router The UniswapV2Router02 to use.
     */
    function exchangeToExactEth(address from, uint256 outputAmount, IUniswapV2Router02 uniswapV2Router) private {
        if (from == address(0)) return;

        // From WETH something else?
        if (from == WETH_ADDRESS) {
            // Withdraw WETH to ETH
            WETH.withdraw(outputAmount);
        } else {
            // Approve input tokens
            IERC20Upgradeable fromToken = IERC20Upgradeable(from);
            uint256 inputBalance = fromToken.balanceOf(address(this));
            safeApprove(fromToken, address(uniswapV2Router), inputBalance);

            // Exchange from tokens to ETH
            uniswapV2Router.swapTokensForExactETH(outputAmount, inputBalance, array(from, WETH_ADDRESS), address(this), block.timestamp);
        }
    }

    /**
     * @notice Safely liquidate an unhealthy loan (using capital from the sender), confirming that at least `minOutputAmount` in collateral is seized (or outputted by exchange if applicable). 
     * @param borrower The borrower's Ethereum address.
     * @param repayAmount The amount to repay to liquidate the unhealthy loan.
     * @param cErc20 The borrowed cErc20 to repay.
     * @param cTokenCollateral The cToken collateral to be liquidated.
     * @param minOutputAmount The minimum amount of collateral to seize (or the minimum exchange output if applicable) required for execution. Reverts if this condition is not met.
     * @param exchangeSeizedTo If set to an address other than `cTokenCollateral`, exchange seized collateral to this ERC20 token contract address (or the zero address for ETH).
     * @param uniswapV2Router The UniswapV2Router to use to convert the seized underlying collateral.
     * @param redemptionStrategies The IRedemptionStrategy contracts to use, if any, to redeem "special" collateral tokens (before swapping the output for borrowed tokens to be repaid via Uniswap).
     * @param strategyData The data for the chosen IRedemptionStrategy contracts, if any.
     */
    function safeLiquidate(address borrower, uint256 repayAmount, CErc20 cErc20, CToken cTokenCollateral, uint256 minOutputAmount, address exchangeSeizedTo, IUniswapV2Router02 uniswapV2Router, IRedemptionStrategy[] memory redemptionStrategies, bytes[] memory strategyData) external returns (uint256) {
        // Transfer tokens in, approve to cErc20, and liquidate borrow
        require(repayAmount > 0, "Repay amount (transaction value) must be greater than 0.");
        IERC20Upgradeable underlying = IERC20Upgradeable(cErc20.underlying());
        underlying.safeTransferFrom(msg.sender, address(this), repayAmount);
        safeApprove(underlying, address(cErc20), repayAmount);
        require(cErc20.liquidateBorrow(borrower, repayAmount, cTokenCollateral) == 0, "Liquidation failed.");

        // Redeem seized cToken collateral if necessary
        if (exchangeSeizedTo != address(cTokenCollateral)) {
            uint256 seizedCTokenAmount = cTokenCollateral.balanceOf(address(this));

            if (seizedCTokenAmount > 0) {
                uint256 redeemResult = cTokenCollateral.redeem(seizedCTokenAmount);
                require(redeemResult == 0, "Error calling redeeming seized cToken: error code not equal to 0");

                // If cTokenCollateral is CEther
                if (cTokenCollateral.isCEther()) {
                    // Exchange redeemed ETH collateral if necessary
                    exchangeAllEthOrTokens(address(0), exchangeSeizedTo, minOutputAmount, uniswapV2Router);
                } else {
                    // Redeem custom collateral if liquidation strategy is set
                    IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(CErc20(address(cTokenCollateral)).underlying());

                    if (redemptionStrategies.length > 0) {
                        require(redemptionStrategies.length == strategyData.length, "IRedemptionStrategy contract array and strategy data bytes array mnust the the same length.");
                        uint256 underlyingCollateralSeized = underlyingCollateral.balanceOf(address(this));
                        for (uint256 i = 0; i < redemptionStrategies.length; i++) (underlyingCollateral, underlyingCollateralSeized) = redeemCustomCollateral(underlyingCollateral, underlyingCollateralSeized, redemptionStrategies[i], strategyData[i]);
                    }

                    // Exchange redeemed token collateral if necessary
                    exchangeAllEthOrTokens(address(underlyingCollateral), exchangeSeizedTo, minOutputAmount, uniswapV2Router);
                }
            }
        }

        // Transfer seized amount to sender
        return transferSeizedFunds(exchangeSeizedTo, minOutputAmount);
    }

    /**
     * @notice Safely liquidate an unhealthy loan (using capital from the sender), confirming that at least `minOutputAmount` in collateral is seized (or outputted by exchange if applicable). 
     * @param borrower The borrower's Ethereum address.
     * @param cEther The borrowed cEther contract to repay.
     * @param cErc20Collateral The cErc20 collateral contract to be liquidated.
     * @param minOutputAmount The minimum amount of collateral to seize (or the minimum exchange output if applicable) required for execution. Reverts if this condition is not met.
     * @param exchangeSeizedTo If set to an address other than `cTokenCollateral`, exchange seized collateral to this ERC20 token contract address (or the zero address for ETH).
     * @param uniswapV2Router The UniswapV2Router to use to convert the seized underlying collateral.
     * @param redemptionStrategies The IRedemptionStrategy contracts to use, if any, to redeem "special" collateral tokens (before swapping the output for borrowed tokens to be repaid via Uniswap).
     * @param strategyData The data for the chosen IRedemptionStrategy contracts, if any.
     */
    function safeLiquidate(address borrower, CEther cEther, CErc20 cErc20Collateral, uint256 minOutputAmount, address exchangeSeizedTo, IUniswapV2Router02 uniswapV2Router, IRedemptionStrategy[] memory redemptionStrategies, bytes[] memory strategyData) external payable returns (uint256) {
        // Liquidate ETH borrow
        require(msg.value > 0, "Repay amount (transaction value) must be greater than 0.");
        cEther.liquidateBorrow{value: msg.value}(borrower, CToken(cErc20Collateral));

        // Redeem seized cToken collateral if necessary
        if (exchangeSeizedTo != address(cErc20Collateral)) {
            uint256 seizedCTokenAmount = cErc20Collateral.balanceOf(address(this));

            if (seizedCTokenAmount > 0) {
                uint256 redeemResult = cErc20Collateral.redeem(seizedCTokenAmount);
                require(redeemResult == 0, "Error calling redeeming seized cToken: error code not equal to 0");

                // Redeem custom collateral if liquidation strategy is set
                IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(cErc20Collateral.underlying());

                if (redemptionStrategies.length > 0) {
                    require(redemptionStrategies.length == strategyData.length, "IRedemptionStrategy contract array and strategy data bytes array mnust the the same length.");
                    uint256 underlyingCollateralSeized = underlyingCollateral.balanceOf(address(this));
                    for (uint256 i = 0; i < redemptionStrategies.length; i++) (underlyingCollateral, underlyingCollateralSeized) = this.redeemCustomCollateral(underlyingCollateral, underlyingCollateralSeized, redemptionStrategies[i], strategyData[i]); // redeemCustomCollateral called externally because this safeLiquidate function is payable (for some reason delegatecall fails when called with msg.value > 0)
                }

                // Exchange redeemed collateral if necessary
                exchangeAllEthOrTokens(address(underlyingCollateral), exchangeSeizedTo, minOutputAmount, uniswapV2Router);
            }
        }

        // Transfer seized amount to sender
        return transferSeizedFunds(exchangeSeizedTo, minOutputAmount);
    }

    /**
     * @dev Transfers seized funds to the sender.
     * @param erc20Contract The address of the token to transfer.
     * @param minOutputAmount The minimum amount to transfer.
     */
    function transferSeizedFunds(address erc20Contract, uint256 minOutputAmount) internal returns (uint256) {
        uint256 seizedOutputAmount;

        if (erc20Contract == address(0)) {
            seizedOutputAmount = address(this).balance;
            require(seizedOutputAmount >= minOutputAmount, "Minimum ETH output amount not satisfied.");

            if (seizedOutputAmount > 0) {
                (bool success, ) = msg.sender.call{value: seizedOutputAmount}("");
                require(success, "Failed to transfer output ETH to msg.sender.");
            }
        } else {
            IERC20Upgradeable token = IERC20Upgradeable(erc20Contract);
            seizedOutputAmount = token.balanceOf(address(this));
            require(seizedOutputAmount >= minOutputAmount, "Minimum token output amount not satified.");
            if (seizedOutputAmount > 0) token.safeTransfer(msg.sender, seizedOutputAmount);
        }

        return seizedOutputAmount;
    }

    /**
     * @dev WETH contract address.
     */
    address internal WETH_ADDRESS;

    /**
     * @dev WETH contract object.
     */
    IWETH internal WETH;

    /**
     * @dev UniswapV2Router02 contract address.
     */
    address internal UNISWAP_V2_ROUTER_02_ADDRESS;

    /**
     * @dev UniswapV2Router02 contract object.
     */
    IUniswapV2Router02 internal UNISWAP_V2_ROUTER_02;

    /**
     * @dev WETH flashloan pair base token #1 (USDC on Ethereum, MIM on Arbitrum).
     */
    address internal WETH_FLASHLOAN_BASE_TOKEN_1;

    /**
     * @dev WETH flashloan pair base token #2 (WBTC on Ethereum, DPX on Arbitrum).
     */
    address internal WETH_FLASHLOAN_BASE_TOKEN_2;

    /**
     * @dev Constructor to set immutable variables.
     */
    constructor() public {
        WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        UNISWAP_V2_ROUTER_02_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; // Uniswap V2 on Ethereum
        UNISWAP_V2_ROUTER_02 = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        WETH_FLASHLOAN_BASE_TOKEN_1 = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC on Ethereum
        WETH_FLASHLOAN_BASE_TOKEN_2 = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // WBTC on Ethereum
    }

    /**
     * @dev Cached liquidator profit exchange source.
     * ERC20 token address or the zero address for ETH.
     * For use in `safeLiquidateToTokensWithFlashLoan`/`safeLiquidateToEthWithFlashLoan` after it is set by `postFlashLoanTokens`/`postFlashLoanWeth`.
     */
    address private _liquidatorProfitExchangeSource;

    /**
     * @notice Safely liquidate an unhealthy loan, confirming that at least `minProfitAmount` in ETH profit is seized. 
     * @param borrower The borrower's Ethereum address.
     * @param repayAmount The amount to repay to liquidate the unhealthy loan.
     * @param cErc20 The borrowed CErc20 contract to repay.
     * @param cTokenCollateral The cToken collateral contract to be liquidated.
     * @param minProfitAmount The minimum amount of profit required for execution (in terms of `exchangeProfitTo`). Reverts if this condition is not met.
     * @param exchangeProfitTo If set to an address other than `cTokenCollateral`, exchange seized collateral to this ERC20 token contract address (or the zero address for ETH).
     * @param uniswapV2RouterForBorrow The UniswapV2Router to use to convert the ETH to the underlying borrow (and flashloan the underlying borrow for ETH).
     * @param uniswapV2RouterForCollateral The UniswapV2Router to use to convert the underlying collateral to ETH.
     * @param redemptionStrategies The IRedemptionStrategy contracts to use, if any, to redeem "special" collateral tokens (before swapping the output for borrowed tokens to be repaid via Uniswap).
     * @param strategyData The data for the chosen IRedemptionStrategy contracts, if any.
     */
    function safeLiquidateToTokensWithFlashLoan(address borrower, uint256 repayAmount, CErc20 cErc20, CToken cTokenCollateral, uint256 minProfitAmount, address exchangeProfitTo, IUniswapV2Router02 uniswapV2RouterForBorrow, IUniswapV2Router02 uniswapV2RouterForCollateral, IRedemptionStrategy[] memory redemptionStrategies, bytes[] memory strategyData, uint256 ethToCoinbase) external returns (uint256) {
        // Input validation
        require(repayAmount > 0, "Repay amount must be greater than 0.");

        // Flashloan via Uniswap (scoping `underlyingBorrow` variable to avoid "stack too deep" compiler error)
        IUniswapV2Pair pair;
        bool token0IsUnderlyingBorrow;
        {
            address underlyingBorrow = cErc20.underlying();
            pair = IUniswapV2Pair(IUniswapV2Factory(uniswapV2RouterForBorrow.factory()).getPair(underlyingBorrow, WETH_ADDRESS));
            token0IsUnderlyingBorrow = pair.token0() == underlyingBorrow;
        }
        pair.swap(token0IsUnderlyingBorrow ? repayAmount : 0, !token0IsUnderlyingBorrow ? repayAmount : 0, address(this), msg.data);

        // Exchange profit, send ETH to coinbase if necessary, and transfer seized funds
        return distributeProfit(exchangeProfitTo, minProfitAmount, ethToCoinbase);
    }

    /**
     * @notice Safely liquidate an unhealthy loan, confirming that at least `minProfitAmount` in ETH profit is seized. 
     * @param borrower The borrower's Ethereum address.
     * @param repayAmount The ETH amount to repay to liquidate the unhealthy loan.
     * @param cEther The borrowed CEther contract to repay.
     * @param cErc20Collateral The CErc20 collateral contract to be liquidated.
     * @param minProfitAmount The minimum amount of profit required for execution (in terms of `exchangeProfitTo`). Reverts if this condition is not met.
     * @param exchangeProfitTo If set to an address other than `cErc20Collateral`, exchange seized collateral to this ERC20 token contract address (or the zero address for ETH).
     * @param uniswapV2RouterForCollateral The UniswapV2Router to use to convert the underlying collateral to ETH.
     * @param redemptionStrategies The IRedemptionStrategy contracts to use, if any, to redeem "special" collateral tokens (before swapping the output for borrowed tokens to be repaid via Uniswap).
     * @param strategyData The data for the chosen IRedemptionStrategy contracts, if any.
     */
    function safeLiquidateToEthWithFlashLoan(address borrower, uint256 repayAmount, CEther cEther, CErc20 cErc20Collateral, uint256 minProfitAmount, address exchangeProfitTo, IUniswapV2Router02 uniswapV2RouterForCollateral, IRedemptionStrategy[] memory redemptionStrategies, bytes[] memory strategyData, uint256 ethToCoinbase) external returns (uint256) {
        // Input validation
        require(repayAmount > 0, "Repay amount must be greater than 0.");

        // Flashloan via Uniswap
        IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(UNISWAP_V2_ROUTER_02.factory(), address(uniswapV2RouterForCollateral) == UNISWAP_V2_ROUTER_02_ADDRESS && cErc20Collateral.underlying() == WETH_FLASHLOAN_BASE_TOKEN_1 ? WETH_FLASHLOAN_BASE_TOKEN_2 : WETH_FLASHLOAN_BASE_TOKEN_1, WETH_ADDRESS)); // Use USDC unless collateral is USDC, in which case we use WBTC to avoid a reentrancy error when exchanging the collateral to repay the borrow
        address token0 = pair.token0();
        pair.swap(token0 == WETH_ADDRESS ? repayAmount : 0, token0 != WETH_ADDRESS ? repayAmount : 0, address(this), msg.data);

        // Exchange profit, send ETH to coinbase if necessary, and transfer seized funds
        return distributeProfit(exchangeProfitTo, minProfitAmount, ethToCoinbase);
    }

    /**
     * Exchange profit, send ETH to coinbase if necessary, and transfer seized funds to sender.
     */
    function distributeProfit(address exchangeProfitTo, uint256 minProfitAmount, uint256 ethToCoinbase) private returns (uint256) {
        if (exchangeProfitTo == address(0)) {
            // Exchange profit if necessary
            exchangeAllEthOrTokens(_liquidatorProfitExchangeSource, exchangeProfitTo, minProfitAmount.add(ethToCoinbase), UNISWAP_V2_ROUTER_02);

            // Transfer ETH to block.coinbase if requested
            if (ethToCoinbase > 0) block.coinbase.call{value: ethToCoinbase}("");

            // Transfer profit to msg.sender
            return transferSeizedFunds(exchangeProfitTo, minProfitAmount);
        } else {
            // Transfer ETH to block.coinbase if requested
            if (ethToCoinbase > 0) {
                exchangeToExactEth(_liquidatorProfitExchangeSource, ethToCoinbase, UNISWAP_V2_ROUTER_02);
                block.coinbase.call{value: ethToCoinbase}("");
            }

            // Exchange profit if necessary
            exchangeAllEthOrTokens(_liquidatorProfitExchangeSource, exchangeProfitTo, minProfitAmount.add(ethToCoinbase), UNISWAP_V2_ROUTER_02);

            // Transfer profit to msg.sender
            return transferSeizedFunds(exchangeProfitTo, minProfitAmount);
        }
    }

    /**
     * @dev Receives ETH from liquidations and flashloans.
     * Requires that `msg.sender` is WETH, a CToken, or a Uniswap V2 Router, or another contract.
     */
    receive() external payable {
        require(msg.sender.isContract(), "Sender is not a contract.");
    }

    /**
     * @dev Callback function for Uniswap flashloans.
     */
    function uniswapV2Call(address sender, uint amount0, uint amount1, bytes calldata data) external override {
        (address cToken) = abi.decode(data[68:100], (address));

        // Liquidate unhealthy borrow, exchange seized collateral, return flashloaned funds, and exchange profit
        if (CToken(cToken).isCEther()) {
            // Decode params
            (address borrower, uint256 repayAmount, , address cTokenCollateral, uint256 minProfitAmount, address exchangeProfitTo, IUniswapV2Router02 uniswapV2Router, address[] memory redemptionStrategies, bytes[] memory strategyData) = abi.decode(data[4:], (address, uint256, address, address, uint256, address, IUniswapV2Router02, address[], bytes[]));

            // Calculate flashloan return amount
            uint256 flashLoanReturnAmount = repayAmount.mul(1000).div(997);
            if (repayAmount.mul(1000).mod(997) > 0) flashLoanReturnAmount++; // Round up if division resulted in a remainder

            // Post WETH flashloan
            // Cache liquidation profit token (or the zero address for ETH) for use as source for exchange later
            _liquidatorProfitExchangeSource = postFlashLoanWeth(borrower, repayAmount, CEther(cToken), CErc20(cTokenCollateral), minProfitAmount, exchangeProfitTo, flashLoanReturnAmount, uniswapV2Router, redemptionStrategies, strategyData);
        }
        else {
            // Decode params
            (address borrower, uint256 repayAmount, , address cTokenCollateral, uint256 minProfitAmount, address exchangeProfitTo, IUniswapV2Router02 uniswapV2RouterForBorrow, IUniswapV2Router02 uniswapV2RouterForCollateral, address[] memory redemptionStrategies, bytes[] memory strategyData) = abi.decode(data[4:], (address, uint256, address, address, uint256, address, IUniswapV2Router02, IUniswapV2Router02, address[], bytes[]));

            // Calculate flashloan return amount
            uint256 flashLoanReturnAmount = repayAmount.mul(1000).div(997);
            if (repayAmount.mul(1000).mod(997) > 0) flashLoanReturnAmount++; // Round up if division resulted in a remainder

            // Post token flashloan
            // Cache liquidation profit token (or the zero address for ETH) for use as source for exchange later
            _liquidatorProfitExchangeSource = postFlashLoanTokens(borrower, repayAmount, CErc20(cToken), CToken(cTokenCollateral), minProfitAmount, exchangeProfitTo, flashLoanReturnAmount, uniswapV2RouterForBorrow, uniswapV2RouterForCollateral, redemptionStrategies, strategyData);
        }
    }

    /**
     * @dev Fetches and sorts the reserves for a pair.
     * Original code from UniswapV2Library.
     */
    function getReserves(address factory, address tokenA, address tokenB) private view returns (uint reserveA, uint reserveB) {
        (address token0, ) = UniswapV2Library.sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1, ) = IUniswapV2Pair(IUniswapV2Factory(factory).getPair(tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @dev Performs chained getAmountIn calculations on any number of pairs.
     * Original code from UniswapV2Library.
     */
    function getAmountsIn(address factory, uint amountOut, address[] memory path) private view returns (uint[] memory amounts) {
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = UniswapV2Library.getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }

    /**
     * @dev Liquidate unhealthy ETH borrow, exchange seized collateral, return flashloaned funds, and exchange profit.
     */
    function postFlashLoanWeth(address borrower, uint256 repayAmount, CEther cEther, CErc20 cErc20Collateral, uint256 minProfitAmount, address exchangeProfitTo, uint256 flashLoanReturnAmount, IUniswapV2Router02 uniswapV2Router, address[] memory redemptionStrategies, bytes[] memory strategyData) private returns (address) {
        // Unwrap WETH
        WETH.withdraw(repayAmount);

        // Liquidate ETH borrow using flashloaned ETH
        cEther.liquidateBorrow{value: repayAmount}(borrower, CToken(cErc20Collateral));

        // Redeem seized cTokens for underlying asset
        uint256 seizedCTokenAmount = cErc20Collateral.balanceOf(address(this));
        require(seizedCTokenAmount > 0, "No cTokens seized.");
        uint256 redeemResult = cErc20Collateral.redeem(seizedCTokenAmount);
        require(redeemResult == 0, "Error calling redeeming seized cToken: error code not equal to 0");

        // Repay flashloan
        return repayWethFlashLoan(repayAmount, cErc20Collateral, exchangeProfitTo, flashLoanReturnAmount, uniswapV2Router, redemptionStrategies, strategyData);
    }

    /**
     * @dev Repays WETH flashloans.
     */
    function repayWethFlashLoan(uint256 repayAmount, CErc20 cErc20Collateral, address exchangeProfitTo, uint256 flashLoanReturnAmount, IUniswapV2Router02 uniswapV2Router, address[] memory redemptionStrategies, bytes[] memory strategyData) private returns (address) {
        // Check underlying collateral seized
        IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(cErc20Collateral.underlying());
        uint256 underlyingCollateralSeized = underlyingCollateral.balanceOf(address(this));

        // Redeem custom collateral if liquidation strategy is set
        if (redemptionStrategies.length > 0) {
            require(redemptionStrategies.length == strategyData.length, "IRedemptionStrategy contract array and strategy data bytes array mnust the the same length.");
            for (uint256 i = 0; i < redemptionStrategies.length; i++) (underlyingCollateral, underlyingCollateralSeized) = redeemCustomCollateral(underlyingCollateral, underlyingCollateralSeized, IRedemptionStrategy(redemptionStrategies[i]), strategyData[i]);
        }

        // Check side of the flashloan to repay: if input token (underlying collateral) is part of flashloan, repay it (to avoid reentracy error); otherwise, convert to WETH and repay WETH
        if (address(uniswapV2Router) == UNISWAP_V2_ROUTER_02_ADDRESS && address(underlyingCollateral) == (cErc20Collateral.underlying() == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 ? 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599 : 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48)) {
            // Get tokens required to repay flashloan and repay flashloan in non-WETH tokens
            uint256 tokensRequired = getAmountsIn(uniswapV2Router.factory(), repayAmount, array(address(underlyingCollateral), WETH_ADDRESS))[0];
            require(tokensRequired <= underlyingCollateralSeized, "Flashloan return amount greater than seized collateral.");
            require(underlyingCollateral.transfer(msg.sender, tokensRequired), "Failed to transfer non-WETH tokens back to flashlender.");
        } else {
            // If underlying collateral is not already WETH, convert it to WETH
            if (address(underlyingCollateral) != WETH_ADDRESS) {
                // If underlying collateral is ETH, deposit to WETH; if token, exchange to WETH
                if (address(underlyingCollateral) == address(0)) {
                    // Deposit ETH to WETH to repay flashloan
                    WETH.deposit{value: flashLoanReturnAmount}();
                } else {
                    // Approve to Uniswap router
                    safeApprove(underlyingCollateral, address(uniswapV2Router), underlyingCollateralSeized);

                    // Swap collateral tokens for WETH via Uniswap router
                    if (exchangeProfitTo == address(underlyingCollateral)) uniswapV2Router.swapTokensForExactTokens(flashLoanReturnAmount, underlyingCollateralSeized, array(address(underlyingCollateral), WETH_ADDRESS), address(this), block.timestamp);
                    else {
                        uniswapV2Router.swapExactTokensForTokens(underlyingCollateralSeized, flashLoanReturnAmount, array(address(underlyingCollateral), WETH_ADDRESS), address(this), block.timestamp);
                        underlyingCollateral = IERC20Upgradeable(WETH_ADDRESS);
                    }
                }
            }

            // Repay flashloan in WETH
            require(flashLoanReturnAmount <= IERC20Upgradeable(WETH_ADDRESS).balanceOf(address(this)), "Flashloan return amount greater than WETH exchanged from seized collateral.");
            require(WETH.transfer(msg.sender, flashLoanReturnAmount), "Failed to transfer WETH back to flashlender.");
        }

        // Return the profited token
        return address(underlyingCollateral);
    }

    /**
     * @dev Liquidate unhealthy token borrow, exchange seized collateral, return flashloaned funds, and exchange profit.
     */
    function postFlashLoanTokens(address borrower, uint256 repayAmount, CErc20 cErc20, CToken cTokenCollateral, uint256 minProfitAmount, address exchangeProfitTo, uint256 flashLoanReturnAmount, IUniswapV2Router02 uniswapV2RouterForBorrow, IUniswapV2Router02 uniswapV2RouterForCollateral, address[] memory redemptionStrategies, bytes[] memory strategyData) private returns (address) {
        // Approve repayAmount to cErc20
        IERC20Upgradeable underlyingBorrow = IERC20Upgradeable(cErc20.underlying());
        safeApprove(underlyingBorrow, address(cErc20), repayAmount);

        // Liquidate ETH borrow using flashloaned ETH
        require(cErc20.liquidateBorrow(borrower, repayAmount, cTokenCollateral) == 0, "Liquidation failed.");

        // Redeem seized cTokens for underlying asset
        uint256 seizedCTokenAmount = cTokenCollateral.balanceOf(address(this));
        require(seizedCTokenAmount > 0, "No cTokens seized.");
        uint256 redeemResult = cTokenCollateral.redeem(seizedCTokenAmount);
        require(redeemResult == 0, "Error calling redeeming seized cToken: error code not equal to 0");

        // Repay flashloan
        return repayTokenFlashLoan(repayAmount, cTokenCollateral, exchangeProfitTo, flashLoanReturnAmount, uniswapV2RouterForBorrow, uniswapV2RouterForCollateral, redemptionStrategies, strategyData, underlyingBorrow);
    }

    /**
     * @dev Repays token flashloans.
     */
    function repayTokenFlashLoan(uint256 repayAmount, CToken cTokenCollateral, address exchangeProfitTo, uint256 flashLoanReturnAmount, IUniswapV2Router02 uniswapV2RouterForBorrow, IUniswapV2Router02 uniswapV2RouterForCollateral, address[] memory redemptionStrategies, bytes[] memory strategyData, IERC20Upgradeable underlyingBorrow) private returns (address) {
        // Swap cTokenCollateral for cErc20 via Uniswap
        if (cTokenCollateral.isCEther()) {
            // Get flashloan repay amount in terms of WETH collateral via Uniswap router
            // uniswapV2RouterForCollateral is ignored because it should be the same as uniswapV2RouterForBorrow
            uint256 underlyingCollateralSeized = address(this).balance;
            uint256 wethRequired = getAmountsIn(uniswapV2RouterForBorrow.factory(), repayAmount, array(WETH_ADDRESS, address(underlyingBorrow)))[0];

            // Repay flashloan
            require(wethRequired <= underlyingCollateralSeized, "Seized ETH collateral not enough to repay flashloan.");
            WETH.deposit{value: wethRequired}();
            require(WETH.transfer(msg.sender, wethRequired), "Failed to repay Uniswap flashloan with WETH exchanged from seized collateral.");

            // Return the profited token (ETH)
            return address(0);
        } else {
            // Check underlying collateral seized
            IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(CErc20(address(cTokenCollateral)).underlying());
            uint256 underlyingCollateralSeized = underlyingCollateral.balanceOf(address(this));

            // Redeem custom collateral if liquidation strategy is set
            if (redemptionStrategies.length > 0) {
                require(redemptionStrategies.length == strategyData.length, "IRedemptionStrategy contract array and strategy data bytes array mnust the the same length.");
                for (uint256 i = 0; i < redemptionStrategies.length; i++) (underlyingCollateral, underlyingCollateralSeized) = redeemCustomCollateral(underlyingCollateral, underlyingCollateralSeized, IRedemptionStrategy(redemptionStrategies[i]), strategyData[i]);
            }

            // Check which side of the flashloan to repay
            if (address(underlyingCollateral) == address(underlyingBorrow)) {
                // Repay flashloan on borrow side with collateral
                require(flashLoanReturnAmount <= underlyingBorrow.balanceOf(address(this)), "Token flashloan return amount greater than tokens exchanged from seized collateral.");
                require(underlyingBorrow.transfer(msg.sender, flashLoanReturnAmount), "Failed to repay token flashloan on borrow (non-WETH) side.");

                // Return the profited token (same as collateral and borrow)
                return address(underlyingCollateral);
            } else {
                // Get WETH required to repay flashloan
                uint256 wethRequired = getAmountsIn(uniswapV2RouterForBorrow.factory(), repayAmount, array(WETH_ADDRESS, address(underlyingBorrow)))[0];

                if (address(underlyingCollateral) != WETH_ADDRESS) {
                    // Approve to Uniswap router
                    safeApprove(underlyingCollateral, address(uniswapV2RouterForCollateral), underlyingCollateralSeized);

                    // Swap collateral tokens for WETH to be repaid via Uniswap router
                    if (exchangeProfitTo == address(underlyingCollateral)) uniswapV2RouterForCollateral.swapTokensForExactTokens(wethRequired, underlyingCollateralSeized, array(address(underlyingCollateral), WETH_ADDRESS), address(this), block.timestamp);
                    else uniswapV2RouterForCollateral.swapExactTokensForTokens(underlyingCollateralSeized, wethRequired, array(address(underlyingCollateral), WETH_ADDRESS), address(this), block.timestamp);
                }

                // Repay flashloan
                require(wethRequired <= IERC20Upgradeable(WETH_ADDRESS).balanceOf(address(this)), "Not enough WETH exchanged from seized collateral to repay flashloan.");
                require(WETH.transfer(msg.sender, wethRequired), "Failed to repay Uniswap flashloan with WETH exchanged from seized collateral.");

                // Return the profited token (underlying collateral if same as exchangeProfitTo; otherwise, WETH)
                return exchangeProfitTo == address(underlyingCollateral) ? address(underlyingCollateral) : WETH_ADDRESS;
            }
        }
    }

    /**
     * @dev Redeem "special" collateral tokens (before swapping the output for borrowed tokens to be repaid via Uniswap).
     * Public visibility because we have to call this function externally if called from a payable FuseSafeLiquidator function (for some reason delegatecall fails when called with msg.value > 0).
     */
    function redeemCustomCollateral(IERC20Upgradeable underlyingCollateral, uint256 underlyingCollateralSeized, IRedemptionStrategy strategy, bytes memory strategyData) public returns (IERC20Upgradeable, uint256) {
        bytes memory returndata = _functionDelegateCall(address(strategy), abi.encodeWithSelector(strategy.redeem.selector, underlyingCollateral, underlyingCollateralSeized, strategyData));
        return abi.decode(returndata, (IERC20Upgradeable, uint256));
    }
    
    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`], but performing a delegate call.
     * Copied from https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/cb4774ace1cb84f2662fa47c573780aab937628b/contracts/utils/MulticallUpgradeable.sol#L37
     */
    function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
        require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");

        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, "Address: low-level delegate call failed");
    }

    /**
     * @dev Used by `_functionDelegateCall` to verify the result of a delegate call.
     * Copied from https://github.com/OpenZeppelin/openzeppelin-contracts-upgradeable/blob/cb4774ace1cb84f2662fa47c573780aab937628b/contracts/utils/MulticallUpgradeable.sol#L45
     */
    function _verifyCallResult(bool success, bytes memory returndata, string memory errorMessage) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
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

    /**
     * @dev Returns an array containing the parameters supplied.
     */
    function array(address a, address b, address c) private pure returns (address[] memory) {
        address[] memory arr = new address[](3);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        return arr;
    }
}
