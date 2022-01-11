// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import "./ICurvePool.sol";
import "../../utils/Utils.sol";

/// no slippage checks, no intakes and no outputs, only internal swap logic
library CurveSwaps {
    using Utils for IERC20;

    function quote(address assetIn, address assetOut, address pool, uint amount) external view returns (uint) {
        (int128 indexIn, int128 indexOut) = _getCoinIndexes(pool, assetIn, assetOut);
        return ICurvePool(pool).get_dy(indexIn, indexOut, amount);
    }

    function swap(address assetIn, address assetOut, address pool, uint amount) external returns (uint) {
        (int128 indexIn, int128 indexOut) = _getCoinIndexes(pool, assetIn, assetOut);
        IERC20(assetIn).ensureExactApproval(pool, amount);
        return ICurvePool(pool).exchange(indexIn, indexOut, amount, 0, address(this));
    }

    function _getCoinIndexes(address pool, address coinIn, address coinOut) internal view returns (int128, int128) {
        address _coin0 = ICurvePool(pool).coins(0);
        address _coin1 = ICurvePool(pool).coins(1);
        if (_coin0 == coinIn && _coin1 == coinOut) {
            return (int128(0), int128(1));
        } else if(_coin0 == coinOut && _coin1 == coinIn) {
            return (int128(1), int128(0));
        }
        revert("incorrect pool");
    }
}