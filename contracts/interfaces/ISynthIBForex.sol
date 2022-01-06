// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface ISynthIBForex {
    function add ( address ib, address synth, address pool ) external;
    function changeG ( address _g ) external;
    function gov (  ) external view returns ( address );
    function ibToSynth ( address ) external view returns ( address );
    function pools ( address ) external view returns ( address );
    function quoteIB ( address ibIn, address ibOut, uint256 amount ) external view returns ( uint256 amountReceived );
    function quoteIBToSynth ( address ibIn, address synthOut, uint256 amount ) external view returns ( uint256 amountReceived );
    function quoteSynth ( address synthIn, address synthOut, uint256 amount ) external view returns ( uint256 amountReceived );
    function quoteSynthToIB ( address synthIn, address ibOut, uint256 amount ) external view returns ( uint256 amountReceived );
    function swapIBToIB ( address ibIn, address ibOut, uint256 amount, uint256 minOut ) external returns ( uint256 amountReceived );
    function swapIBToSynth ( address ibIn, address synthOut, uint256 amount, uint256 minOut ) external returns ( uint256 amountReceived );
    function swapSynth ( address synthIn, address synthOut, uint256 amount, uint256 minOut ) external returns ( uint256 amountReceived );
    function swapSynthToIB ( address synthIn, address ibOut, uint256 amount, uint256 minOut ) external returns ( uint256 amountReceived );
    function synthId ( address ) external view returns ( bytes32 );
}
