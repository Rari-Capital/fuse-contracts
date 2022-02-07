// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.6.12;

abstract contract OlympusV2Staking {
    address public OHM;

    /**
     * @notice redeem sOHM for OHMs
     * @param _to address
     * @param _amount uint
     * @param _trigger bool
     * @param _rebasing bool
     * @return amount_ uint
     */
    function unstake(
        address _to,
        uint256 _amount,
        bool _trigger,
        bool _rebasing
    ) external virtual returns (uint256 amount_);
}
