// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';

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

interface IWETH9 {
    function deposit() external payable;
}

contract BurnAgEurAdapterView {

    IStableMasterFront constant stableMasterFront = IStableMasterFront(0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87);
    ICurvePool constant curveIBEurAgEur = ICurvePool(0xB37D6c07482Bc11cd28a1f11f1a6ad7b66Dec933);
    ICurvePool constant curveIBEurSEur = ICurvePool(0x1F71f05CF491595652378Fe94B7820344A551B8E);
    ISwapRouter constant router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    IWETH9 constant weth = IWETH9(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    ISynthIBForex immutable forex;
    ILPAdapter immutable lpAdapter;
    address immutable ibEur;
    address constant usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    constructor (address _lpAdapter, address poolManager, uint amount, address startingAsset) payable {
        lpAdapter = ILPAdapter(_lpAdapter);
        forex = ISynthIBForex(lpAdapter.forex());
        ibEur = curveIBEurAgEur.coins(0);

        // getting agEur balance
        weth.deposit{value: msg.value}();
        IERC20(address(weth)).approve(address(router), msg.value);

        ISwapRouter.ExactInputParams memory params = ISwapRouter.ExactInputParams({
            path: abi.encodePacked(address(weth), uint24(3000), usdc, uint24(500), stableMasterFront.agToken()),
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: msg.value,
            amountOutMinimum: 0
        });

        uint agEurMax = router.exactInput(params);

        if (startingAsset != address(0) && startingAsset != stableMasterFront.agToken()) {
            amount = convertFrom(amount, startingAsset);
        }

        require (agEurMax >= amount, "too much");

        uint result = burnAgEurForUsd(poolManager, amount);

        assembly {
            let res:= mload(0x40)
            mstore(res, result)
            return(res, 0x20)
        }
    }

    function convertFrom(uint amount, address startingAsset) internal view returns (uint) {
        // ib-eur & ag-eur LP
        if (startingAsset == address(curveIBEurAgEur)) {
            return curveIBEurAgEur.calc_withdraw_one_coin(amount, 1);
        }
        // ib-eur
        if (startingAsset == ibEur) {
            return curveIBEurAgEur.get_dy(0, 1, amount);
        }

        // in any other cases we convert startingAsset to ib-eur

        // ib-asset
        if (forex.pools(startingAsset) != address(0)) {
            amount = forex.quoteIB(startingAsset, ibEur, amount);
            return curveIBEurAgEur.get_dy(0, 1, forex.quoteIB(startingAsset, ibEur, amount));
        }

        bool isLP;
        try ICurvePool(startingAsset).coins(0) returns (address _value) {
            isLP = _value != address(0);
        } catch (bytes memory) { }
        // curve LP
        if (isLP) {
            amount = lpAdapter.quoteLPToIB(startingAsset, ibEur, amount);
            return curveIBEurAgEur.get_dy(0, 1, amount);
        }

        // synth
        amount = forex.quoteSynthToIB(startingAsset, ibEur, amount);
        return curveIBEurAgEur.get_dy(0, 1, amount);
    }

    function burnAgEurForUsd(address poolManager, uint amount) internal returns (uint) {
        (address token,,,,,,,,) = stableMasterFront.collateralMap(poolManager);
        stableMasterFront.burn(amount, address(this), address(this), poolManager, 0);
        return IERC20(token).balanceOf(address(this));
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
