// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

// Staking in sSpell inspired by Chef Nomi's SushiBar - MIT license (originally WTFPL)
// modified by BoringCrypto for DictatorDAO
interface sSpellV1 is IERC20Upgradeable {
    function token() external view returns (IERC20Upgradeable);
    function burn(address to, uint256 shares) external returns (bool);
}
