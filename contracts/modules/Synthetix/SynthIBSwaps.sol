// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import "./ISynthIBPoolStorage.sol";
import "../Curve/CurveSwaps.sol";
import "../../utils/Utils.sol";

interface SynthExchanger {
    function exchangeAtomically(
        bytes32 sourceCurrencyKey,
        uint sourceAmount,
        bytes32 destinationCurrencyKey,
        bytes32 trackingCode
    ) external returns (uint amountReceived);
}

interface SynthExchangeViewer {
    function getAmountsForAtomicExchange(
        uint sourceAmount,
        bytes32 sourceCurrencyKey,
        bytes32 destinationCurrencyKey
    )
    external
    view
    returns (
        uint amountReceived,
        uint fee,
        uint exchangeFeeRate
    );
}

/// no slippage checks, no intakes and no outputs, only internal swap logic
library SynthIBSwaps {
    using SafeERC20 for IERC20;
    using Utils for IERC20;

    SynthExchanger public constant sex = SynthExchanger(0xDC01020857afbaE65224CfCeDb265d1216064c59);
    SynthExchangeViewer public constant sexViewer = SynthExchangeViewer(0x2A417C61B8062363e4ff50900779463b45d235f6);
    ISynthIBPoolStorage public constant poolStorage = ISynthIBPoolStorage(0x123456787B892f0Aa394AfcC2d7a41a9446f50F7);

    // Quote synth to synth
    function quoteSynth(address synthIn, address synthOut, uint amount) external view returns (uint amountReceived) {
        if (synthIn == synthOut) return amount;
        (amountReceived,,) = sexViewer.getAmountsForAtomicExchange(amount, synthId(synthIn), synthId(synthOut));
    }

    // Quote ib to ib
    function quoteIB(address ibIn, address ibOut, uint amount) external view returns (uint amountReceived) {
        if (ibIn == ibOut) return amount;
        address _swapSynth = poolStorage.ibToSynth(ibOut);
        amount = quoteIBToSynth(ibIn, _swapSynth, amount);
        amountReceived = quoteSynthToIB(_swapSynth, ibOut, amount);
    }

    // Quote synth to ib
    function quoteSynthToIB(address synthIn, address ibOut, uint amount) public view returns (uint amountReceived) {
        address _swapSynth = poolStorage.ibToSynth(ibOut);
        if (_swapSynth != synthIn) {
            (amount,,) = sexViewer.getAmountsForAtomicExchange(amount, synthId(synthIn), synthId(_swapSynth));
        }
        return CurveSwaps.quote(_swapSynth, ibOut, poolStorage.pools(ibOut), amount);
    }

    // Quote ib to synth
    function quoteIBToSynth(address ibIn, address synthOut, uint amount) public view returns (uint amountReceived) {
        address _swapSynth = poolStorage.ibToSynth(ibIn);
        amountReceived = CurveSwaps.quote(ibIn, _swapSynth, poolStorage.pools(ibIn), amount);
        if (_swapSynth != synthOut) {
            (amountReceived,,) = sexViewer.getAmountsForAtomicExchange(amountReceived, synthId(poolStorage.ibToSynth(ibIn)), synthId(synthOut));
        }
    }

    // Trade synth to synth
    function swapSynth(address synthIn, address synthOut, uint amount) public returns (uint amountReceived) {
        if (synthIn == synthOut) return amount;
        IERC20(synthIn).ensureMaxApproval(address(sex), amount);
        amountReceived = sex.exchangeAtomically(synthId(synthIn), amount, synthId(synthOut), "Forex");
    }

    // Trade synth to ib
    function swapSynthToIB(address synthIn, address ibOut, uint amount) public returns (uint) {
        address _swapSynth = poolStorage.ibToSynth(ibOut);
        if (_swapSynth != synthIn) {
            IERC20(synthIn).ensureMaxApproval(address(sex), amount);
            amount = sex.exchangeAtomically(synthId(synthIn), amount, synthId(_swapSynth), "Forex");
        }
        return CurveSwaps.swap(_swapSynth, ibOut, poolStorage.pools(ibOut), amount);
    }

    // Trade ib to synth
    function swapIBToSynth(address ibIn, address synthOut, uint amount) public returns (uint amountReceived) {
        address _swapSynth = poolStorage.ibToSynth(ibIn);
        amountReceived = CurveSwaps.swap(ibIn, _swapSynth, poolStorage.pools(ibIn), amount);
        if (_swapSynth != synthOut) {
            IERC20(_swapSynth).ensureMaxApproval(address(sex), amount);
            amountReceived = sex.exchangeAtomically(synthId(_swapSynth), amountReceived, synthId(synthOut), "Forex");
        }
    }

    // Trade ib to ib
    function swapIB(address ibIn, address ibOut, uint amount) public returns (uint amountReceived) {
        if (ibIn == ibOut) return amount;
        address _swapSynth = poolStorage.ibToSynth(ibOut);
        amountReceived = swapIBToSynth(ibIn, _swapSynth, amount);
        amountReceived = swapSynthToIB(_swapSynth, ibOut, amountReceived);
    }

    function synthId(address synth) public view returns (bytes32) {
        return bytes32(bytes(IERC20Metadata(synth).symbol()));
    }
}