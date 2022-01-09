// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "../../ISynthIBForex.sol";
import "../Curve/ILPAdapter.sol";
import "./IStableMasterFront.sol";
import "../Curve/ICurvePool.sol";

interface IUniRouter {
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
}

contract MintAgEurAdapterView {

    IUniRouter constant router = IUniRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IStableMasterFront constant stableMasterFront = IStableMasterFront(0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87);
    ICurvePool constant curveIBEurAgEur = ICurvePool(0xB37D6c07482Bc11cd28a1f11f1a6ad7b66Dec933);
    ICurvePool constant curveIBEurSEur = ICurvePool(0x1F71f05CF491595652378Fe94B7820344A551B8E);
    ISynthIBForex immutable forex;
    ILPAdapter immutable lpAdapter;
    address immutable ibEur;

    constructor (address _lpAdapter, address poolManager, uint amount, address resultingAsset) payable {
        lpAdapter = ILPAdapter(_lpAdapter);
        forex = ISynthIBForex(lpAdapter.forex());
        ibEur = curveIBEurAgEur.coins(0);
        uint result = mintAgEurForUsd(poolManager, amount);

        if (resultingAsset != address(0) && resultingAsset != stableMasterFront.agToken()) {
            result = convertTo(result, resultingAsset);
        }

        assembly {
            let res:= mload(0x40)
            mstore(res, result)
            return(res, 0x20)
        }
    }

    function convertTo(uint amount, address resultingAsset) internal view returns (uint) {
        // ib-eur & ag-eur LP
        if (resultingAsset == address(curveIBEurAgEur)) {
            uint[2] memory amounts = [0, amount];
            return curveIBEurAgEur.calc_token_amount(amounts, true);
        }
        // ib-eur
        if (resultingAsset == ibEur) {
            return curveIBEurAgEur.get_dy(1, 0, amount);
        }
        // in any other cases we convert ag-eur to ib-eur
        amount = curveIBEurAgEur.get_dy(1, 0, amount);

        // ib-asset
        if (forex.pools(resultingAsset) != address(0)) {
            return forex.quoteIB(ibEur, resultingAsset, amount);
        }

        bool isLP;
        try ICurvePool(resultingAsset).coins(0) returns (address _value) {
            isLP = _value != address(0);
        } catch (bytes memory) { }
        // curve LP
        if (isLP) {
            return lpAdapter.quoteIBToLP(ibEur, resultingAsset, amount);
        }

        // synth
        return forex.quoteIBToSynth(ibEur, resultingAsset, amount);
    }

    function mintAgEurForUsd(address poolManager, uint amount) internal returns (uint) {
        address[] memory path = new address[](2);
        path[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        (address token,,,,,,,,) = stableMasterFront.collateralMap(poolManager);
        path[1] = token;
        router.swapExactETHForTokens{value: msg.value}(1, path, address(this), block.timestamp + 1);
        require(IERC20(token).balanceOf(address(this)) >= amount, "too much");
        IERC20(token).approve(address(stableMasterFront), amount);
        stableMasterFront.mint(amount, address(this), poolManager, 1);
        return IERC20(stableMasterFront.agToken()).balanceOf(address(this));
    }

    function _getSynth(address pool) internal view returns (int128, address) {
        address coin0 = ICurvePool(pool).coins(0);
        address coin1 = ICurvePool(pool).coins(1);
        if (forex.pools(coin0) == pool) {
            return (int128(1), coin1);
        }
        if (forex.pools(coin1) == pool) {
            return (int128(0), coin0);
        }
        revert("pool not found");
    }
}
