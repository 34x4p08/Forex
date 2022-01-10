// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./IStableMasterFront.sol";

interface IPerpetualManager {
    function totalHedgeAmount() external view returns(uint256);
}

library AngleUtils {
    uint public constant BASE_PARAMS = 1e9;

    function _computeFeeMint(uint256 amount, IStableMasterFront.MintBurnData memory feeData, uint256 stocksUsers, address perpetualManager) internal view returns (uint256 feeMint) {
        uint64 feeMint64;
        if (feeData.xFeeMint.length == 1) {
            // This is done to avoid an external call in the case where the fees are constant regardless of the collateral
            // ratio
            feeMint64 = feeData.yFeeMint[0];
        } else {
            uint64 hedgeRatio = _computeHedgeRatio(amount + stocksUsers, IPerpetualManager(perpetualManager).totalHedgeAmount(), feeData.targetHAHedge);
            // Computing the fees based on the spread
            feeMint64 = _piecewiseLinear(hedgeRatio, feeData.xFeeMint, feeData.yFeeMint);
        }
        // Fees could in some occasions depend on other factors like collateral ratio
        // Keepers are the ones updating this part of the fees
        feeMint = (feeMint64 * feeData.bonusMalusMint) / BASE_PARAMS;
    }

    function _computeFeeBurn(uint256 amount, IStableMasterFront.MintBurnData memory feeData, uint256 stocksUsers, address perpetualManager) internal view returns (uint256 feeBurn) {
        uint64 feeBurn64;
        if (feeData.xFeeBurn.length == 1) {
            // Avoiding an external call if fees are constant
            feeBurn64 = feeData.yFeeBurn[0];
        } else {
            uint64 hedgeRatio = _computeHedgeRatio(stocksUsers - amount, IPerpetualManager(perpetualManager).totalHedgeAmount(), feeData.targetHAHedge);
            // Computing the fees based on the spread
            feeBurn64 = _piecewiseLinear(hedgeRatio, feeData.xFeeBurn, feeData.yFeeBurn);
        }
        // Fees could in some occasions depend on other factors like collateral ratio
        // Keepers are the ones updating this part of the fees
        feeBurn = (feeBurn64 * feeData.bonusMalusBurn) / BASE_PARAMS;
    }

    function _computeHedgeRatio(uint256 newStocksUsers, uint256 tha, uint64 thaHedge) internal pure returns (uint64 ratio) {
        newStocksUsers = (thaHedge * newStocksUsers) / BASE_PARAMS;
        if (newStocksUsers > tha) ratio = uint64((tha * BASE_PARAMS) / newStocksUsers);
        else ratio = uint64(BASE_PARAMS);
    }

    function _piecewiseLinear(
        uint64 x,
        uint64[] memory xArray,
        uint64[] memory yArray
    ) internal pure returns (uint64) {
        if (x >= xArray[xArray.length - 1]) {
            return yArray[xArray.length - 1];
        } else if (x <= xArray[0]) {
            return yArray[0];
        } else {
            uint256 lower;
            uint256 upper = xArray.length - 1;
            uint256 mid;
            while (upper - lower > 1) {
                mid = lower + (upper - lower) / 2;
                if (xArray[mid] <= x) {
                    lower = mid;
                } else {
                    upper = mid;
                }
            }
            if (yArray[upper] > yArray[lower]) {
                // There is no risk of overflow here as in the product of the difference of `y`
                // with the difference of `x`, the product is inferior to `BASE_PARAMS**2` which does not
                // overflow for `uint64`
                return
                yArray[lower] +
                ((yArray[upper] - yArray[lower]) * (x - xArray[lower])) /
                (xArray[upper] - xArray[lower]);
            } else {
                return
                yArray[lower] -
                ((yArray[lower] - yArray[upper]) * (x - xArray[lower])) /
                (xArray[upper] - xArray[lower]);
            }
        }
    }
}
