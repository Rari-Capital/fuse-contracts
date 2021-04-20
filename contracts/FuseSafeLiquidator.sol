// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

import "./external/compound/CToken.sol";
import "./external/compound/CErc20.sol";
import "./external/compound/CEther.sol";

import "./external/aave/IWETH.sol";

import "./external/uniswap/IUniswapV2Router02.sol";
import "./external/uniswap/IUniswapV2Callee.sol";
import "./external/uniswap/IUniswapV2Pair.sol";
import "./external/uniswap/UniswapV2Library.sol";

/**
 * @title FuseSafeLiquidator
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FuseSafeLiquidator safely liquidates unhealthy borrowers (with flashloan support).
 * @dev Do not transfer ETH or tokens directly to this address. Only send ETH here when using a method, and only approve tokens for transfer to here when using a method. Direct ETH transfers will be rejected and direct token transfers will be lost.
 */
contract FuseSafeLiquidator is Initializable, IUniswapV2Callee {
    using SafeMathUpgradeable for uint256;
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
     */
    function exchangeAllEthOrTokens(address from, address to, uint256 minOutputAmount) private {
        if (to == from) return;

        if (from == address(0)) {
            // Exchange from ETH to tokens
            UNISWAP_V2_ROUTER_02.swapExactETHForTokens{value: address(this).balance}(minOutputAmount, array(WETH_ADDRESS, to), address(this), block.timestamp);
        } else {
            // Approve input tokens
            IERC20Upgradeable fromToken = IERC20Upgradeable(from);
            uint256 inputBalance = fromToken.balanceOf(address(this));
            safeApprove(fromToken, UNISWAP_V2_ROUTER_02_ADDRESS, inputBalance);

            // Exchange from tokens to ETH or tokens
            if (to == address(0)) UNISWAP_V2_ROUTER_02.swapExactTokensForETH(inputBalance, minOutputAmount, array(from, WETH_ADDRESS), address(this), block.timestamp);
            else UNISWAP_V2_ROUTER_02.swapExactTokensForTokens(inputBalance, minOutputAmount, from == WETH_ADDRESS || to == WETH_ADDRESS ? array(from, to) : array(from, WETH_ADDRESS, to), address(this), block.timestamp); // Put WETH in the middle of the path if not already a part of the path
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
     */
    function safeLiquidate(address borrower, uint256 repayAmount, CErc20 cErc20, CToken cTokenCollateral, uint256 minOutputAmount, address exchangeSeizedTo) external {
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

                // Exchange redeemed collateral if necessary
                exchangeAllEthOrTokens(cTokenCollateral.isCEther() ? address(0) : CErc20(address(cTokenCollateral)).underlying(), exchangeSeizedTo, minOutputAmount);
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
        // Liquidate ETH borrow
        require(msg.value > 0, "Repay amount (transaction value) must be greater than 0.");
        cEther.liquidateBorrow{value: msg.value}(borrower, CToken(cErc20Collateral));

        // Redeem seized cToken collateral if necessary
        if (exchangeSeizedTo != address(cErc20Collateral)) {
            uint256 seizedCTokenAmount = cErc20Collateral.balanceOf(address(this));

            if (seizedCTokenAmount > 0) {
                uint256 redeemResult = cErc20Collateral.redeem(seizedCTokenAmount);
                require(redeemResult == 0, "Error calling redeeming seized cToken: error code not equal to 0");

                // Exchange redeemed collateral if necessary
                exchangeAllEthOrTokens(cErc20Collateral.underlying(), exchangeSeizedTo, minOutputAmount);
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
                (bool success, ) = msg.sender.call{value: seizedOutputAmount}("");
                require(success, "Failed to transfer output ETH to msg.sender.");
            }
        } else {
            IERC20Upgradeable exchangeSeizedToToken = IERC20Upgradeable(exchangeSeizedTo);
            uint256 seizedOutputAmount = exchangeSeizedToToken.balanceOf(address(this));
            require(seizedOutputAmount >= minOutputAmount, "Minimum token output amount not satified.");
            if (seizedOutputAmount > 0) exchangeSeizedToToken.safeTransfer(msg.sender, seizedOutputAmount);
        }
    }

    /**
     * @dev WETH contract address.
     */
    address constant private WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @dev WETH contract object.
     */
    IWETH constant private WETH = IWETH(WETH_ADDRESS);

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
     * @notice Safely liquidate an unhealthy loan, confirming that at least `minProfitAmount` in ETH profit is seized. 
     * @param borrower The borrower's Ethereum address.
     * @param repayAmount The amount to repay to liquidate the unhealthy loan.
     * @param cErc20 The borrowed CErc20 contract to repay.
     * @param cTokenCollateral The cToken collateral contract to be liquidated.
     * @param minProfitAmount The minimum amount of profit required for execution (in terms of `exchangeProfitTo`). Reverts if this condition is not met.
     * @param exchangeProfitTo If set to an address other than `cTokenCollateral`, exchange seized collateral to this ERC20 token contract address (or the zero address for ETH).
     */
    function safeLiquidateToTokensWithFlashLoan(address borrower, uint256 repayAmount, CErc20 cErc20, CToken cTokenCollateral, uint256 minProfitAmount, address exchangeProfitTo) external {
        // Flashloan via Uniswap
        require(repayAmount > 0, "Repay amount must be greater than 0.");
        address underlyingBorrow = cErc20.underlying();
        IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(UNISWAP_V2_FACTORY_ADDRESS, underlyingBorrow, WETH_ADDRESS));
        address token0 = pair.token0();
        pair.swap(token0 == underlyingBorrow ? repayAmount : 0, token0 != underlyingBorrow ? repayAmount : 0, address(this), msg.data);

        // Exchange profit if necessary
        exchangeAllEthOrTokens(cTokenCollateral.isCEther() ? address(0) : CErc20(address(cTokenCollateral)).underlying(), exchangeProfitTo, minProfitAmount);

        // Transfer profit to msg.sender
        transferSeizedFunds(exchangeProfitTo, minProfitAmount);
    }

    /**
     * @notice Safely liquidate an unhealthy loan, confirming that at least `minProfitAmount` in ETH profit is seized. 
     * @param borrower The borrower's Ethereum address.
     * @param repayAmount The ETH amount to repay to liquidate the unhealthy loan.
     * @param cEther The borrowed CEther contract to repay.
     * @param cErc20Collateral The CErc20 collateral contract to be liquidated.
     * @param minProfitAmount The minimum amount of profit required for execution (in terms of `exchangeProfitTo`). Reverts if this condition is not met.
     * @param exchangeProfitTo If set to an address other than `cErc20Collateral`, exchange seized collateral to this ERC20 token contract address (or the zero address for ETH).
     */
    function safeLiquidateToEthWithFlashLoan(address borrower, uint256 repayAmount, CEther cEther, CErc20 cErc20Collateral, uint256 minProfitAmount, address exchangeProfitTo) external {
        // Flashloan via Uniswap
        require(repayAmount > 0, "Repay amount must be greater than 0.");
        IUniswapV2Pair pair = IUniswapV2Pair(UniswapV2Library.pairFor(UNISWAP_V2_FACTORY_ADDRESS, cErc20Collateral.underlying() == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 ? 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599 : 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48, WETH_ADDRESS)); // Use USDC unless collateral is USDC, in which case we use WBTC to avoid a reentrancy error
        address token0 = pair.token0();
        pair.swap(token0 == WETH_ADDRESS ? repayAmount : 0, token0 != WETH_ADDRESS ? repayAmount : 0, address(this), msg.data);

        // Exchange profit if necessary
        if (exchangeProfitTo != address(0) && exchangeProfitTo != cErc20Collateral.underlying()) UNISWAP_V2_ROUTER_02.swapExactETHForTokens{value: address(this).balance}(minProfitAmount, array(WETH_ADDRESS, exchangeProfitTo), address(this), block.timestamp);

        // Transfer profit to msg.sender
        transferSeizedFunds(exchangeProfitTo, minProfitAmount);
    }

    /**
     * @dev Receives ETH from WETH, liquidations, and flashloans.
     * Requires that `msg.sender` is WETH, a CToken, or the Uniswap V2 Router.
     */
    receive() external payable {
        require(msg.sender == WETH_ADDRESS || msg.sender == UNISWAP_V2_ROUTER_02_ADDRESS || CToken(msg.sender).isCToken(), "Sender is not WETH, a CToken, or the Uniswap V2 Router.");
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
        (address borrower, uint256 repayAmount, address cToken, address cTokenCollateral, uint256 minProfitAmount, address exchangeProfitTo) = abi.decode(params[4:], (address, uint256, address, address, uint256, address));

        // Calculate flashloan return amount
        uint256 flashLoanReturnAmount = repayAmount.mul(1000).div(997);
        if (repayAmount.mul(1000).mod(997) > 0) flashLoanReturnAmount++; // Round up if division resulted in a remainder

        // Liquidate unhealthy borrow, exchange seized collateral, return flashloaned funds, and exchange profit
        if (CToken(cToken).isCEther()) postFlashLoanWeth(borrower, repayAmount, CEther(cToken), CErc20(cTokenCollateral), minProfitAmount, exchangeProfitTo, flashLoanReturnAmount);
        else postFlashLoanTokens(borrower, repayAmount, CErc20(cToken), CToken(cTokenCollateral), minProfitAmount, exchangeProfitTo, flashLoanReturnAmount);
    }

    /**
     * @dev Liquidate unhealthy ETH borrow, exchange seized collateral, return flashloaned funds, and exchange profit.
     */
    function postFlashLoanWeth(address borrower, uint256 repayAmount, CEther cEther, CErc20 cErc20Collateral, uint256 minProfitAmount, address exchangeProfitTo, uint256 flashLoanReturnAmount) private {
        // Unwrap WETH
        WETH.withdraw(repayAmount);

        // Liquidate ETH borrow using flashloaned ETH
        cEther.liquidateBorrow{value: repayAmount}(borrower, CToken(cErc20Collateral));

        // Redeem seized cTokens for underlying asset
        uint256 seizedCTokenAmount = cErc20Collateral.balanceOf(address(this));
        require(seizedCTokenAmount > 0, "No cTokens seized.");
        uint256 redeemResult = cErc20Collateral.redeem(seizedCTokenAmount);
        require(redeemResult == 0, "Error calling redeeming seized cToken: error code not equal to 0");

        // Check underlying collateral seized
        IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(cErc20Collateral.underlying());
        uint256 underlyingCollateralSeized = underlyingCollateral.balanceOf(address(this));

        // Approve to Uniswap router
        safeApprove(underlyingCollateral, UNISWAP_V2_ROUTER_02_ADDRESS, underlyingCollateralSeized);

        // Swap collateral tokens for ETH via Uniswap router
        if (exchangeProfitTo == address(underlyingCollateral)) UNISWAP_V2_ROUTER_02.swapTokensForExactETH(flashLoanReturnAmount, underlyingCollateralSeized, array(address(underlyingCollateral), WETH_ADDRESS), address(this), block.timestamp);
        else UNISWAP_V2_ROUTER_02.swapExactTokensForETH(underlyingCollateralSeized, flashLoanReturnAmount, array(address(underlyingCollateral), WETH_ADDRESS), address(this), block.timestamp);

        // Repay flashloan
        require(flashLoanReturnAmount <= address(this).balance, "Flashloan return amount greater than ETH exchanged from seized collateral.");
        WETH.deposit{value: flashLoanReturnAmount}();
        require(WETH.transfer(msg.sender, flashLoanReturnAmount), "Failed to transfer WETH back to flashlender.");
    }

    /**
     * @dev Liquidate unhealthy token borrow, exchange seized collateral, return flashloaned funds, and exchange profit.
     */
    function postFlashLoanTokens(address borrower, uint256 repayAmount, CErc20 cErc20, CToken cTokenCollateral, uint256 minProfitAmount, address exchangeProfitTo, uint256 flashLoanReturnAmount) private {
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

        // Swap cTokenCollateral for cErc20 via Uniswap
        if (cTokenCollateral.isCEther()) {
            // Swap collateral ETH for tokens via Uniswap router
            uint256 underlyingCollateralSeized = address(this).balance;
            uint256 wethRequired = UniswapV2Library.getAmountsIn(UNISWAP_V2_FACTORY_ADDRESS, repayAmount, array(WETH_ADDRESS, address(underlyingBorrow)))[0];

            // Repay flashloan
            require(wethRequired <= underlyingCollateralSeized, "Seized ETH collateral not enough to repay flashloan.");
            WETH.deposit{value: wethRequired}();
            require(WETH.transfer(msg.sender, wethRequired), "Failed to repay Uniswap flashloan with WETH exchanged from seized collateral.");
        } else {
            // Check underlying collateral seized
            IERC20Upgradeable underlyingCollateral = IERC20Upgradeable(CErc20(address(cTokenCollateral)).underlying());
            uint256 underlyingCollateralSeized = underlyingCollateral.balanceOf(address(this));

            // Approve to Uniswap router
            safeApprove(underlyingCollateral, UNISWAP_V2_ROUTER_02_ADDRESS, underlyingCollateralSeized);

            // Swap collateral tokens for WETH to be repaid via Uniswap router
            uint256 wethRequired = UniswapV2Library.getAmountsIn(UNISWAP_V2_FACTORY_ADDRESS, repayAmount, array(WETH_ADDRESS, address(underlyingBorrow)))[0];
            UNISWAP_V2_ROUTER_02.swapTokensForExactTokens(wethRequired, underlyingCollateralSeized, array(address(underlyingCollateral), WETH_ADDRESS), address(this), block.timestamp);

            // Repay flashloan
            require(wethRequired <= IERC20Upgradeable(WETH_ADDRESS).balanceOf(address(this)), "Not enough WETH exchanged from seized collateral to repay flashloan.");
            require(WETH.transfer(msg.sender, wethRequired), "Failed to repay Uniswap flashloan with WETH exchanged from seized collateral.");
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
