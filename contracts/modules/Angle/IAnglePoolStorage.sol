// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IStableMasterFront.sol";

interface IAnglePoolStorage {
    function tokenToPoolManager ( address ) external view returns ( address );
}