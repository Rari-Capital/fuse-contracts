// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./external/compound/Comptroller.sol";
import "./external/compound/Unitroller.sol";
import "./external/compound/PriceOracle.sol";

/**
 * @title FusePoolDirectory
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FusePoolDirectory is a directory for Fuse interest rate pools.
 */
contract FusePoolDirectory is OwnableUpgradeable {
    /**
     * @dev Initializes a deployer whitelist if desired.
     * @param _enforceDeployerWhitelist Boolean indicating if the deployer whitelist is to be enforced.
     * @param _deployerWhitelist Array of Ethereum accounts to be whitelisted.
     */
    function initialize(bool _enforceDeployerWhitelist, address[] memory _deployerWhitelist) public initializer {
        __Ownable_init();
        enforceDeployerWhitelist = _enforceDeployerWhitelist;
        for (uint256 i = 0; i < _deployerWhitelist.length; i++) deployerWhitelist[_deployerWhitelist[i]] = true;
    }

    /**
     * @dev Struct for a Fuse interest rate pool.
     */
    struct FusePool {
        string name;
        address creator;
        address comptroller;
        uint256 blockPosted;
        uint256 timestampPosted;
    }

    /**
     * @dev Array of Fuse interest rate pools.
     */
    FusePool[] public pools;

    /**
     * @dev Maps Ethereum accounts to arrays of Fuse pool indexes.
     */
    mapping(address => uint256[]) private _poolsByAccount;

    /**
     * @dev Maps Fuse pool Comptroller addresses to bools indicating if they have been registered via the directory.
     */
    mapping(address => bool) public poolExists;

    /**
     * @dev Emitted when a new Fuse pool is added to the directory.
     */
    event PoolRegistered(uint256 index, FusePool pool);

    /**
     * @dev Booleans indicating if the deployer whitelist is enforced.
     */
    bool public enforceDeployerWhitelist;

    /**
     * @dev Maps Ethereum accounts to booleans indicating if they are allowed to deploy pools.
     */
    mapping(address => bool) public deployerWhitelist;

    /**
     * @dev Controls if the deployer whitelist is to be enforced.
     * @param enforce Boolean indicating if the deployer whitelist is to be enforced.
     */
    function _setDeployerWhitelistEnforcement(bool enforce) external onlyOwner {
        enforceDeployerWhitelist = enforce;
    }

    /**
     * @dev Adds/removes Ethereum accounts to the deployer whitelist.
     * @param deployers Array of Ethereum accounts to be whitelisted.
     * @param status Whether to add or remove the accounts.
     */
    function _editDeployerWhitelist(address[] calldata deployers, bool status) external onlyOwner {
        require(deployers.length > 0, "No deployers supplied.");
        for (uint256 i = 0; i < deployers.length; i++) deployerWhitelist[deployers[i]] = status;
    }

    /**
     * @dev Adds a new Fuse pool to the directory (without checking msg.sender).
     * @param name The name of the pool.
     * @param comptroller The pool's Comptroller proxy contract address.
     * @return The index of the registered Fuse pool.
     */
    function _registerPool(string memory name, address comptroller) internal returns (uint256) {
        require(!poolExists[comptroller], "Pool already exists in the directory.");
        require(!enforceDeployerWhitelist || deployerWhitelist[msg.sender], "Sender is not on deployer whitelist.");
        FusePool memory pool = FusePool(name, msg.sender, comptroller, block.number, block.timestamp);
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
     * @param enforceWhitelist Boolean indicating if the pool's supplier/borrower whitelist is to be enforced.
     * @param closeFactor The pool's close factor (scaled by 1e18).
     * @param maxAssets Maximum number of assets in the pool.
     * @param liquidationIncentive The pool's liquidation incentive (scaled by 1e18).
     * @param priceOracle The pool's PriceOracle contract address.
     * @return The index of the registered Fuse pool and the Unitroller proxy address.
     */
    function deployPool(string memory name, address implementation, bool enforceWhitelist, uint256 closeFactor, uint256 maxAssets, uint256 liquidationIncentive, address priceOracle) external returns (uint256, address) {
        // Input validation
        require(implementation != address(0), "No Comptroller implementation contract address specified.");
        require(priceOracle != address(0), "No PriceOracle contract address specified.");

        // Deploy Unitroller using msg.sender, name, and block.number as a salt
        bytes memory unitrollerCreationCode = hex"60806040526001805460ff60a81b1960ff60a01b19909116600160a01b1716600160a81b17905534801561003257600080fd5b50600080546001600160a01b03191633179055610ae2806100546000396000f3fe6080604052600436106100a75760003560e01c8063bb82aa5e11610064578063bb82aa5e14610438578063c1e803341461044d578063dcfbc0c714610462578063e992a04114610477578063e9c714f2146104aa578063f851a440146104bf576100a7565b80630225ab9d1461032c5780630a755ec21461036a57806326782247146103935780632f1069ba146103c45780636f63af0b146103d9578063b71d1a0c14610405575b60025460408051600481526024810182526020810180516001600160e01b0316633757348b60e21b178152915181516000946060946001600160a01b039091169392918291908083835b602083106101105780518252601f1990920191602091820191016100f1565b6001836020036101000a038019825116818451168082178552505050505050905001915050600060405180830381855afa9150503d8060008114610170576040519150601f19603f3d011682016040523d82523d6000602084013e610175565b606091505b50915091506000821561019c5781806020019051602081101561019757600080fd5b505190505b80156102a9576002546040805163bbcdd6d360e01b81526001600160a01b03909216600483015251600091734826533b4897376654bb4d4ad88b7fafd0c985289163bbcdd6d391602480820192602092909190829003018186803b15801561020357600080fd5b505afa158015610217573d6000803e3d6000fd5b505050506040513d602081101561022d57600080fd5b50516002549091506001600160a01b038083169116146102a757600280546001600160a01b038381166001600160a01b0319831617928390556040805192821680845293909116602083015280517fd604de94d45953f9138079ec1b82d533cb2160c906d1076d1f7ed54befbca97a9281900390910190a1505b505b6002546040516000916001600160a01b031690829036908083838082843760405192019450600093509091505080830381855af49150503d806000811461030c576040519150601f19603f3d011682016040523d82523d6000602084013e610311565b606091505b505090506040513d6000823e818015610328573d82f35b3d82fd5b34801561033857600080fd5b506103586004803603602081101561034f57600080fd5b503515156104d4565b60408051918252519081900360200190f35b34801561037657600080fd5b5061037f610570565b604080519115158252519081900360200190f35b34801561039f57600080fd5b506103a8610580565b604080516001600160a01b039092168252519081900360200190f35b3480156103d057600080fd5b5061037f61058f565b3480156103e557600080fd5b50610358600480360360208110156103fc57600080fd5b5035151561059f565b34801561041157600080fd5b506103586004803603602081101561042857600080fd5b50356001600160a01b031661063b565b34801561044457600080fd5b506103a86106be565b34801561045957600080fd5b506103586106cd565b34801561046e57600080fd5b506103a86107c8565b34801561048357600080fd5b506103586004803603602081101561049a57600080fd5b50356001600160a01b03166107d7565b3480156104b657600080fd5b506103586108f7565b3480156104cb57600080fd5b506103a86109dd565b60006104de6109ec565b6104f5576104ee60016004610a47565b905061056b565b60015460ff600160a81b90910416151582151514156105155760006104ee565b60018054831515600160a81b810260ff60a81b199092169190911790915560408051918252517f10f9a0a95673b0837d1dce21fd3bffcb6d760435e9b5300b75a271182f75f8229181900360200190a160005b90505b919050565b600154600160a81b900460ff1681565b6001546001600160a01b031681565b600154600160a01b900460ff1681565b60006105a96109ec565b6105b9576104ee60016004610a47565b60015460ff600160a01b90910416151582151514156105d95760006104ee565b60018054831515600160a01b90810260ff60a01b199092169190911791829055604080519190920460ff161515815290517fabb56a15fd39488c914b324690b88f30d7daec63d2131ca0ef47e5739068c86e9181900360200190a16000610568565b60006106456109ec565b610655576104ee6001600f610a47565b600180546001600160a01b038481166001600160a01b0319831681179093556040805191909216808252602082019390935281517fca4f2f25d0898edd99413412fb94012f9e54ec8142f9b093e7720646a95b16a9929181900390910190a160005b9392505050565b6002546001600160a01b031681565b6003546000906001600160a01b0316331415806106f357506003546001600160a01b0316155b1561070a57610703600180610a47565b90506107c5565b60028054600380546001600160a01b038082166001600160a01b031980861682179687905590921690925560408051938316808552949092166020840152815190927fd604de94d45953f9138079ec1b82d533cb2160c906d1076d1f7ed54befbca97a92908290030190a1600354604080516001600160a01b038085168252909216602083015280517fe945ccee5d701fc83f9b8aa8ca94ea4219ec1fcbd4f4cab4f0ea57c5c3e1d8159281900390910190a160005b925050505b90565b6003546001600160a01b031681565b60006107e16109ec565b6107f1576104ee60016011610a47565b60025460408051639d244f9f60e01b81526001600160a01b039283166004820152918416602483015251734826533b4897376654bb4d4ad88b7fafd0c9852891639d244f9f916044808301926020929190829003018186803b15801561085657600080fd5b505afa15801561086a573d6000803e3d6000fd5b505050506040513d602081101561088057600080fd5b5051610892576104ee60016010610a47565b600380546001600160a01b038481166001600160a01b0319831617928390556040805192821680845293909116602083015280517fe945ccee5d701fc83f9b8aa8ca94ea4219ec1fcbd4f4cab4f0ea57c5c3e1d8159281900390910190a160006106b7565b6001546000906001600160a01b031633141580610912575033155b156109235761070360016000610a47565b60008054600180546001600160a01b038082166001600160a01b031980861682179687905590921690925560408051938316808552949092166020840152815190927ff9ffabca9c8276e99321725bcb43fb076a6c66a54b7f21c4e8146d8519b417dc92908290030190a1600154604080516001600160a01b038085168252909216602083015280517fca4f2f25d0898edd99413412fb94012f9e54ec8142f9b093e7720646a95b16a99281900390910190a160006107c0565b6000546001600160a01b031681565b600080546001600160a01b031633148015610a105750600154600160a81b900460ff165b80610a42575033734826533b4897376654bb4d4ad88b7fafd0c98528148015610a425750600154600160a01b900460ff165b905090565b60007f45b96fe442630264581b197e84bbada861235052c5a1aadfff9ea4e40a969aa0836015811115610a7657fe5b83601a811115610a8257fe5b604080519283526020830191909152600082820152519081900360600190a18260158111156106b757fefea265627a7a72315820b063cb02e120b5afe144d885cdb603bced17b4bdfef13e4072cc53b41ae0f16b64736f6c63430005110032";
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, name, block.number));
        address proxy;

        assembly {
            proxy := create2(0, add(unitrollerCreationCode, 32), mload(unitrollerCreationCode), salt)
        }

        // Setup Unitroller
        Unitroller unitroller = Unitroller(proxy);
        require(unitroller._setPendingImplementation(implementation) == 0, "Failed to set pending implementation on Unitroller."); // Checks Comptroller implementation whitelist
        Comptroller comptrollerImplementation = Comptroller(implementation);
        comptrollerImplementation._become(unitroller);
        Comptroller comptrollerProxy = Comptroller(proxy);

        // Set pool parameters
        comptrollerProxy._setCloseFactor(closeFactor);
        comptrollerProxy._setMaxAssets(maxAssets);
        comptrollerProxy._setLiquidationIncentive(liquidationIncentive);
        comptrollerProxy._setPriceOracle(PriceOracle(priceOracle));

        // Whitelist
        if (enforceWhitelist) require(comptrollerProxy._setWhitelistEnforcement(true) == 0, "Failed to enforce supplier/borrower whitelist.");

        // Make msg.sender the admin
        require(unitroller._setPendingAdmin(msg.sender) == 0, "Failed to set pending admin on Unitroller.");

        // Register the pool with this FusePoolDirectory
        return (_registerPool(name, proxy), proxy);
    }

    /**
     * @notice Returns arrays of all Fuse pools' data.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     */
    function getAllPools() external view returns (FusePool[] memory) {
        return pools;
    }

    /**
     * @notice Returns arrays of all public Fuse pool indexes and data.
     * @dev This function is not designed to be called in a transaction: it is too gas-intensive.
     */
    function getPublicPools() external view returns (uint256[] memory, FusePool[] memory) {
        uint256 arrayLength = 0;

        for (uint256 i = 0; i < pools.length; i++) {
            try Comptroller(pools[i].comptroller).enforceWhitelist() returns (bool enforceWhitelist) {
                if (enforceWhitelist) continue;
            } catch { }

            arrayLength++;
        }

        uint256[] memory indexes = new uint256[](arrayLength);
        FusePool[] memory publicPools = new FusePool[](arrayLength);
        uint256 index = 0;

        for (uint256 i = 0; i < pools.length; i++) {
            try Comptroller(pools[i].comptroller).enforceWhitelist() returns (bool enforceWhitelist) {
                if (enforceWhitelist) continue;
            } catch { }

            indexes[index] = i;
            publicPools[index] = pools[i];
            index++;
        }

        return (indexes, publicPools);
    }

    /**
     * @notice Returns arrays of Fuse pool indexes and data created by `account`.
     */
    function getPoolsByAccount(address account) external view returns (uint256[] memory, FusePool[] memory) {
        uint256[] memory indexes = new uint256[](_poolsByAccount[account].length);
        FusePool[] memory accountPools = new FusePool[](_poolsByAccount[account].length);

        for (uint256 i = 0; i < _poolsByAccount[account].length; i++) {
            indexes[i] = _poolsByAccount[account][i];
            accountPools[i] = pools[_poolsByAccount[account][i]];
        }

        return (indexes, accountPools);
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

    /**
     * @notice Modify existing Fuse pool name.
     */
    function setPoolName(uint256 index, string calldata name) external {
        Comptroller _comptroller = Comptroller(pools[index].comptroller);
        require(msg.sender == _comptroller.admin() && _comptroller.adminHasRights() || msg.sender == owner());
        pools[index].name = name;
    }
}
