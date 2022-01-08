// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../../interfaces/ISynthIBForex.sol";

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

interface CurvePool {
    function remove_liquidity_one_coin(uint256, int128, uint256) external returns (uint256);
    function calc_withdraw_one_coin(uint256, int128) external view returns (uint256);
    function calc_token_amount(uint256[2] calldata, bool) external view returns (uint256);
    function add_liquidity(uint256[2] calldata, uint256) external returns (uint256);
    function coins(uint) external view returns (address);
}

contract LPAdapter {
    using SafeERC20 for IERC20;

    ISynthIBForex public immutable forex;

    constructor(address synthIBForex) {
        forex = ISynthIBForex(synthIBForex);
    }

    function quoteLPToSynth(address lpIn, address synthOut, uint amount) public view returns (uint amountReceived) {
        (int128 synthIndex, address synth) = _getSynth(lpIn);
        amountReceived = CurvePool(lpIn).calc_withdraw_one_coin(amount, synthIndex);
        if (synth != synthOut) {
            amountReceived = forex.quoteSynth(synth, synthOut, amountReceived);
        }
    }

    function quoteSynthToLP(address synthIn, address lpOut, uint amount) public view returns (uint amountReceived) {
        (int128 synthIndex, address synth) = _getSynth(lpOut);
        amountReceived = forex.quoteSynth(synthIn, synth, amount);
        uint[2] memory amounts;
        amounts[uint(int(synthIndex))] = amountReceived;
        amountReceived = CurvePool(lpOut).calc_token_amount(amounts, true);
    }

    function quoteLPToIB(address lpIn, address ibOut, uint amount) external view returns (uint amountReceived) {
        (int128 synthIndex, address synth) = _getSynth(lpIn);
        amountReceived = CurvePool(lpIn).calc_withdraw_one_coin(amount, synthIndex);
        return forex.quoteSynthToIB(synth, ibOut, amountReceived);
    }

    function quoteIBToLP(address ibIn, address lpOut, uint amount) public view returns (uint amountReceived) {
        (int128 synthIndex, address synth) = _getSynth(lpOut);
        amountReceived = forex.quoteIBToSynth(ibIn, synth, amount);
        uint[2] memory amounts;
        amounts[uint(int(synthIndex))] = amountReceived;
        amountReceived = CurvePool(lpOut).calc_token_amount(amounts, true);
    }

    function quoteLPToLP(address lpIn, address lpOut, uint amount) external view returns (uint amountReceived) {
        (int128 synthIndex, address synth) = _getSynth(lpOut);
        amountReceived = quoteLPToSynth(lpIn, synth, amount);
        uint[2] memory amounts;
        amounts[uint(int(synthIndex))] = amountReceived;
        return CurvePool(lpOut).calc_token_amount(amounts, true);
    }

    // Trade LP to synth
    function swapLPToSynth(address lpIn, address synthOut, uint amount, uint minOut) public returns (uint amountReceived) {
        IERC20(lpIn).safeTransferFrom(msg.sender, address(this), amount);
        (int128 synthIndex, address synth) = _getSynth(lpIn);
        amountReceived = CurvePool(lpIn).remove_liquidity_one_coin(amount, synthIndex, 0);
        if (synth != synthOut) {
            IERC20(synth).safeApprove(address(forex), type(uint).max);
            amountReceived = forex.swapSynth(synth, synthOut, amountReceived, minOut);
        }
        require(amountReceived > minOut, "slippage");
        IERC20(synthOut).safeTransfer(msg.sender, amountReceived);
    }

    // Trade synth to LP
    function swapSynthToLP(address synthIn, address lpOut, uint amount, uint minOut) public returns (uint amountReceived) {
        IERC20(synthIn).safeTransferFrom(msg.sender, address(this), amount);
        (int128 synthIndex, address synth) = _getSynth(lpOut);
        IERC20(synthIn).safeApprove(address(forex), type(uint).max);
        amountReceived = forex.swapSynth(synthIn, synth, amount, 0);

        uint[2] memory amounts;
        amounts[uint(int(synthIndex))] = amountReceived;
        IERC20(synth).safeApprove(lpOut, amountReceived);
        amountReceived = CurvePool(lpOut).add_liquidity(amounts, minOut);

        require(amountReceived > minOut, "slippage");
        IERC20(lpOut).safeTransfer(msg.sender, amountReceived);
    }

    // Trade LP to ib
    function swapLPToIB(address lpIn, address ibOut, uint amount, uint minOut) external returns (uint amountReceived) {
        IERC20(lpIn).safeTransferFrom(msg.sender, address(this), amount);
        (int128 synthIndex, address synth) = _getSynth(lpIn);
        amountReceived = CurvePool(lpIn).remove_liquidity_one_coin(amount, synthIndex, 0);
        IERC20(synth).safeApprove(address(forex), type(uint).max);
        amountReceived = forex.swapSynthToIB(synth, ibOut, amountReceived, minOut);
        IERC20(ibOut).safeTransfer(msg.sender, amountReceived);
    }

    // Trade LP to other LP
    function swapLPToLP(address lpIn, address lpOut, uint amount, uint minOut) external returns (uint amountReceived) {
        (int128 synthIndex, address synth) = _getSynth(lpOut);
        amountReceived = swapLPToSynth(lpIn, synth, amount, 0);

        uint[2] memory amounts;
        amounts[uint(int(synthIndex))] = amountReceived;

        IERC20(synth).safeApprove(lpOut, amountReceived);
        amountReceived = CurvePool(lpOut).add_liquidity(amounts, minOut);

        require(amountReceived > minOut, "slippage");
        IERC20(lpOut).safeTransfer(msg.sender, amountReceived);
    }

    function _getSynth(address pool) internal view returns (int128, address) {
        address coin0 = CurvePool(pool).coins(0);
        address coin1 = CurvePool(pool).coins(1);
        if (forex.pools(coin0) == pool) {
            return (int128(1), coin1);
        }
        if (forex.pools(coin1) == pool) {
            return (int128(0), coin0);
        }
        revert("pool not found");
    }
}