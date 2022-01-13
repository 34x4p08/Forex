// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import "./utils/BytesLib.sol";

import "hardhat/console.sol";

contract CustomSwap {
    using BytesLib for bytes;
    using SafeERC20 for IERC20;

    /// change this function to `view` in the ABI
    function viewMulticall(address[] calldata contracts, bytes[] calldata data) external returns (uint) {
        bytes memory lastResult;
        bytes memory stepData;
        for (uint256 i = 0; i < data.length; i++) {
            address contractToCall = contracts[i];
            // intake
            if (i == 0) {
                stepData = data[i];
            } else {
                stepData = data[i].concat(lastResult);
            }
            (bool success, bytes memory result) = address(contractToCall).delegatecall(stepData);

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

    function multicall(address[] calldata contracts, bytes[] calldata data, uint minOut) external returns (uint) {
        bytes memory lastResult;
        bytes memory stepData;
        for (uint256 i = 0; i < data.length; i++) {
            address contractToCall = contracts[i];
            // intake
            if (i == 0) {
                stepData = data[i];
                address assetIn = stepData.slice(4, 32).toAddress(12);
                uint amount = stepData.toUint256(stepData.length - 32);
                IERC20(assetIn).safeTransferFrom(msg.sender, address(this), amount);
            } else {
                stepData = data[i].concat(lastResult);
            }
            (bool success, bytes memory result) = address(contractToCall).delegatecall(stepData);

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
        uint _result = lastResult.toUint256(0);
        require(_result > minOut, "slippage");
        address lastAssetOut = stepData.slice(36, 32).toAddress(12);
        IERC20(lastAssetOut).safeTransfer(msg.sender, _result);
        return _result;
    }
}
