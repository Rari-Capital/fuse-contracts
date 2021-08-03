// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/proxy/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/SafeERC20Upgradeable.sol";

/**
 * @title FuseFeeDistributor
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice FuseFeeDistributor controls and receives protocol fees from Fuse pools and relays admin actions to Fuse pools.
 */
contract FuseFeeDistributor is Initializable, OwnableUpgradeable {
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /**
     * @dev Initializer that sets the proportion of Fuse pool interest taken as a protocol fee.
     * @param _interestFeeRate The proportion of Fuse pool interest taken as a protocol fee (scaled by 1e18).
     */
    function initialize(uint256 _interestFeeRate) public initializer {
        require(_interestFeeRate <= 1e18, "Interest fee rate cannot be more than 100%.");
        __Ownable_init();
        interestFeeRate = _interestFeeRate;
        maxSupplyEth = uint256(-1);
        maxUtilizationRate = uint256(-1);
        comptrollerImplementationWhitelist[address(0)][0x94B2200d28932679DEF4A7d08596A229553a994E] = true;
        comptrollerImplementationWhitelist[address(0)][0x8A78A9D35c9C61F9E0Ff526C5d88eC28354543fE] = true;
        cErc20DelegateWhitelist[address(0)][0x67E70eeB9DD170f7B4A9EF620720c9069D5e706C][false] = true;
        cErc20DelegateWhitelist[address(0)][0x2b3dD0AE288c13a730F6C422e2262a9d3dA79Ed1][false] = true;
        cEtherDelegateWhitelist[address(0)][0x60884c8FAaD1B30B1C76100dA92B76eD3aF849ba][false] = true;
    }

    /**
     * @notice The proportion of Fuse pool interest taken as a protocol fee (scaled by 1e18).
     */
    uint256 public interestFeeRate;

    /**
     * @dev Sets the proportion of Fuse pool interest taken as a protocol fee.
     * @param _interestFeeRate The proportion of Fuse pool interest taken as a protocol fee (scaled by 1e18).
     */
    function _setInterestFeeRate(uint256 _interestFeeRate) external onlyOwner {
        require(_interestFeeRate <= 1e18, "Interest fee rate cannot be more than 100%.");
        interestFeeRate = _interestFeeRate;
    }

    /**
     * @dev Withdraws accrued fees on interest.
     * @param erc20Contract The ERC20 token address to withdraw. Set to the zero address to withdraw ETH.
     */
    function _withdrawAssets(address erc20Contract) external {
        if (erc20Contract == address(0)) {
            uint256 balance = address(this).balance;
            require(balance > 0, "No balance available to withdraw.");
            (bool success, ) = owner().call{value: balance}("");
            require(success, "Failed to transfer ETH balance to msg.sender.");
        } else {
            IERC20Upgradeable token = IERC20Upgradeable(erc20Contract);
            uint256 balance = token.balanceOf(address(this));
            require(balance > 0, "No token balance available to withdraw.");
            token.safeTransfer(owner(), balance);
        }
    }

    /**
     * @dev Minimum borrow balance (in ETH) per user per Fuse pool asset (only checked on new borrows, not redemptions).
     */
    uint256 public minBorrowEth;

    /**
     * @dev Maximum supply balance (in ETH) per user per Fuse pool asset.
     */
    uint256 public maxSupplyEth;

    /**
     * @dev Maximum utilization rate (scaled by 1e18) for Fuse pool assets (only checked on new borrows, not redemptions).
     */
    uint256 public maxUtilizationRate;

    /**
     * @dev Sets the proportion of Fuse pool interest taken as a protocol fee.
     * @param _minBorrowEth Minimum borrow balance (in ETH) per user per Fuse pool asset (only checked on new borrows, not redemptions).
     * @param _maxSupplyEth Maximum supply balance (in ETH) per user per Fuse pool asset.
     * @param _maxUtilizationRate Maximum utilization rate (scaled by 1e18) for Fuse pool assets (only checked on new borrows, not redemptions).
     */
    function _setPoolLimits(uint256 _minBorrowEth, uint256 _maxSupplyEth, uint256 _maxUtilizationRate) external onlyOwner {
        minBorrowEth = _minBorrowEth;
        maxSupplyEth = _maxSupplyEth;
        maxUtilizationRate = _maxUtilizationRate;
    }

    /**
     * @dev Receives ETH fees.
     */
    receive() external payable { }

    /**
     * @dev Sends data to a contract.
     * @param targets The contracts to which `data` will be sent.
     * @param data The data to be sent to each of `targets`.
     */
    function _callPool(address[] calldata targets, bytes[] calldata data) external onlyOwner {
        require(targets.length > 0 && targets.length == data.length, "Array lengths must be equal and greater than 0.");
        for (uint256 i = 0; i < targets.length; i++) targets[i].functionCall(data[i]);
    }

    /**
     * @dev Sends data to a contract.
     * @param targets The contracts to which `data` will be sent.
     * @param data The data to be sent to each of `targets`.
     */
    function _callPool(address[] calldata targets, bytes calldata data) external onlyOwner {
        require(targets.length > 0, "No target addresses specified.");
        for (uint256 i = 0; i < targets.length; i++) targets[i].functionCall(data);
    }

    function deployCEther(bytes calldata constructorData) external returns (address) {
        // Make sure comptroller == msg.sender
        (address comptroller) = abi.decode(constructorData[0:32], (address));
        require(comptroller == msg.sender, "Comptroller is not sender.");

        // Deploy Unitroller using msg.sender, underlying, and block.number as a salt
        bytes memory cEtherDelegatorCreationCode = hex"60806040523480156200001157600080fd5b50604051620013613803806200136183398181016040526101008110156200003857600080fd5b815160208301516040808501805191519395929483019291846401000000008211156200006457600080fd5b9083019060208201858111156200007a57600080fd5b82516401000000008111828201881017156200009557600080fd5b82525081516020918201929091019080838360005b83811015620000c4578181015183820152602001620000aa565b50505050905090810190601f168015620000f25780820380516001836020036101000a031916815260200191505b50604052602001805160405193929190846401000000008211156200011657600080fd5b9083019060208201858111156200012c57600080fd5b82516401000000008111828201881017156200014757600080fd5b82525081516020918201929091019080838360005b83811015620001765781810151838201526020016200015c565b50505050905090810190601f168015620001a45780820380516001836020036101000a031916815260200191505b50604081815260208301519201805192949193919284640100000000821115620001cd57600080fd5b908301906020820185811115620001e357600080fd5b8251640100000000811182820188101715620001fe57600080fd5b82525081516020918201929091019080838360005b838110156200022d57818101518382015260200162000213565b50505050905090810190601f1680156200025b5780820380516001836020036101000a031916815260200191505b506040526020018051906020019092919080519060200190929190505050620003d88489898989878760405160240180876001600160a01b03166001600160a01b03168152602001866001600160a01b03166001600160a01b031681526020018060200180602001858152602001848152602001838103835287818151815260200191508051906020019080838360005b8381101562000306578181015183820152602001620002ec565b50505050905090810190601f168015620003345780820380516001836020036101000a031916815260200191505b50838103825286518152865160209182019188019080838360005b83811015620003695781810151838201526020016200034f565b50505050905090810190601f168015620003975780820380516001836020036101000a031916815260200191505b5060408051601f198184030181529190526020810180516001600160e01b03908116631e70b25560e21b17909152909950620003fe16975050505050505050565b50620003f0846000856001600160e01b03620004c516565b5050505050505050620007ce565b606060006060846001600160a01b0316846040518082805190602001908083835b60208310620004405780518252601f1990920191602091820191016200041f565b6001836020036101000a038019825116818451168082178552505050505050905001915050600060405180830381855af49150503d8060008114620004a2576040519150601f19603f3d011682016040523d82523d6000602084013e620004a7565b606091505b50915091506000821415620004bd573d60208201fd5b949350505050565b60005460408051630304735160e61b81526001600160a01b039283166004820152918516602483015283151560448301525173a731585ab05fc9f83555cf9bff8f58ee94e18f859163c11cd440916064808301926020929190829003018186803b1580156200053357600080fd5b505afa15801562000548573d6000803e3d6000fd5b505050506040513d60208110156200055f57600080fd5b50516200059e5760405162461bcd60e51b81526004018080602001828103825260548152602001806200130d6054913960600191505060405180910390fd5b8115620005e0576040805160048152602481019091526020810180516001600160e01b0390811663153ab50560e01b17909152620005de91906200070616565b505b600080546001600160a01b038581166001600160a01b031983161783556040516020602482018181528651604484015286519390941694620006b79487949093849360649091019290860191908190849084905b838110156200064e57818101518382015260200162000634565b50505050905090810190601f1680156200067c5780820380516001836020036101000a031916815260200191505b5060408051601f198184030181529190526020810180516001600160e01b03908116630adccee560e31b179091529093506200070616915050565b50600054604080516001600160a01b038085168252909216602083015280517fd604de94d45953f9138079ec1b82d533cb2160c906d1076d1f7ed54befbca97a9281900390910190a150505050565b606060006060306001600160a01b0316846040518082805190602001908083835b60208310620007485780518252601f19909201916020918201910162000727565b6001836020036101000a0380198251168184511680821785525050505050509050019150506000604051808303816000865af19150503d8060008114620007ac576040519150601f19603f3d011682016040523d82523d6000602084013e620007b1565b606091505b50915091506000821415620007c7573d60208201fd5b9392505050565b610b2f80620007de6000396000f3fe6080604052600436106100295760003560e01c8063555bcc401461024a5780635c60da1b14610316575b33301480159061003c575061003c610347565b156101c7576000805460408051638abe0b7560e01b81526001600160a01b03909216600483015251829160609173a731585ab05fc9f83555cf9bff8f58ee94e18f8591638abe0b759160248083019287929190829003018186803b1580156100a357600080fd5b505afa1580156100b7573d6000803e3d6000fd5b505050506040513d6000823e601f3d908101601f1916820160405260608110156100e057600080fd5b8151602083015160408085018051915193959294830192918464010000000082111561010b57600080fd5b90830190602082018581111561012057600080fd5b825164010000000081118282018810171561013a57600080fd5b82525081516020918201929091019080838360005b8381101561016757818101518382015260200161014f565b50505050905090810190601f1680156101945780820380516001836020036101000a031916815260200191505b5060405250506000549396509194509250506001600160a01b038085169116146101c3576101c38383836104ac565b5050505b600080546040516001600160a01b0390911690829036908083838082843760405192019450600093509091505080830381855af49150503d806000811461022a576040519150601f19603f3d011682016040523d82523d6000602084013e61022f565b606091505b505090506040513d6000823e818015610246573d82f35b3d82fd5b34801561025657600080fd5b506103146004803603606081101561026d57600080fd5b6001600160a01b0382351691602081013515159181019060608101604082013564010000000081111561029f57600080fd5b8201836020820111156102b157600080fd5b803590602001918460018302840111640100000000831117156102d357600080fd5b91908080601f0160208091040260200160405190810160405280939291908181526020018383808284376000920191909152509295506106d6945050505050565b005b34801561032257600080fd5b5061032b610729565b604080516001600160a01b039092168252519081900360200190f35b60408051600481526024810182526020810180516001600160e01b0316635fe3b56760e01b1781529151815160009384936060933093919290918291908083835b602083106103a75780518252601f199092019160209182019101610388565b6001836020036101000a038019825116818451168082178552505050505050905001915050600060405180830381855afa9150503d8060008114610407576040519150601f19603f3d011682016040523d82523d6000602084013e61040c565b606091505b50915091508161041b57600080fd5b600081806020019051602081101561043257600080fd5b505160408051633757348b60e21b815290519192506001600160a01b0383169163dd5cd22c91600480820192602092909190829003018186803b15801561047857600080fd5b505afa15801561048c573d6000803e3d6000fd5b505050506040513d60208110156104a257600080fd5b5051935050505090565b60005460408051630304735160e61b81526001600160a01b039283166004820152918516602483015283151560448301525173a731585ab05fc9f83555cf9bff8f58ee94e18f859163c11cd440916064808301926020929190829003018186803b15801561051957600080fd5b505afa15801561052d573d6000803e3d6000fd5b505050506040513d602081101561054357600080fd5b50516105805760405162461bcd60e51b8152600401808060200182810382526054815260200180610aa76054913960600191505060405180910390fd5b81156105ba576040805160048152602481019091526020810180516001600160e01b031663153ab50560e01b1790526105b890610738565b505b600080546001600160a01b038581166001600160a01b0319831617835560405160206024820181815286516044840152865193909416946106879487949093849360649091019290860191908190849084905b8381101561062557818101518382015260200161060d565b50505050905090810190601f1680156106525780820380516001836020036101000a031916815260200191505b5060408051601f198184030181529190526020810180516001600160e01b0316630adccee560e31b1790529250610738915050565b50600054604080516001600160a01b038085168252909216602083015280517fd604de94d45953f9138079ec1b82d533cb2160c906d1076d1f7ed54befbca97a9281900390910190a150505050565b6106de6107fb565b6107195760405162461bcd60e51b8152600401808060200182810382526039815260200180610a6e6039913960400191505060405180910390fd5b6107248383836104ac565b505050565b6000546001600160a01b031681565b606060006060306001600160a01b0316846040518082805190602001908083835b602083106107785780518252601f199092019160209182019101610759565b6001836020036101000a0380198251168184511680821785525050505050509050019150506000604051808303816000865af19150503d80600081146107da576040519150601f19603f3d011682016040523d82523d6000602084013e6107df565b606091505b509150915060008214156107f4573d60208201fd5b9392505050565b6000805460408051600481526024810182526020810180516001600160e01b0316635fe3b56760e01b1781529151815185946060946001600160a01b039091169392918291908083835b602083106108645780518252601f199092019160209182019101610845565b6001836020036101000a038019825116818451168082178552505050505050905001915050600060405180830381855afa9150503d80600081146108c4576040519150601f19603f3d011682016040523d82523d6000602084013e6108c9565b606091505b5091509150816108d857600080fd5b60008180602001905160208110156108ef57600080fd5b5051604080516303e1469160e61b8152905191925082916001600160a01b0383169163f851a440916004808301926020929190829003018186803b15801561093657600080fd5b505afa15801561094a573d6000803e3d6000fd5b505050506040513d602081101561096057600080fd5b50516001600160a01b0316331480156109da5750806001600160a01b0316630a755ec26040518163ffffffff1660e01b815260040160206040518083038186803b1580156109ad57600080fd5b505afa1580156109c1573d6000803e3d6000fd5b505050506040513d60208110156109d757600080fd5b50515b80610a6457503373a731585ab05fc9f83555cf9bff8f58ee94e18f85148015610a645750806001600160a01b0316632f1069ba6040518163ffffffff1660e01b815260040160206040518083038186803b158015610a3757600080fd5b505afa158015610a4b573d6000803e3d6000fd5b505050506040513d6020811015610a6157600080fd5b50515b9450505050509056fe43457468657244656c656761746f723a3a5f736574496d706c656d656e746174696f6e3a2043616c6c6572206d7573742062652061646d696e4e657720696d706c656d656e746174696f6e20636f6e74726163742061646472657373206e6f742077686974656c6973746564206f7220616c6c6f7752657369676e206d75737420626520696e7665727465642ea265627a7a72315820487f74e603c4d8c30dc1800ae4cb22bc9fa13005c9569102c32db09a5dc9542464736f6c634300051100324e657720696d706c656d656e746174696f6e20636f6e74726163742061646472657373206e6f742077686974656c6973746564206f7220616c6c6f7752657369676e206d75737420626520696e7665727465642e";
        cEtherDelegatorCreationCode = abi.encodePacked(cEtherDelegatorCreationCode, constructorData);
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, address(0), block.number));
        address proxy;

        assembly {
            proxy := create2(0, add(cEtherDelegatorCreationCode, 32), mload(cEtherDelegatorCreationCode), salt)
            if iszero(extcodesize(proxy)) {
                revert(0, "Failed to deploy CEther.")
            }
        }

        return proxy;
    }

    function deployCErc20(bytes calldata constructorData) external returns (address) {
        // Make sure comptroller == msg.sender
        (address underlying, address comptroller) = abi.decode(constructorData[0:64], (address, address));
        require(comptroller == msg.sender, "Comptroller is not sender.");

        // Deploy CErc20Delegator using msg.sender, underlying, and block.number as a salt
        bytes memory cErc20DelegatorCreationCode = hex"60806040523480156200001157600080fd5b50604051620013d1380380620013d183398181016040526101208110156200003857600080fd5b8151602083015160408085015160608601805192519496939591949391820192846401000000008211156200006c57600080fd5b9083019060208201858111156200008257600080fd5b82516401000000008111828201881017156200009d57600080fd5b82525081516020918201929091019080838360005b83811015620000cc578181015183820152602001620000b2565b50505050905090810190601f168015620000fa5780820380516001836020036101000a031916815260200191505b50604052602001805160405193929190846401000000008211156200011e57600080fd5b9083019060208201858111156200013457600080fd5b82516401000000008111828201881017156200014f57600080fd5b82525081516020918201929091019080838360005b838110156200017e57818101518382015260200162000164565b50505050905090810190601f168015620001ac5780820380516001836020036101000a031916815260200191505b50604081815260208301519201805192949193919284640100000000821115620001d557600080fd5b908301906020820185811115620001eb57600080fd5b82516401000000008111828201881017156200020657600080fd5b82525081516020918201929091019080838360005b83811015620002355781810151838201526020016200021b565b50505050905090810190601f168015620002635780820380516001836020036101000a031916815260200191505b50604081815260208381015193909101516001600160a01b03808e1660248501908152818e166044860152908c16606485015260c4840185905260e4840182905260e0608485019081528b516101048601528b51959750919550620003d39489948f948f948f948f948f948d948d949260a4830192610124019189019080838360005b8381101562000300578181015183820152602001620002e6565b50505050905090810190601f1680156200032e5780820380516001836020036101000a031916815260200191505b50838103825286518152865160209182019188019080838360005b838110156200036357818101518382015260200162000349565b50505050905090810190601f168015620003915780820380516001836020036101000a031916815260200191505b5060408051601f198184030181529190526020810180516001600160e01b0390811663a0b0d28960e01b17909152909a50620003fa1698505050505050505050565b50620003eb846000856001600160e01b03620004c116565b505050505050505050620007ca565b606060006060846001600160a01b0316846040518082805190602001908083835b602083106200043c5780518252601f1990920191602091820191016200041b565b6001836020036101000a038019825116818451168082178552505050505050905001915050600060405180830381855af49150503d80600081146200049e576040519150601f19603f3d011682016040523d82523d6000602084013e620004a3565b606091505b50915091506000821415620004b9573d60208201fd5b949350505050565b600054604080516338e6a07360e11b81526001600160a01b039283166004820152918516602483015283151560448301525173a731585ab05fc9f83555cf9bff8f58ee94e18f85916371cd40e6916064808301926020929190829003018186803b1580156200052f57600080fd5b505afa15801562000544573d6000803e3d6000fd5b505050506040513d60208110156200055b57600080fd5b50516200059a5760405162461bcd60e51b81526004018080602001828103825260548152602001806200137d6054913960600191505060405180910390fd5b8115620005dc576040805160048152602481019091526020810180516001600160e01b0390811663153ab50560e01b17909152620005da91906200070216565b505b600080546001600160a01b038581166001600160a01b031983161783556040516020602482018181528651604484015286519390941694620006b39487949093849360649091019290860191908190849084905b838110156200064a57818101518382015260200162000630565b50505050905090810190601f168015620006785780820380516001836020036101000a031916815260200191505b5060408051601f198184030181529190526020810180516001600160e01b03908116630adccee560e31b179091529093506200070216915050565b50600054604080516001600160a01b038085168252909216602083015280517fd604de94d45953f9138079ec1b82d533cb2160c906d1076d1f7ed54befbca97a9281900390910190a150505050565b606060006060306001600160a01b0316846040518082805190602001908083835b60208310620007445780518252601f19909201916020918201910162000723565b6001836020036101000a0380198251168184511680821785525050505050509050019150506000604051808303816000865af19150503d8060008114620007a8576040519150601f19603f3d011682016040523d82523d6000602084013e620007ad565b606091505b50915091506000821415620007c3573d60208201fd5b9392505050565b610ba380620007da6000396000f3fe6080604052600436106100295760003560e01c8063555bcc40146102875780635c60da1b14610353575b34156100665760405162461bcd60e51b8152600401808060200182810382526037815260200180610aab6037913960400191505060405180910390fd5b3330148015906100795750610079610384565b15610204576000805460408051638abe0b7560e01b81526001600160a01b03909216600483015251829160609173a731585ab05fc9f83555cf9bff8f58ee94e18f8591638abe0b759160248083019287929190829003018186803b1580156100e057600080fd5b505afa1580156100f4573d6000803e3d6000fd5b505050506040513d6000823e601f3d908101601f19168201604052606081101561011d57600080fd5b8151602083015160408085018051915193959294830192918464010000000082111561014857600080fd5b90830190602082018581111561015d57600080fd5b825164010000000081118282018810171561017757600080fd5b82525081516020918201929091019080838360005b838110156101a457818101518382015260200161018c565b50505050905090810190601f1680156101d15780820380516001836020036101000a031916815260200191505b5060405250506000549396509194509250506001600160a01b03808516911614610200576102008383836104e9565b5050505b600080546040516001600160a01b0390911690829036908083838082843760405192019450600093509091505080830381855af49150503d8060008114610267576040519150601f19603f3d011682016040523d82523d6000602084013e61026c565b606091505b505090506040513d6000823e818015610283573d82f35b3d82fd5b34801561029357600080fd5b50610351600480360360608110156102aa57600080fd5b6001600160a01b038235169160208101351515918101906060810160408201356401000000008111156102dc57600080fd5b8201836020820111156102ee57600080fd5b8035906020019184600183028401116401000000008311171561031057600080fd5b91908080601f016020809104026020016040519081016040528093929190818152602001838380828437600092019190915250929550610713945050505050565b005b34801561035f57600080fd5b50610368610766565b604080516001600160a01b039092168252519081900360200190f35b60408051600481526024810182526020810180516001600160e01b0316635fe3b56760e01b1781529151815160009384936060933093919290918291908083835b602083106103e45780518252601f1990920191602091820191016103c5565b6001836020036101000a038019825116818451168082178552505050505050905001915050600060405180830381855afa9150503d8060008114610444576040519150601f19603f3d011682016040523d82523d6000602084013e610449565b606091505b50915091508161045857600080fd5b600081806020019051602081101561046f57600080fd5b505160408051633757348b60e21b815290519192506001600160a01b0383169163dd5cd22c91600480820192602092909190829003018186803b1580156104b557600080fd5b505afa1580156104c9573d6000803e3d6000fd5b505050506040513d60208110156104df57600080fd5b5051935050505090565b600054604080516338e6a07360e11b81526001600160a01b039283166004820152918516602483015283151560448301525173a731585ab05fc9f83555cf9bff8f58ee94e18f85916371cd40e6916064808301926020929190829003018186803b15801561055657600080fd5b505afa15801561056a573d6000803e3d6000fd5b505050506040513d602081101561058057600080fd5b50516105bd5760405162461bcd60e51b8152600401808060200182810382526054815260200180610ae26054913960600191505060405180910390fd5b81156105f7576040805160048152602481019091526020810180516001600160e01b031663153ab50560e01b1790526105f590610775565b505b600080546001600160a01b038581166001600160a01b0319831617835560405160206024820181815286516044840152865193909416946106c49487949093849360649091019290860191908190849084905b8381101561066257818101518382015260200161064a565b50505050905090810190601f16801561068f5780820380516001836020036101000a031916815260200191505b5060408051601f198184030181529190526020810180516001600160e01b0316630adccee560e31b1790529250610775915050565b50600054604080516001600160a01b038085168252909216602083015280517fd604de94d45953f9138079ec1b82d533cb2160c906d1076d1f7ed54befbca97a9281900390910190a150505050565b61071b610838565b6107565760405162461bcd60e51b8152600401808060200182810382526039815260200180610b366039913960400191505060405180910390fd5b6107618383836104e9565b505050565b6000546001600160a01b031681565b606060006060306001600160a01b0316846040518082805190602001908083835b602083106107b55780518252601f199092019160209182019101610796565b6001836020036101000a0380198251168184511680821785525050505050509050019150506000604051808303816000865af19150503d8060008114610817576040519150601f19603f3d011682016040523d82523d6000602084013e61081c565b606091505b50915091506000821415610831573d60208201fd5b9392505050565b6000805460408051600481526024810182526020810180516001600160e01b0316635fe3b56760e01b1781529151815185946060946001600160a01b039091169392918291908083835b602083106108a15780518252601f199092019160209182019101610882565b6001836020036101000a038019825116818451168082178552505050505050905001915050600060405180830381855afa9150503d8060008114610901576040519150601f19603f3d011682016040523d82523d6000602084013e610906565b606091505b50915091508161091557600080fd5b600081806020019051602081101561092c57600080fd5b5051604080516303e1469160e61b8152905191925082916001600160a01b0383169163f851a440916004808301926020929190829003018186803b15801561097357600080fd5b505afa158015610987573d6000803e3d6000fd5b505050506040513d602081101561099d57600080fd5b50516001600160a01b031633148015610a175750806001600160a01b0316630a755ec26040518163ffffffff1660e01b815260040160206040518083038186803b1580156109ea57600080fd5b505afa1580156109fe573d6000803e3d6000fd5b505050506040513d6020811015610a1457600080fd5b50515b80610aa157503373a731585ab05fc9f83555cf9bff8f58ee94e18f85148015610aa15750806001600160a01b0316632f1069ba6040518163ffffffff1660e01b815260040160206040518083038186803b158015610a7457600080fd5b505afa158015610a88573d6000803e3d6000fd5b505050506040513d6020811015610a9e57600080fd5b50515b9450505050509056fe43457263323044656c656761746f723a66616c6c6261636b3a2063616e6e6f742073656e642076616c756520746f2066616c6c6261636b4e657720696d706c656d656e746174696f6e20636f6e74726163742061646472657373206e6f742077686974656c6973746564206f7220616c6c6f7752657369676e206d75737420626520696e7665727465642e43457263323044656c656761746f723a3a5f736574496d706c656d656e746174696f6e3a2043616c6c6572206d7573742062652061646d696ea265627a7a72315820526f364572ad2ed321a1c1688fb40559048cdc371b513b9e49f441c23e24128964736f6c634300051100324e657720696d706c656d656e746174696f6e20636f6e74726163742061646472657373206e6f742077686974656c6973746564206f7220616c6c6f7752657369676e206d75737420626520696e7665727465642e";
        cErc20DelegatorCreationCode = abi.encodePacked(cErc20DelegatorCreationCode, constructorData);
        bytes32 salt = keccak256(abi.encodePacked(msg.sender, underlying, block.number));
        address proxy;

        assembly {
            proxy := create2(0, add(cErc20DelegatorCreationCode, 32), mload(cErc20DelegatorCreationCode), salt)
            if iszero(extcodesize(proxy)) {
                revert(0, "Failed to deploy CErc20.")
            }
        }

        return proxy;
    }

    /**
     * @dev Whitelisted Comptroller implementation contract addresses for each existing implementation.
     */
    mapping(address => mapping(address => bool)) public comptrollerImplementationWhitelist;

    /**
     * @dev Adds/removes Comptroller implementations to the whitelist.
     * @param oldImplementations The old `Comptroller` implementation addresses to upgrade from for each `newImplementations` to upgrade to.
     * @param newImplementations Array of `Comptroller` implementations to be whitelisted/unwhitelisted.
     * @param statuses Array of whitelist statuses corresponding to `implementations`.
     */
    function _editComptrollerImplementationWhitelist(address[] calldata oldImplementations, address[] calldata newImplementations, bool[] calldata statuses) external onlyOwner {
        require(newImplementations.length > 0 && newImplementations.length == oldImplementations.length && newImplementations.length == statuses.length, "No Comptroller implementations supplied or array lengths not equal.");
        for (uint256 i = 0; i < newImplementations.length; i++) comptrollerImplementationWhitelist[oldImplementations[i]][newImplementations[i]] = statuses[i];
    }

    /**
     * @dev Whitelisted CErc20Delegate implementation contract addresses and `allowResign` values for each existing implementation.
     */
    mapping(address => mapping(address => mapping(bool => bool))) public cErc20DelegateWhitelist;

    /**
     * @dev Adds/removes CErc20Delegate implementations to the whitelist.
     * @param oldImplementations The old `CErc20Delegate` implementation addresses to upgrade from for each `newImplementations` to upgrade to.
     * @param newImplementations Array of `CErc20Delegate` implementations to be whitelisted/unwhitelisted.
     * @param allowResign Array of `allowResign` values corresponding to `newImplementations` to be whitelisted/unwhitelisted.
     * @param statuses Array of whitelist statuses corresponding to `newImplementations`.
     */
    function _editCErc20DelegateWhitelist(address[] calldata oldImplementations, address[] calldata newImplementations, bool[] calldata allowResign, bool[] calldata statuses) external onlyOwner {
        require(newImplementations.length > 0 && newImplementations.length == oldImplementations.length && newImplementations.length == allowResign.length && newImplementations.length == statuses.length, "No CErc20Delegate implementations supplied or array lengths not equal.");
        for (uint256 i = 0; i < newImplementations.length; i++) cErc20DelegateWhitelist[oldImplementations[i]][newImplementations[i]][allowResign[i]] = statuses[i];
    }

    /**
     * @dev Whitelisted CEtherDelegate implementation contract addresses and `allowResign` values for each existing implementation.
     */
    mapping(address => mapping(address => mapping(bool => bool))) public cEtherDelegateWhitelist;

    /**
     * @dev Adds/removes CEtherDelegate implementations to the whitelist.
     * @param oldImplementations The old `CEtherDelegate` implementation addresses to upgrade from for each `newImplementations` to upgrade to.
     * @param newImplementations Array of `CEtherDelegate` implementations to be whitelisted/unwhitelisted.
     * @param allowResign Array of `allowResign` values corresponding to `newImplementations` to be whitelisted/unwhitelisted.
     * @param statuses Array of whitelist statuses corresponding to `newImplementations`.
     */
    function _editCEtherDelegateWhitelist(address[] calldata oldImplementations, address[] calldata newImplementations, bool[] calldata allowResign, bool[] calldata statuses) external onlyOwner {
        require(newImplementations.length > 0 && newImplementations.length == oldImplementations.length && newImplementations.length == allowResign.length && newImplementations.length == statuses.length, "No CEtherDelegate implementations supplied or array lengths not equal.");
        for (uint256 i = 0; i < newImplementations.length; i++) cEtherDelegateWhitelist[oldImplementations[i]][newImplementations[i]][allowResign[i]] = statuses[i];
    }

    /**
     * @dev Latest Comptroller implementation for each existing implementation.
     */
    mapping(address => address) internal _latestComptrollerImplementation;

    /**
     * @dev Latest Comptroller implementation for each existing implementation.
     */
    function latestComptrollerImplementation(address oldImplementation) external view returns (address) {
        return _latestComptrollerImplementation[oldImplementation] != address(0) ? _latestComptrollerImplementation[oldImplementation] : oldImplementation;
    }

    /**
     * @dev Sets the latest `Comptroller` upgrade implementation address.
     * @param oldImplementation The old `Comptroller` implementation address to upgrade from.
     * @param newImplementation Latest `Comptroller` implementation address.
     */
    function _setLatestComptrollerImplementation(address oldImplementation, address newImplementation) external onlyOwner {
        _latestComptrollerImplementation[oldImplementation] = newImplementation;
    }

    struct CDelegateUpgradeData {
        address implementation;
        bool allowResign;
        bytes becomeImplementationData;
    }

    /**
     * @dev Latest CErc20Delegate implementation for each existing implementation.
     */
    mapping(address => CDelegateUpgradeData) public _latestCErc20Delegate;

    /**
     * @dev Latest CEtherDelegate implementation for each existing implementation.
     */
    mapping(address => CDelegateUpgradeData) public _latestCEtherDelegate;

    /**
     * @dev Latest CErc20Delegate implementation for each existing implementation.
     */
    function latestCErc20Delegate(address oldImplementation) external view returns (address, bool, bytes memory) {
        CDelegateUpgradeData memory data = _latestCErc20Delegate[oldImplementation];
        bytes memory emptyBytes;
        return data.implementation != address(0) ? (data.implementation, data.allowResign, data.becomeImplementationData) : (oldImplementation, false, emptyBytes);
    }

    /**
     * @dev Latest CEtherDelegate implementation for each existing implementation.
     */
    function latestCEtherDelegate(address oldImplementation) external view returns (address, bool, bytes memory) {
        CDelegateUpgradeData memory data = _latestCEtherDelegate[oldImplementation];
        bytes memory emptyBytes;
        return data.implementation != address(0) ? (data.implementation, data.allowResign, data.becomeImplementationData) : (oldImplementation, false, emptyBytes);
    }

    /**
     * @dev Sets the latest `CEtherDelegate` upgrade implementation address and data.
     * @param oldImplementation The old `CEtherDelegate` implementation address to upgrade from.
     * @param newImplementation Latest `CEtherDelegate` implementation address.
     * @param allowResign Whether or not `resignImplementation` should be called on the old implementation before upgrade.
     * @param becomeImplementationData Data passed to the new implementation via `becomeImplementation` after upgrade.
     */
    function _setLatestCEtherDelegate(address oldImplementation, address newImplementation, bool allowResign, bytes calldata becomeImplementationData) external onlyOwner {
        _latestCEtherDelegate[oldImplementation] = CDelegateUpgradeData(newImplementation, allowResign, becomeImplementationData);
    }

    /**
     * @dev Sets the latest `CErc20Delegate` upgrade implementation address and data.
     * @param oldImplementation The old `CErc20Delegate` implementation address to upgrade from.
     * @param newImplementation Latest `CErc20Delegate` implementation address.
     * @param allowResign Whether or not `resignImplementation` should be called on the old implementation before upgrade.
     * @param becomeImplementationData Data passed to the new implementation via `becomeImplementation` after upgrade.
     */
    function _setLatestCErc20Delegate(address oldImplementation, address newImplementation, bool allowResign, bytes calldata becomeImplementationData) external onlyOwner {
        _latestCErc20Delegate[oldImplementation] = CDelegateUpgradeData(newImplementation, allowResign, becomeImplementationData);
    }
}
