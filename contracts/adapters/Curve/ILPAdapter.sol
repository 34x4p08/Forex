// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ILPAdapter {
    function forex (  ) external view returns ( address );
    function quoteIBToLP ( address ibIn, address lpOut, uint256 amount ) external view returns ( uint256 amountReceived );
    function quoteLPToIB ( address lpIn, address ibOut, uint256 amount ) external view returns ( uint256 amountReceived );
    function quoteLPToLP ( address lpIn, address lpOut, uint256 amount ) external view returns ( uint256 amountReceived );
    function quoteLPToSynth ( address lpIn, address synthOut, uint256 amount ) external view returns ( uint256 amountReceived );
    function quoteSynthToLP ( address synthIn, address lpOut, uint256 amount ) external view returns ( uint256 amountReceived );
    function swapLPToIB ( address lpIn, address ibOut, uint256 amount, uint256 minOut ) external returns ( uint256 amountReceived );
    function swapLPToLP ( address lpIn, address lpOut, uint256 amount, uint256 minOut ) external returns ( uint256 amountReceived );
    function swapLPToSynth ( address lpIn, address synthOut, uint256 amount, uint256 minOut ) external returns ( uint256 amountReceived );
    function swapSynthToLP ( address synthIn, address lpOut, uint256 amount, uint256 minOut ) external returns ( uint256 amountReceived );
}