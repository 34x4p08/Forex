// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../../ISynthIBForex.sol";

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import "./ILPAdapter.sol";
import "./ICurvePool.sol";

contract LPAdapter is ILPAdapter {
    using SafeERC20 for IERC20;

    address public immutable forex;

    constructor(address synthIBForex) {
        forex = synthIBForex;
    }

    function quoteLPToSynth(address lpIn, address synthOut, uint amount) public view returns (uint amountReceived) {
        (int128 synthIndex, address synth) = _getSynth(lpIn);
        amountReceived = ICurvePool(lpIn).calc_withdraw_one_coin(amount, synthIndex);
        if (synth != synthOut) {
            amountReceived = ISynthIBForex(forex).quoteSynth(synth, synthOut, amountReceived);
        }
    }

    function quoteSynthToLP(address synthIn, address lpOut, uint amount) public view returns (uint) {
        (int128 synthIndex, address synth) = _getSynth(lpOut);
        uint[2] memory amounts;
        amounts[uint(int(synthIndex))] =
            synthIn == synth ? amount : ISynthIBForex(forex).quoteSynth(synthIn, synth, amount);
        return ICurvePool(lpOut).calc_token_amount(amounts, true);
    }

    function quoteLPToIB(address lpIn, address ibOut, uint amount) external view returns (uint amountReceived) {
        (int128 synthIndex, address synth) = _getSynth(lpIn);
        if (ICurvePool(lpIn).coins(synthIndex == 0 ? 1 : 0) == ibOut) {
            return ICurvePool(lpIn).calc_withdraw_one_coin(amount, synthIndex == 0 ? int128(1) : int128(0));
        }
        amountReceived = ICurvePool(lpIn).calc_withdraw_one_coin(amount, synthIndex);
        return ISynthIBForex(forex).quoteSynthToIB(synth, ibOut, amountReceived);
    }

    function quoteIBToLP(address ibIn, address lpOut, uint amount) public view returns (uint amountReceived) {
        (int128 synthIndex, address synth) = _getSynth(lpOut);
        uint[2] memory amounts;
        if (ICurvePool(lpOut).coins(synthIndex == 0 ? 1 : 0) == ibIn) {
            amounts[synthIndex == 0 ? 1 : 0] = amount;
        } else {
            amounts[uint(int(synthIndex))] = ISynthIBForex(forex).quoteIBToSynth(ibIn, synth, amount);
        }
        amountReceived = ICurvePool(lpOut).calc_token_amount(amounts, true);
    }

    function quoteLPToLP(address lpIn, address lpOut, uint amount) external view returns (uint amountReceived) {
        (int128 synthIndex, address synth) = _getSynth(lpOut);
        amountReceived = quoteLPToSynth(lpIn, synth, amount);
        uint[2] memory amounts;
        amounts[uint(int(synthIndex))] = amountReceived;
        return ICurvePool(lpOut).calc_token_amount(amounts, true);
    }

    // Trade LP to synth
    function swapLPToSynth(address lpIn, address synthOut, uint amount, uint minOut) public returns (uint amountReceived) {
        IERC20(lpIn).safeTransferFrom(msg.sender, address(this), amount);
        (int128 synthIndex, address synth) = _getSynth(lpIn);
        amountReceived = ICurvePool(lpIn).remove_liquidity_one_coin(amount, synthIndex, 0);
        if (synth != synthOut) {
            IERC20(synth).safeApprove(forex, amountReceived);
            amountReceived = ISynthIBForex(forex).swapSynth(synth, synthOut, amountReceived, minOut);
        }
        require(amountReceived > minOut, "slippage");
        IERC20(synthOut).safeTransfer(msg.sender, amountReceived);
    }

    // Trade synth to LP
    function swapSynthToLP(address synthIn, address lpOut, uint amount, uint minOut) public returns (uint amountReceived) {
        IERC20(synthIn).safeTransferFrom(msg.sender, address(this), amount);
        (int128 synthIndex, address synth) = _getSynth(lpOut);

        uint[2] memory amounts;

        if (synthIn == synth) {
            amounts[uint(int(synthIndex))] = amount;
        } else {
            IERC20(synthIn).safeApprove(forex, amount);
            amounts[uint(int(synthIndex))] = ISynthIBForex(forex).swapSynth(synthIn, synth, amount, 0);
        }

        IERC20(synth).safeApprove(lpOut, amounts[uint(int(synthIndex))]);
        amountReceived = ICurvePool(lpOut).add_liquidity(amounts, minOut);

        require(amountReceived > minOut, "slippage");
        IERC20(lpOut).safeTransfer(msg.sender, amountReceived);
    }

    // Trade ib to LP
    function swapIBToLP(address ibIn, address lpOut, uint amount, uint minOut) public returns (uint amountReceived) {
        IERC20(ibIn).safeTransferFrom(msg.sender, address(this), amount);
        (int128 synthIndex, address synth) = _getSynth(lpOut);

        uint[2] memory amounts;

        if (ISynthIBForex(forex).pools(ibIn) == lpOut) {
            amounts[synthIndex == 0 ? 1 : 0] = amount;
            IERC20(ibIn).safeApprove(lpOut, amount);
        } else {
            IERC20(ibIn).safeApprove(forex, amount);
            amounts[uint(int(synthIndex))] = ISynthIBForex(forex).swapIBToSynth(ibIn, synth, amount, 0);
            IERC20(synth).safeApprove(lpOut, amounts[uint(int(synthIndex))]);
        }

        amountReceived = ICurvePool(lpOut).add_liquidity(amounts, 0);

        require(amountReceived > minOut, "slippage");
        IERC20(lpOut).safeTransfer(msg.sender, amountReceived);
    }

    // Trade LP to ib
    function swapLPToIB(address lpIn, address ibOut, uint amount, uint minOut) external returns (uint amountReceived) {
        IERC20(lpIn).safeTransferFrom(msg.sender, address(this), amount);
        (int128 synthIndex, address synth) = _getSynth(lpIn);

        if (ICurvePool(lpIn).coins(synthIndex == 0 ? 1 : 0) == ibOut) {
            amountReceived = ICurvePool(lpIn).remove_liquidity_one_coin(amount, synthIndex == 0 ? int128(1) : int128(0), 0);
        } else {
            amountReceived = ICurvePool(lpIn).remove_liquidity_one_coin(amount, synthIndex, 0);
            IERC20(synth).safeApprove(forex, amountReceived);
            amountReceived = ISynthIBForex(forex).swapSynthToIB(synth, ibOut, amountReceived, 0);
        }
        require(amountReceived > minOut, "slippage");
        IERC20(ibOut).safeTransfer(msg.sender, amountReceived);
    }

    // Trade LP to other LP
    function swapLPToLP(address lpIn, address lpOut, uint amount, uint minOut) external returns (uint amountReceived) {
        if (lpIn == lpOut) return amount;
        (int128 synthIndex, address synth) = _getSynth(lpOut);
        amountReceived = swapLPToSynth(lpIn, synth, amount, 0);

        uint[2] memory amounts;
        amounts[uint(int(synthIndex))] = amountReceived;

        IERC20(synth).safeApprove(lpOut, amountReceived);
        amountReceived = ICurvePool(lpOut).add_liquidity(amounts, minOut);

        require(amountReceived > minOut, "slippage");
        IERC20(lpOut).safeTransfer(msg.sender, amountReceived);
    }

    function _getSynth(address pool) internal view returns (int128, address) {
        address coin0 = ICurvePool(pool).coins(0);
        address coin1 = ICurvePool(pool).coins(1);
        if (ISynthIBForex(forex).pools(coin0) == pool) {
            return (int128(1), coin1);
        }
        if (ISynthIBForex(forex).pools(coin1) == pool) {
            return (int128(0), coin0);
        }
        revert("pool not found");
    }
}