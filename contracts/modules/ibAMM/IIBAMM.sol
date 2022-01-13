// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IIBAMM {
    function quote(address to, uint amount) external view returns (uint);
    function swap(address to, uint amount, uint minOut) external returns (bool);
}