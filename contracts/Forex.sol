// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface erc20 {
    function approve(address, uint) external returns (bool);
    function transfer(address, uint) external returns (bool);
    function transferFrom(address, address, uint) external returns (bool);
    function balanceOf(address) external view returns (uint);
    function symbol() external view returns (string memory);
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

contract Forex {
    SynthExchanger sex = SynthExchanger(0xDC01020857afbaE65224CfCeDb265d1216064c59);
    SynthExchangeViewer sexViewer = SynthExchangeViewer(0x2A417C61B8062363e4ff50900779463b45d235f6);


    address public gov = msg.sender;

    mapping (address => bytes32) public synthID;
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
        synthID[0x57Ab1ec28D129707052df4dF418D58a2D46d5f51] = "sUSD";

        // ibeur, seur
        add(0x96E61422b6A9bA0e068B6c5ADd4fFaBC6a4aae27, 0xD71eCFF9342A5Ced620049e616c5035F1dB98620, 0x19b080FE1ffA0553469D20Ca36219F17Fcf03859);
    }

    function add(address ib, address synth, address pool) public g {
        require(pools[ib] == address(0));
        require(ibToSynth[ib] == address(0));
        require(synthID[synth] == bytes32(0));

        bytes32 id = bytes32(bytes(Metadata(synth).symbol()));
        require(id != bytes32(0));        
        synthID[synth] = id;

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
        (amountReceived,,) = sexViewer.getAmountsForAtomicExchange(amount, synthID[synthIn], synthID[synthOut]);
    }

    function quoteIB(address ibIn, address ibOut, uint amount) external view returns (uint amountReceived) {
        require(ibIn != ibOut, "???");
        address pool = pools[ibIn];
        (int128 synthIndex, int128 ibIndex) = _getTokenIndexes(pool, ibIn);
        uint _out = CurvePool(pool).get_dy(ibIndex, synthIndex, amount);
        (amountReceived,,) = sexViewer.getAmountsForAtomicExchange(_out, synthID[ibToSynth[ibIn]], synthID[ibToSynth[ibOut]]);
        pool = pools[ibOut];
        (synthIndex, ibIndex) = _getTokenIndexes(pool, ibOut);
        return CurvePool(pool).get_dy(synthIndex, ibIndex, amountReceived);
    }

    // Quote synth to ib
    function quoteSynthToIB(address synthIn, address ibOut, uint amount) external view returns (uint amountReceived) {
        if (ibToSynth[ibOut] != synthIn) {
            (amount,,) = sexViewer.getAmountsForAtomicExchange(amount, synthID[synthIn], synthID[ibToSynth[ibOut]]);
        }
        address pool = pools[ibOut];
        (int128 synthIndex, int128 ibIndex) = _getTokenIndexes(pool, ibOut);
        return CurvePool(pool).get_dy(synthIndex, ibIndex, amount);
    }

    // Quote ib to synth
    function quoteIBToSynth(address ibIn, address synthOut, uint amount) external view returns (uint amountReceived) {
        address pool = pools[ibIn];
        (int128 synthIndex, int128 ibIndex) = _getTokenIndexes(pool, ibIn);
        uint amountReceived = CurvePool(pool).get_dy(ibIndex, synthIndex, amount);
        if (ibToSynth[ibIn] != synthOut) {
            (amountReceived,,) = sexViewer.getAmountsForAtomicExchange(amountReceived, synthID[ibToSynth[ibIn]], synthID[synthOut]);
        }
    }

    function swapSynth(address synthIn, address synthOut, uint amount, uint minOut) external returns (uint amountReceived) {
        require(synthIn != synthOut, "???");
        _safeTransferFrom(synthIn, msg.sender, address(this), amount);
        amountReceived = sex.exchangeAtomically(synthID[synthIn], amount, synthID[synthOut], "Forex");
        require(amountReceived > minOut, "slippage");
        _safeTransfer(synthOut, msg.sender, amountReceived);
    }

    // Trade synth to ib
    function swapSynthToIB(address synthIn, address ibOut, uint amount, uint minOut) external returns (uint amountReceived) {
        _safeTransferFrom(synthIn, msg.sender, address(this), amount);

        if (ibToSynth[ibOut] != synthIn) {
            amount = sex.exchangeAtomically(synthID[synthIn], amount, synthID[ibToSynth[ibOut]], "Forex");
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
            amountReceived = sex.exchangeAtomically(synthID[ibToSynth[ibIn]], amountReceived, synthID[synthOut], "Forex");
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
        amountReceived = sex.exchangeAtomically(synthID[ibToSynth[ibIn]], amountReceived, synthID[ibToSynth[ibOut]], "Forex");
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
}