// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

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
library SynthSwaps {
    using SafeERC20 for IERC20;
    using Utils for IERC20;

    SynthExchanger public constant sex = SynthExchanger(0xDC01020857afbaE65224CfCeDb265d1216064c59);
    SynthExchangeViewer public constant sexViewer = SynthExchangeViewer(0x2A417C61B8062363e4ff50900779463b45d235f6);

    // Quote synth to synth
    function quoteSynth(address synthIn, address synthOut, uint amount) external view returns (uint amountReceived) {
        if (synthIn == synthOut) return amount;
        (amountReceived,,) = sexViewer.getAmountsForAtomicExchange(amount, synthId(synthIn), synthId(synthOut));
    }

    // Trade synth to synth
    function swapSynth(address synthIn, address synthOut, uint amount) public returns (uint amountReceived) {
        if (synthIn == synthOut) return amount;
        IERC20(synthIn).ensureMaxApproval(address(sex), amount);
        amountReceived = sex.exchangeAtomically(synthId(synthIn), amount, synthId(synthOut), "Forex");
    }

    function synthId(address synth) public view returns (bytes32) {
        return bytes32(bytes(IERC20Metadata(synth).symbol()));
    }
}