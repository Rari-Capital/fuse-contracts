// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/proxy/ClonesUpgradeable.sol";

import "./UniswapV3TwapPriceOracleV2.sol";

/**
 * @title UniswapV3TwapPriceOracleV2Factory
 * @notice Deploys and catalogs UniswapV3TwapPriceOracleV2 contracts.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract UniswapV3TwapPriceOracleV2Factory {
    /**
     * @dev WETH token contract address.
     */
    address constant public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @dev Implementation address for the `UniswapV3TwapPriceOracleV2`.
     */
    address immutable public logic;

    /**
     * @notice Maps `UniswapV3Factory` contracts to fee tiers to base tokens to `UniswapV3TwapPriceOracleV2` contract addresses.
     */
    mapping(address => mapping(uint256 => mapping(address => UniswapV3TwapPriceOracleV2))) public oracles;

    /**
     * @notice Constructor that stores the UniswapV3TwapPriceOracleV2 implementation/logic contract.
     * @param _logic The `UniswapV3TwapPriceOracleV2` implementation contract.
     */
    constructor(address _logic) public {
        require(_logic != address(0), "UniswapV3TwapPriceOracleV2 implementation/logic contract not defined.");
        logic  = _logic;
    }

    /**
     * @notice Deploys a `UniswapV3TwapPriceOracleV2`.
     * @param uniswapV3Factory The `UniswapV3Factory` contract of the pairs for which this oracle will be used.
     * @param feeTier The fee tier of the pairs for which this oracle will be used.
     * @param baseToken The base token of the pairs for which this oracle will be used.
     */
    function deploy(address uniswapV3Factory, uint24 feeTier, address baseToken) external returns (address) {
        // Input validation
        if (baseToken == address(0)) baseToken = address(WETH);

        // Return existing oracle if present
        address currentOracle = address(oracles[uniswapV3Factory][feeTier][baseToken]);
        if (currentOracle != address(0)) return currentOracle;

        // Deploy oracle
        bytes32 salt = keccak256(abi.encodePacked(uniswapV3Factory, feeTier, baseToken));
        address oracle = ClonesUpgradeable.cloneDeterministic(logic, salt);
        UniswapV3TwapPriceOracleV2(oracle).initialize(uniswapV3Factory, feeTier, baseToken);

        // Set oracle in state
        oracles[uniswapV3Factory][feeTier][baseToken] = UniswapV3TwapPriceOracleV2(oracle);

        // Return oracle address
        return oracle;
    }
}
