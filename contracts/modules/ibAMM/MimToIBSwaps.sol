// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import "./IIBAMM.sol";
import "../../utils/Utils.sol";

/// no slippage checks, no intakes and no outputs, only internal swap logic
library MimToIBSwaps {
    using Utils for IERC20;

    IIBAMM constant ibAMM =  IIBAMM(0x8338Aa899fB3168598D871Edc1FE2B4F0Ca6BBEF);

    address constant mim = 0x99D8a9C45b2ecA8864373A26D1459e3Dff1e17F3;

    function quote(address ibOut, uint amount) external view returns (uint) {
        return ibAMM.quote(ibOut, amount);
    }

    function swap(address ibOut, uint amount) external returns (uint) {
        IERC20(mim).ensureMaxApproval(address(ibAMM), amount);
        uint before = IERC20(ibOut).balanceOf(address(this));
        require(ibAMM.swap(ibOut, amount, 0), "!swap");
        return IERC20(ibOut).balanceOf(address(this)) - before;
    }
}