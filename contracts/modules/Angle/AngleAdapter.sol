// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import "../Synthetix/SynthIBSwaps.sol";
import "../Curve/CurveLPSwaps.sol";
import "../Curve/ICurvePool.sol";
import "../../utils/Utils.sol";
import "./IAnglePoolStorage.sol";
import "./AngleUtils.sol";

interface IOracle {
    function readQuoteLower(uint) external view returns (uint);
}

/// no slippage checks, no intakes and no outputs, only internal swap logic
library AngleAdapter {
    using SafeERC20 for IERC20;
    using Utils for IERC20;

    IStableMasterFront constant public stableMasterFront = IStableMasterFront(0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87);
    ICurvePool constant public curveIBEurAgEur = ICurvePool(0xB37D6c07482Bc11cd28a1f11f1a6ad7b66Dec933);
    ICurvePool constant public curveIBEurSEur = ICurvePool(0x1F71f05CF491595652378Fe94B7820344A551B8E);
    IAnglePoolStorage constant public anglePoolStorage = IAnglePoolStorage(0x092D703AF2B1b566de68872008F904e320D04659);
    address public constant ibEur = 0x96E61422b6A9bA0e068B6c5ADd4fFaBC6a4aae27;
    address public constant agEur = 0x1a7e4e63778B4f12a199C062f3eFdD288afCBce8;

    function swapUSDToIB(address usdIn, address ibOut, uint amount)
        external returns (uint amountReceived)
    {
        amount = _mintAgEurForUsd(usdIn, amount);
        IERC20(agEur).ensureMaxApproval(address(curveIBEurAgEur), amount);
        amountReceived = curveIBEurAgEur.exchange(1, 0, amount, 0, address(this));
        if (ibOut != ibEur) {
            amountReceived = SynthIBSwaps.swapIB(ibEur, ibOut, amountReceived);
        }
    }

    function quoteUSDToIB(address usdIn, address ibOut, uint amount)
        external view returns (uint amountReceived)
    {
        amount = quoteMint(usdIn, amount);
        amountReceived = curveIBEurAgEur.get_dy(1, 0, amount);
        if (ibOut != ibEur) {
            amountReceived = SynthIBSwaps.quoteIB(ibEur, ibOut, amountReceived);
        }
    }

    function swapIBToUSD(address ibIn, address usdOut, uint amount)
        external returns (uint amountReceived)
    {
        if (ibIn != ibEur) {
            amount = SynthIBSwaps.swapIB(ibIn, ibEur, amount);
        }
        IERC20(ibEur).ensureMaxApproval(address(curveIBEurAgEur), amount);
        amount = curveIBEurAgEur.exchange(0, 1, amount, 0, address(this));
        amountReceived = _burnAgEurForUsd(usdOut, amount);
    }

    function swapUSDToSynth(address usdIn, address synthOut, uint amount)
        external returns (uint amountReceived)
    {
        amount = _mintAgEurForUsd(usdIn, amount);
        IERC20(agEur).ensureMaxApproval(address(curveIBEurAgEur), amount);
        amountReceived = curveIBEurAgEur.exchange(1, 0, amount, 0, address(this));
        amountReceived = SynthIBSwaps.swapIBToSynth(ibEur, synthOut, amountReceived);
    }

    function swapSynthToUSD(address synthIn, address usdOut, uint amount)
        external returns (uint amountReceived)
    {
        amount = SynthIBSwaps.swapSynthToIB(synthIn, ibEur, amount);
        IERC20(ibEur).ensureMaxApproval(address(curveIBEurAgEur), amount);
        amount = curveIBEurAgEur.exchange(0, 1, amount, 0, address(this));
        amountReceived = _burnAgEurForUsd(usdOut, amount);
    }

    function swapUSDToLP(address usdIn, address lpOut, uint amount)
        external returns (uint amountReceived)
    {
        amount = _mintAgEurForUsd(usdIn, amount);
        IERC20(agEur).ensureMaxApproval(address(curveIBEurAgEur), amount);
        if (lpOut == address(curveIBEurAgEur)) {
            uint[2] memory amounts = [0, amount];
            amountReceived = curveIBEurAgEur.add_liquidity(amounts, 0);
        } else {
            amountReceived = curveIBEurAgEur.exchange(1, 0, amount, 0, address(this));
            amountReceived = CurveLPSwaps.swapIBToLP(ibEur, lpOut, amountReceived);
        }
    }

    function swapLPToUSD(address lpIn, address usdOut, uint amount)
        external returns (uint amountReceived)
    {
        if (lpIn == address(curveIBEurAgEur)) {
            amountReceived = curveIBEurAgEur.remove_liquidity_one_coin(amount, 1, 0);
        } else {
            amountReceived = CurveLPSwaps.swapLPToIB(lpIn, ibEur, amount);
            IERC20(ibEur).ensureMaxApproval(address(curveIBEurAgEur), amountReceived);
            amountReceived = curveIBEurAgEur.exchange(0, 1, amountReceived, 0, address(this));
        }
        amountReceived = _burnAgEurForUsd(usdOut, amountReceived);
    }

    function quoteMint(address usdIn, uint amount) public view returns (uint) {

        (,,address perpetualManager, address oracle,uint256 stocksUsers,,,,IStableMasterFront.MintBurnData memory feeData) =
            stableMasterFront.collateralMap(anglePoolStorage.tokenToPoolManager(usdIn));
        uint256 amountForUserInStable = IOracle(oracle).readQuoteLower(amount);
        uint fees = AngleUtils._computeFeeMint(amountForUserInStable, feeData, stocksUsers, perpetualManager);
        amountForUserInStable = (amountForUserInStable * (1e9 - fees)) / 1e9;
        require(stocksUsers + amountForUserInStable <= feeData.capOnStableMinted, "16");
        return amountForUserInStable;
    }

    function _mintAgEurForUsd(address usdIn, uint amount) internal returns (uint) {
        IERC20(usdIn).ensureExactApproval(address(stableMasterFront), amount);
        uint before = IERC20(agEur).balanceOf(address(this));
        stableMasterFront.mint(amount, address(this), anglePoolStorage.tokenToPoolManager(usdIn), 0);
        return IERC20(agEur).balanceOf(address(this)) - before;
    }

    function _burnAgEurForUsd(address usdOut, uint amount) internal returns (uint amountReceived) {
        uint before = IERC20(usdOut).balanceOf(address(this));
        stableMasterFront.burn(amount, address(this), address(this), anglePoolStorage.tokenToPoolManager(usdOut), 0);
        amountReceived = IERC20(usdOut).balanceOf(address(this)) - before;
    }
}
