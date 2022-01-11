// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IAnglePoolStorage.sol";

contract AnglePoolStorage is IAnglePoolStorage {

    IStableMasterFront constant public stableMasterFront = IStableMasterFront(0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87);

    mapping (address => address) public tokenToPoolManager;

    function addPoolManagers(address[] calldata poolManagers) public {
        for (uint i = 0; i < poolManagers.length; i++) {
            (address token,,,,,,,,) = stableMasterFront.collateralMap(poolManagers[i]);
            tokenToPoolManager[token] = poolManagers[i];
        }
    }
}