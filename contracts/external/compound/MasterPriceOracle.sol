pragma solidity 0.6.12;

import "./PriceOracle.sol";

interface MasterPriceOracle is PriceOracle {
    function oracles(address underlying) external view returns (address);
}
