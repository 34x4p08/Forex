// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import "./ICurvePool.sol";
import "../../utils/Utils.sol";

/// no slippage checks, no intakes and no outputs, only internal swap logic
library CurveSwaps {
    using Utils for IERC20;

    function quote(int128 indexIn, int128 indexOut, address pool, uint amount) external view returns (uint) {
        return ICurvePool(pool).get_dy(indexIn, indexOut, amount);
    }

    function quoteUnderlying(int128 indexIn, int128 indexOut, address pool, uint amount) external view returns (uint) {
        return ICurvePool(pool).get_dy_underlying(indexIn, indexOut, amount);
    }

    function swap(address assetIn, int128 indexIn, int128 indexOut, address pool, uint amount) external returns (uint) {
        IERC20(assetIn).ensureMaxApproval(pool, amount);
        return ICurvePool(pool).exchange(indexIn, indexOut, amount, 0);
    }

    function swapUnderlying(address assetIn, int128 indexIn, int128 indexOut, address pool, uint amount) external returns (uint) {
        IERC20(assetIn).ensureMaxApproval(pool, amount);
        return ICurvePool(pool).exchange_underlying(indexIn, indexOut, amount, 0);
    }
}