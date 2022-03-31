// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.12;

import "../../../oracles/BasePriceOracle.sol";
import "../../../external/tracer/ILeveragedPool.sol";

import "../../../external/compound/PriceOracle.sol";
import "../../../external/compound/CErc20.sol";

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

/**
 * Tracer Perpetual Pool oracle 
 * @notice Returns prices for Tracer Pool short and long tokens
 * @dev Implements `PriceOracle` and `BasePriceOracle`.
 * @author Sri Yantra <sriyantra@rari.capital>, David Lucid <david@rari.capital> (https://github.com/davidlucid), raymogg
 */
contract TracerPoolPriceOracle is PriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    mapping(address => address) tokenToPool;
    mapping(address => address) poolToSettlementToken;

    /**
     * @dev The administrator of this oracle.
     */
    address public admin;

    /**
     * @dev Constructor to set admin
     */
    constructor (address _admin) public {
        admin = _admin;
    }

    /**
     * @dev Changes the admin and emits an event.
     */
    function changeAdmin(address newAdmin) external onlyAdmin {
        address oldAdmin = admin;
        admin = newAdmin;
        emit NewAdmin(oldAdmin, newAdmin);
    }

    /**
     * @dev Event emitted when `admin` is changed.
     */
    event NewAdmin(address oldAdmin, address newAdmin);

    /**
     * @dev Modifier that checks if `msg.sender == admin`.
     */
    modifier onlyAdmin {
        require(msg.sender == admin, "Sender is not the admin.");
        _;
    }

    /**
     * @notice Fetches the token/ETH price, with 18 decimals of precision.
     * @param underlying The underlying token address for which to get the price.
     * @return Price denominated in ETH (scaled by 1e18)
     */
    function price(address underlying) external override view returns (uint) {
        return _price(underlying);
    }

    function _price(address underlying) internal view returns (uint) {
        // lookup address of perpetual pool
        address pool = tokenToPool[underlying];
        require(pool != address(0), "Pool not found");

        ILeveragedPool _pool = ILeveragedPool(pool);
        address[2] memory tokens =  _pool.poolTokens();
        uint256 issuedPoolTokens = ERC20Upgradeable(underlying).totalSupply();

        // underlying MUST equal tokens[0] or [1] due to the pool == addr(0) check
        // pool token price = collateral in pool / issued pool tokens
        if (underlying == tokens[0]) {
            // long token
            uint256 lPrice = _pool.longBalance().mul(10 ** uint256(ERC20Upgradeable(underlying).decimals())).div(issuedPoolTokens);
            return lPrice.mul(BasePriceOracle(msg.sender).price(poolToSettlementToken[pool])).div(10 ** uint256(ERC20Upgradeable(underlying).decimals()));
        } else {
            // short token
            uint256 sPrice = _pool.shortBalance().mul(10 ** uint256(ERC20Upgradeable(underlying).decimals())).div(issuedPoolTokens);
            return sPrice.mul(BasePriceOracle(msg.sender).price(poolToSettlementToken[pool])).div(10 ** uint256(ERC20Upgradeable(underlying).decimals()));
        }
    }

    /**
     * @notice Returns the price in ETH of the token underlying `cToken`.
     * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
     * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
     */
    function getUnderlyingPrice(CToken cToken) external override view returns (uint) {
        address underlying = CErc20(address(cToken)).underlying();
        // Comptroller needs prices to be scaled by 1e(36 - decimals)
        // Since `_price` returns prices scaled by 18 decimals, we must scale them by 1e(36 - 18 - decimals)
        return _price(underlying).mul(1e18).div(10 ** uint256(ERC20Upgradeable(underlying).decimals()));
    }

    /**
     * @notice registers a Tracer Perpetual Pool with this oracle contract
     * @param pool pool address, settlementToken address of settlement token in Bal pool
     */
    function addPool(address pool, address settlementToken) public onlyAdmin {
        require (settlementToken != address(0), "settlement token needed");
        
        ILeveragedPool _pool = ILeveragedPool(pool);
        require(_pool.poolTokens()[0] != address(0), "Pool not valid");
        address[2] memory tokens =  _pool.poolTokens();

        // register the short and long token for this pool
        // long token
        tokenToPool[tokens[0]] = pool;
        // short token
        tokenToPool[tokens[1]] = pool;
        // settlement token
        poolToSettlementToken[pool] = settlementToken;
    }
}