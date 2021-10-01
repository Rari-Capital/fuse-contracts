// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;

import "./UniswapV3TwapPriceOracleV2.sol";

/**
 * @title UniswapV3TwapPriceOracleV2Factory
 * @notice Deploys and catalogs UniswapV3TwapPriceOracleV2 contracts.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract UniswapV3TwapPriceOracleV2Factory {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice Deploys a `UniswapV3TwapPriceOracleV2`.
     * @param uniswapV3Factory The `UniswapV3Factory` contract of the pairs for which this oracle will be used.
     * @param feeTier The fee tier of the pairs for which this oracle will be used.
     * @param baseToken The base token of the pairs for which this oracle will be used.
     */
    function deploy(address uniswapV3Factory, uint256 feeTier, address baseToken) external returns (address) {
        // Input validation
        if (baseToken == address(0)) baseToken = address(WETH);

        // Return existing oracle if present
        address currentOracle = address(oracles[uniswapV3Factory][feeTier][baseToken]);
        if (currentOracle != address(0)) return currentOracle;

        // Deploy oracle
        bytes memory bytecode = abi.encodePacked(type(UniswapV3TwapPriceOracleV2).creationCode, abi.encode(uniswapV3Factory, feeTier, baseToken));
        bytes32 salt = keccak256(abi.encodePacked(uniswapV3Factory, feeTier, baseToken));
        address oracle;

        assembly {
            oracle := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
            if iszero(extcodesize(oracle)) {
                revert(0, "Failed to deploy price oracle.")
            }
        }

        // Set oracle in state
        oracles[uniswapV3Factory][feeTier][baseToken] = UniswapV3TwapPriceOracleV2(oracle);

        // Return oracle address
        return oracle;
    }

    /**
     * @dev WETH token contract address.
     */
    address constant public WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /**
     * @notice Maps `UniswapV3Factory` contracts to fee tiers to base tokens to `UniswapV3TwapPriceOracleV2` contract addresses.
     */
    mapping(address => mapping(uint256 => mapping(address => UniswapV3TwapPriceOracleV2))) public oracles;
}
