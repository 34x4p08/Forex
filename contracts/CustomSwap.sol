// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import "./FunctionPointers.sol";
import "./utils/BytesLib.sol";

contract CustomSwap is FunctionPointers {
    using BytesLib for bytes;

    function multicall(bytes[] calldata data) external returns (uint) {
        bytes memory lastResult;
        for (uint256 i = 0; i < data.length; i++) {
            bytes memory stepData = i == 0 ? data[i] : data[i].concat(lastResult);
            (bool success, bytes memory result) = address(this).delegatecall(stepData);

            if (!success) {
                // Next 5 lines from https://ethereum.stackexchange.com/a/83577
                if (result.length < 68) revert();
                assembly {
                    result := add(result, 0x04)
                }
                revert(abi.decode(result, (string)));
            }

            lastResult = result;
        }
        return lastResult.toUint256(0);
    }
}
