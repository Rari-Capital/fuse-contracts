pragma solidity 0.6.12;

import "../external/compound/PriceOracle.sol";
import "../external/compound/CToken.sol";
import "../external/compound/CErc20.sol";

import "./BasePriceOracle.sol";

/**
 * @title MasterPriceOracle
 * @notice Use a combination of price oracles.
 * @dev Implements `PriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract MasterPriceOracle is PriceOracle, BasePriceOracle {
    /**
     * @dev Maps underlying token addresses to `PriceOracle` contracts (can be `BasePriceOracle` contracts too).
     */
    mapping(address => PriceOracle) public oracles;

    /**
     * @dev The administrator of this `MasterPriceOracle`.
     */
    address public admin;

    address constant private WETH_ADDRESS = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    /**
     * @dev Controls if `admin` can overwrite existing assignments of oracles to underlying tokens.
     */
    bool public canAdminOverwrite;

    /**
     * @dev Constructor to initialize state variables.
     * @param underlyings The underlying ERC20 token addresses to link to `_oracles`.
     * @param _oracles The `PriceOracle` contracts to be assigned to `underlyings`.
     * @param _admin The admin who can assign oracles to underlying tokens.
     * @param _canAdminOverwrite Controls if `admin` can overwrite existing assignments of oracles to underlying tokens.
     */
    constructor (address[] memory underlyings, PriceOracle[] memory _oracles, address _admin, bool _canAdminOverwrite) public {
        // Input validation
        require(underlyings.length > 0 && underlyings.length == _oracles.length, "Lengths of both arrays must be equal and greater than 0.");

        // Initialize state variables
        for (uint256 i = 0; i < underlyings.length; i++) oracles[underlyings[i]] = _oracles[i];
        admin = _admin;
        canAdminOverwrite = _canAdminOverwrite;
    }

    /**
     * @dev Constructor to map RariFundTokens to RariFundManagers.
     */
    function add(address[] calldata underlyings, PriceOracle[] calldata _oracles) external onlyAdmin {
        // Input validation
        require(underlyings.length > 0 && underlyings.length == _oracles.length, "Lengths of both arrays must be equal and greater than 0.");

        // Assign oracles to underlying tokens
        for (uint256 i = 0; i < underlyings.length; i++) {
            if (!canAdminOverwrite) require(address(oracles[underlyings[i]]) == address(0), "Admin cannot overwrite existing assignments of oracles to underlying tokens.");
            oracles[underlyings[i]] = _oracles[i];
        }
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
     * @dev Changes ability of admin to overwrite to false. This is irreversible!
     */
    function revokeCanAdminOverwrite() external onlyAdmin {
        canAdminOverwrite = false;
        emit RevokeCanAdminOverwrite(msg.sender, false);
    }

    /**
     * @dev Event emitted when `canAdminOverwrite` is changed.
     */
    event RevokeCanAdminOverwrite(address admin, bool canOverwrite);

    /**
     * @dev Modifier that checks if `msg.sender == admin`.
     */
    modifier onlyAdmin {
        require(msg.sender == admin, "Sender is not the admin.");
        _;
    }

    /**
     * @dev Returns the price in ETH of the token underlying `cToken` (implements `PriceOracle`).
     */
    function getUnderlyingPrice(CToken cToken) external override view returns (uint) {
        // Return 1e18 for ETH
        if (cToken.isCEther()) return 1e18;

        // Get underlying ERC20 token address
        address underlying = address(CErc20(address(cToken)).underlying());

        // Return 1e18 for WETH
        if (underlying == WETH_ADDRESS) return 1e18;

        // Get underlying price from assigned oracle
        return oracles[underlying].getUnderlyingPrice(cToken);
    }

    /**
     * @dev Attempts to return the price in ETH of `underlying` (implements `BasePriceOracle`).
     */
    function price(address underlying) external override view returns (uint) {
        // Return 1e18 for WETH
        if (underlying == WETH_ADDRESS) return 1e18;

        // Get underlying price from assigned oracle
        return BasePriceOracle(address(oracles[underlying])).price(underlying);
    }
}
