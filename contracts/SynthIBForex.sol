// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/ISynthIBForex.sol";

interface erc20 {
    function approve(address, uint) external returns (bool);
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function balanceOf(address) external view returns (uint);
}

interface Metadata {
    function symbol() external view returns (string memory);
}

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

interface CurvePool {
    function get_dy(int128, int128, uint) external view returns (uint);
    function coins(uint) external view returns (address);
    function exchange(int128, int128, uint, uint, address) external returns (uint);
}

contract SynthIBForex is ISynthIBForex {
    SynthExchanger sex = SynthExchanger(0xDC01020857afbaE65224CfCeDb265d1216064c59);
    SynthExchangeViewer sexViewer = SynthExchangeViewer(0x2A417C61B8062363e4ff50900779463b45d235f6);


    address public gov = msg.sender;
    // ib-asset to synth analogue
    mapping (address => address) public ibToSynth;
    // ib-asset to related Curve pool
    mapping (address => address) public pools;

    modifier g {
        require(gov == msg.sender, "!g");
        _;
    }

    constructor() {
        // susd
        erc20(0x57Ab1ec28D129707052df4dF418D58a2D46d5f51).approve(address(sex), type(uint).max);

        // ibeur, seur
        add(0x96E61422b6A9bA0e068B6c5ADd4fFaBC6a4aae27, 0xD71eCFF9342A5Ced620049e616c5035F1dB98620, 0x19b080FE1ffA0553469D20Ca36219F17Fcf03859);
    }

    function add(address ib, address synth, address pool) public g {
        require(pools[ib] == address(0));
        require(ibToSynth[ib] == address(0));

        require(synthId(synth) != bytes32(0));

        pools[ib] = pool;
        ibToSynth[ib] = synth;
        erc20(synth).approve(address(sex), type(uint).max);
        erc20(synth).approve(pool, type(uint).max);
        erc20(ib).approve(pool, type(uint).max);
    }

    function changeG(address _g) external g {
        gov = _g;
    }

    function quoteSynth(address synthIn, address synthOut, uint amount) external view returns (uint amountReceived) {
        (amountReceived,,) = sexViewer.getAmountsForAtomicExchange(amount, synthId(synthIn), synthId(synthOut));
    }

    function quoteIB(address ibIn, address ibOut, uint amount) external view returns (uint amountReceived) {
        require(ibIn != ibOut, "???");
        address pool = pools[ibIn];
        (int128 synthIndex, int128 ibIndex) = _getTokenIndexes(pool, ibIn);
        uint _out = CurvePool(pool).get_dy(ibIndex, synthIndex, amount);
        (amountReceived,,) = sexViewer.getAmountsForAtomicExchange(_out, synthId(ibToSynth[ibIn]), synthId(ibToSynth[ibOut]));
        pool = pools[ibOut];
        (synthIndex, ibIndex) = _getTokenIndexes(pool, ibOut);
        return CurvePool(pool).get_dy(synthIndex, ibIndex, amountReceived);
    }

    // Quote synth to ib
    function quoteSynthToIB(address synthIn, address ibOut, uint amount) external view returns (uint amountReceived) {
        if (ibToSynth[ibOut] != synthIn) {
            (amount,,) = sexViewer.getAmountsForAtomicExchange(amount, synthId(synthIn), synthId(ibToSynth[ibOut]));
        }
        address pool = pools[ibOut];
        (int128 synthIndex, int128 ibIndex) = _getTokenIndexes(pool, ibOut);
        return CurvePool(pool).get_dy(synthIndex, ibIndex, amount);
    }

    // Quote ib to synth
    function quoteIBToSynth(address ibIn, address synthOut, uint amount) external view returns (uint amountReceived) {
        address pool = pools[ibIn];
        (int128 synthIndex, int128 ibIndex) = _getTokenIndexes(pool, ibIn);
        amountReceived = CurvePool(pool).get_dy(ibIndex, synthIndex, amount);
        if (ibToSynth[ibIn] != synthOut) {
            (amountReceived,,) = sexViewer.getAmountsForAtomicExchange(amountReceived, synthId(ibToSynth[ibIn]), synthId(synthOut));
        }
    }

    function swapSynth(address synthIn, address synthOut, uint amount, uint minOut) external returns (uint amountReceived) {
        require(synthIn != synthOut, "???");
        _safeTransferFrom(synthIn, msg.sender, address(this), amount);
        amountReceived = sex.exchangeAtomically(synthId(synthIn), amount, synthId(synthOut), "Forex");
        require(amountReceived > minOut, "slippage");
        _safeTransfer(synthOut, msg.sender, amountReceived);
    }

    // Trade synth to ib
    function swapSynthToIB(address synthIn, address ibOut, uint amount, uint minOut) external returns (uint amountReceived) {
        _safeTransferFrom(synthIn, msg.sender, address(this), amount);

        if (ibToSynth[ibOut] != synthIn) {
            amount = sex.exchangeAtomically(synthId(synthIn), amount, synthId(ibToSynth[ibOut]), "Forex");
        }

        address pool = pools[ibOut];
        (int128 synthIndex, int128 ibIndex) = _getTokenIndexes(pool, ibOut);
        amountReceived = CurvePool(pool).exchange(synthIndex, ibIndex, amount, minOut, msg.sender);
    }

    // Trade ib to synth
    function swapIBToSynth(address ibIn, address synthOut, uint amount, uint minOut) external returns (uint amountReceived) {
        _safeTransferFrom(ibIn, msg.sender, address(this), amount);
        address pool = pools[ibIn];
        (int128 synthIndex, int128 ibIndex) = _getTokenIndexes(pool, ibIn);
        amountReceived = CurvePool(pool).exchange(ibIndex, synthIndex, amount, 0, address(this));

        if (ibToSynth[ibIn] != synthOut) {
            amountReceived = sex.exchangeAtomically(synthId(ibToSynth[ibIn]), amountReceived, synthId(synthOut), "Forex");
        }

        require(amountReceived > minOut, "slippage");
        _safeTransfer(synthOut, msg.sender, amountReceived);
    }

    // Trade ib to ib
    function swapIBToIB(address ibIn, address ibOut, uint amount, uint minOut) external returns (uint amountReceived) {
        require(ibIn != ibOut, "???");
        _safeTransferFrom(ibIn, msg.sender, address(this), amount);
        address pool = pools[ibIn];
        (int128 synthIndex, int128 ibIndex) = _getTokenIndexes(pool, ibIn);
        amountReceived = CurvePool(pool).exchange(ibIndex, synthIndex, amount, 0, address(this));
        amountReceived = sex.exchangeAtomically(synthId(ibToSynth[ibIn]), amountReceived, synthId(ibToSynth[ibOut]), "Forex");
        pool = pools[ibOut];
        (synthIndex, ibIndex) = _getTokenIndexes(pool, ibOut);
        amountReceived = CurvePool(pool).exchange(synthIndex, ibIndex, amount, 0, address(this));
        require(amountReceived > minOut, "slippage");
        _safeTransfer(ibOut, msg.sender, amountReceived);
    }

    function _safeTransfer(address token, address to, uint256 value) internal {
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(erc20.transfer.selector, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function _safeTransferFrom(address token, address from, address to, uint256 value) internal {
        (bool success, bytes memory data) =
        token.call(abi.encodeWithSelector(erc20.transferFrom.selector, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    function _getTokenIndexes(address pool, address ibAsset) internal view returns (int128, int128) {
        address coin0 = CurvePool(pool).coins(0);
        return coin0 == ibAsset ? (int128(1), int128(0)) : (int128(0), int128(1));
    }

    function synthId(address synth) public view returns (bytes32) {
        return bytes32(bytes(Metadata(synth).symbol()));
    }
}