// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import "../../ISynthIBForex.sol";
import "../Curve/ILPAdapter.sol";
import "./IStableMasterFront.sol";
import "../Curve/ICurvePool.sol";

contract MintAgEurAdapter {
    using SafeERC20 for IERC20;

    IStableMasterFront constant stableMasterFront = IStableMasterFront(0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87);
    ICurvePool constant public curveIBEurAgEur = ICurvePool(0xB37D6c07482Bc11cd28a1f11f1a6ad7b66Dec933);
    ICurvePool constant public curveIBEurSEur = ICurvePool(0x1F71f05CF491595652378Fe94B7820344A551B8E);
    ISynthIBForex public immutable forex;
    ILPAdapter public immutable lpAdapter;
    address public immutable ibEur;

    constructor (address _lpAdapter) payable {
        lpAdapter = ILPAdapter(_lpAdapter);
        forex = ISynthIBForex(lpAdapter.forex());
        ibEur = curveIBEurAgEur.coins(0);
    }

    function swapUSDToIB(address poolManager, uint amount, address ibOut, uint minOut)
        external returns (uint amountReceived)
    {
        amount = mintAgEurForUsd(poolManager, amount);
        IERC20(stableMasterFront.agToken()).safeApprove(address(curveIBEurAgEur), amount);
        amountReceived = curveIBEurAgEur.exchange(1, 0, amount, 0, address(this));
        if (ibOut != ibEur) {
            IERC20(ibEur).safeApprove(address(forex), amountReceived);
            amountReceived = forex.swapIBToIB(ibEur, ibOut, amountReceived, 0);
        }
        require(amountReceived > minOut, "slippage");
        IERC20(ibOut).safeTransfer(msg.sender, amountReceived);
    }

    function swapUSDToSynth(address poolManager, uint amount, address synthOut, uint minOut)
        external returns (uint amountReceived)
    {
        amount = mintAgEurForUsd(poolManager, amount);
        IERC20(stableMasterFront.agToken()).safeApprove(address(curveIBEurAgEur), amount);
        amountReceived = curveIBEurAgEur.exchange(1, 0, amount, 0, address(this));
        IERC20(ibEur).safeApprove(address(forex), amountReceived);
        amountReceived = forex.swapIBToSynth(ibEur, synthOut, amountReceived, 0);
        require(amountReceived > minOut, "slippage");
        IERC20(synthOut).safeTransfer(msg.sender, amountReceived);
    }

    function swapUSDToLP(address poolManager, uint amount, address lpOut, uint minOut)
        external returns (uint amountReceived)
    {
        amount = mintAgEurForUsd(poolManager, amount);

        if (lpOut == address(curveIBEurAgEur)) {
            uint[2] memory amounts = [0, amount];
            IERC20(stableMasterFront.agToken()).safeApprove(address(curveIBEurAgEur), amount);
            amountReceived = curveIBEurAgEur.add_liquidity(amounts, 0);
        } else {
            IERC20(stableMasterFront.agToken()).safeApprove(address(curveIBEurAgEur), amount);
            amountReceived = curveIBEurAgEur.exchange(1, 0, amount, 0, address(this));
            IERC20(ibEur).safeApprove(address(lpAdapter), amountReceived);
            amountReceived = lpAdapter.swapIBToLP(ibEur, lpOut, amountReceived, 0);
        }
        require(amountReceived > minOut, "slippage");
        IERC20(lpOut).safeTransfer(msg.sender, amountReceived);
    }

    function mintAgEurForUsd(address poolManager, uint amount) internal returns (uint) {
        (address token,,,,,,,,) = stableMasterFront.collateralMap(poolManager);
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(token).approve(address(stableMasterFront), amount);
        uint before = IERC20(stableMasterFront.agToken()).balanceOf(address(this));
        stableMasterFront.mint(amount, address(this), poolManager, 0);
        return IERC20(stableMasterFront.agToken()).balanceOf(address(this)) - before;
    }
}
