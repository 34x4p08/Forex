// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ISynthIBPoolStorage {
    function ibToSynth ( address ) external view returns ( address );
    function synthToIB ( address ) external view returns ( address );
    function pools ( address ) external view returns ( address );
}