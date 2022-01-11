// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./modules/Synthetix/SynthIBSwaps.sol";
import "./modules/Curve/CurveSwaps.sol";
import "./modules/Curve/CurveLPSwaps.sol";
import "./modules/Angle/AngleSwaps.sol";

contract FunctionPointers {
    // Quote synth to synth
    function quoteSynth(address synthIn, address synthOut, uint amount) public view returns (uint) {
        return SynthIBSwaps.quoteSynth(synthIn, synthOut, amount);
    }

    // Quote ib to ib
    function quoteIB(address ibIn, address ibOut, uint amount) public view returns (uint) {
        return SynthIBSwaps.quoteIB(ibIn, ibOut, amount);
    }

    // Quote synth to ib
    function quoteSynthToIB(address synthIn, address ibOut, uint amount) public view returns (uint) {
        return SynthIBSwaps.quoteSynthToIB(synthIn, ibOut, amount);
    }

    // Quote ib to synth
    function quoteIBToSynth(address ibIn, address synthOut, uint amount) public view returns (uint) {
        return SynthIBSwaps.quoteIBToSynth(ibIn, synthOut, amount);
    }

    // Trade synth to synth
    function swapSynth(address synthIn, address synthOut, uint amount) internal returns (uint) {
        return SynthIBSwaps.swapSynth(synthIn, synthOut, amount);
    }

    // Trade synth to ib
    function swapSynthToIB(address synthIn, address ibOut, uint amount) internal returns (uint) {
        return SynthIBSwaps.swapSynthToIB(synthIn, ibOut, amount);
    }

    // Trade ib to synth
    function swapIBToSynth(address ibIn, address synthOut, uint amount) internal returns (uint) {
        return SynthIBSwaps.swapIBToSynth(ibIn, synthOut, amount);
    }

    // Trade ib to ib
    function swapIB(address ibIn, address ibOut, uint amount) internal returns (uint) {
        return SynthIBSwaps.swapIB(ibIn, ibOut, amount);
    }
}
