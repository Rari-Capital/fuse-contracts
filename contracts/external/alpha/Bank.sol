// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface Bank is IERC20Upgradeable {
    /// @dev Return the total ETH entitled to the token holders. Be careful of unaccrued interests.
    function totalETH() external view returns (uint256);
}
