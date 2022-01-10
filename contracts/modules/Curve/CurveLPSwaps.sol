// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import "../Synthetix/SynthIBSwaps.sol";
import "./ICurvePool.sol";
import "../../utils/Utils.sol";

/// no slippage checks, no intakes and no outputs, only internal swap logic
library CurveLPSwaps {
    using SafeERC20 for IERC20;
    using Utils for IERC20;

    IPoolStorage public constant poolStorage = IPoolStorage(0x123456787B892f0Aa394AfcC2d7a41a9446f50F7);

    function quoteLPToSynth(address lpIn, address synthOut, uint amount) public view returns (uint amountReceived) {
        (int128 synthIndex, address synth) = _getSynth(lpIn);
        amountReceived = ICurvePool(lpIn).calc_withdraw_one_coin(amount, synthIndex);
        if (synth != synthOut) {
            amountReceived = SynthIBSwaps.quoteSynth(synth, synthOut, amountReceived);
        }
    }

    function quoteSynthToLP(address synthIn, address lpOut, uint amount) public view returns (uint) {
        (int128 _swapSynthIndex, address _swapSynth) = _getSynth(lpOut);
        uint[2] memory amounts;
        amounts[uint(int(_swapSynthIndex))] =
            synthIn == _swapSynth ? amount : SynthIBSwaps.quoteSynth(synthIn, _swapSynth, amount);
        return ICurvePool(lpOut).calc_token_amount(amounts, true);
    }

    function quoteLPToIB(address lpIn, address ibOut, uint amount) external view returns (uint amountReceived) {
        (int128 synthIndex, address synth) = _getSynth(lpIn);
        if (ICurvePool(lpIn).coins(synthIndex == 0 ? 1 : 0) == ibOut) {
            return ICurvePool(lpIn).calc_withdraw_one_coin(amount, synthIndex == 0 ? int128(1) : int128(0));
        }
        amountReceived = ICurvePool(lpIn).calc_withdraw_one_coin(amount, synthIndex);
        return SynthIBSwaps.quoteSynthToIB(synth, ibOut, amountReceived);
    }

    function quoteIBToLP(address ibIn, address lpOut, uint amount) public view returns (uint amountReceived) {
        (int128 _swapSynthIndex, address _swapSynth) = _getSynth(lpOut);
        uint[2] memory amounts;
        if (ICurvePool(lpOut).coins(_swapSynthIndex == 0 ? 1 : 0) == ibIn) {
            amounts[_swapSynthIndex == 0 ? 1 : 0] = amount;
        } else {
            amounts[uint(int(_swapSynthIndex))] = SynthIBSwaps.quoteIBToSynth(ibIn, _swapSynth, amount);
        }
        amountReceived = ICurvePool(lpOut).calc_token_amount(amounts, true);
    }

    // Quote LP to LP 
    function quoteLP(address lpIn, address lpOut, uint amount) external view returns (uint amountReceived) {
        if (lpIn == lpOut) return amount;
        (, address _swapSynth) = _getSynth(lpOut);
        amountReceived = quoteLPToSynth(lpIn, _swapSynth, amount);
        amountReceived = quoteSynthToLP(_swapSynth, lpOut, amountReceived);
    }

    // Trade LP to synth
    function swapLPToSynth(address lpIn, address synthOut, uint amount) public returns (uint amountReceived) {
        (int128 _swapSynthIndex, address _swapSynth) = _getSynth(lpIn);
        amountReceived = ICurvePool(lpIn).remove_liquidity_one_coin(amount, _swapSynthIndex, 0);
        if (_swapSynth != synthOut) {
            amountReceived = SynthIBSwaps.swapSynth(_swapSynth, synthOut, amountReceived);
        }
    }

    // Trade synth to LP
    function swapSynthToLP(address synthIn, address lpOut, uint amount) public returns (uint amountReceived) {
        (int128 _swapSynthIndex, address _swapSynth) = _getSynth(lpOut);
        uint[2] memory amounts;
        amounts[uint(int(_swapSynthIndex))] = SynthIBSwaps.swapSynth(synthIn, _swapSynth, amount);
        IERC20(_swapSynth).ensureExactApproval(lpOut, amounts[uint(int(_swapSynthIndex))]);
        amountReceived = ICurvePool(lpOut).add_liquidity(amounts, 0);
    }

    // Trade ib to LP
    function swapIBToLP(address ibIn, address lpOut, uint amount) public returns (uint amountReceived) {
        (int128 synthIndex, address synth) = _getSynth(lpOut);
        uint[2] memory amounts;
        if (poolStorage.pools(ibIn) == lpOut) {
            amounts[synthIndex == 0 ? 1 : 0] = amount;
            IERC20(ibIn).ensureExactApproval(lpOut, amount);
        } else {
            amounts[uint(int(synthIndex))] = SynthIBSwaps.swapIBToSynth(ibIn, synth, amount);
            IERC20(synth).ensureExactApproval(lpOut, amounts[uint(int(synthIndex))]);
        }
        amountReceived = ICurvePool(lpOut).add_liquidity(amounts, 0);
    }

    // Trade LP to ib
    function swapLPToIB(address lpIn, address ibOut, uint amount) external returns (uint amountReceived) {
        (int128 _swapSynthIndex, address _swapSynth) = _getSynth(lpIn);
        if (poolStorage.synthToIB(_swapSynth) == ibOut) {
            amountReceived = ICurvePool(lpIn).remove_liquidity_one_coin(amount, _swapSynthIndex == 0 ? int128(1) : int128(0), 0);
        } else {
            amountReceived = ICurvePool(lpIn).remove_liquidity_one_coin(amount, _swapSynthIndex, 0);
            amountReceived = SynthIBSwaps.swapSynthToIB(_swapSynth, ibOut, amountReceived);
        }
    }

    // Trade LP to other LP
    function swapLP(address lpIn, address lpOut, uint amount) external returns (uint amountReceived) {
        if (lpIn == lpOut) return amount;
        (, address _swapSynth) = _getSynth(lpOut);
        amountReceived = swapLPToSynth(lpIn, _swapSynth, amount);
        amountReceived = swapSynthToLP(_swapSynth, lpOut, amountReceived);
    }

    function _getSynth(address pool) internal view returns (int128, address) {
        address coin0 = ICurvePool(pool).coins(0);
        address coin1 = ICurvePool(pool).coins(1);
        if (poolStorage.pools(coin0) == pool) {
            return (int128(1), coin1);
        }
        if (poolStorage.pools(coin1) == pool) {
            return (int128(0), coin0);
        }
        revert("pool not found");
    }
}