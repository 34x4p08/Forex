// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol';
import "./IPoolStorage.sol";
import "../Curve/ICurvePool.sol";

contract PoolStorage is IPoolStorage {
    address public gov = msg.sender;
    // ib-asset to synth analogue
    mapping (address => address) public ibToSynth;
    // ib-asset to synth analogue
    mapping (address => address) public synthToIB;
    // ib-asset to related Curve pool
    mapping (address => address) public pools;

    modifier g {
        require(gov == msg.sender, "!g");
        _;
    }

    constructor() {
        // ibeur, seur
        add(0x96E61422b6A9bA0e068B6c5ADd4fFaBC6a4aae27, 0xD71eCFF9342A5Ced620049e616c5035F1dB98620, 0x19b080FE1ffA0553469D20Ca36219F17Fcf03859);
    }

    function add(address ib, address synth, address pool) public g {
        require(pools[ib] == address(0));
        require(ibToSynth[ib] == address(0));
        require(synthToIB[synth] == address(0));
        require(ib != synth);
        require(synthId(synth) != bytes32(0));

        require(
            (ICurvePool(pool).coins(0) == ib || ICurvePool(pool).coins(1) == ib) &&
            (ICurvePool(pool).coins(0) == synth || ICurvePool(pool).coins(1) == synth)
        );

        pools[ib] = pool;
        ibToSynth[ib] = synth;
        synthToIB[synth] = ib;
    }

    function changeG(address _g) external g {
        gov = _g;
    }

    function synthId(address synth) public view returns (bytes32) {
        return bytes32(bytes(IERC20Metadata(synth).symbol()));
    }
}