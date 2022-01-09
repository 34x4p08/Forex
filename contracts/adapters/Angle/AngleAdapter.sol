// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import "../../ISynthIBForex.sol";
import "../Curve/ILPAdapter.sol";
import "./IStableMasterFront.sol";
import "../Curve/ICurvePool.sol";

contract AngleAdapter {
    using SafeERC20 for IERC20;

    IStableMasterFront constant stableMasterFront = IStableMasterFront(0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87);
    ICurvePool constant public curveIBEurAgEur = ICurvePool(0xB37D6c07482Bc11cd28a1f11f1a6ad7b66Dec933);
    ICurvePool constant public curveIBEurSEur = ICurvePool(0x1F71f05CF491595652378Fe94B7820344A551B8E);
    ISynthIBForex public immutable forex;
    ILPAdapter public immutable lpAdapter;
    address public immutable ibEur;

    mapping (address => address) public tokenToPoolManager;

    constructor (address _lpAdapter, address[] memory poolManagers) {
        lpAdapter = ILPAdapter(_lpAdapter);
        forex = ISynthIBForex(lpAdapter.forex());
        ibEur = curveIBEurAgEur.coins(0);
        for (uint i = 0; i < poolManagers.length; i++) {
            addPoolManager(poolManagers[i]);
        }
    }

    function addPoolManager(address poolManager) public {
        (address token,,,,,,,,) = stableMasterFront.collateralMap(poolManager);
        tokenToPoolManager[token] = poolManager;
    }

    function swapUSDToIB(address usdIn, address ibOut, uint amount, uint minOut)
        external returns (uint amountReceived)
    {
        amount = _mintAgEurForUsd(usdIn, amount);
        IERC20(stableMasterFront.agToken()).safeApprove(address(curveIBEurAgEur), amount);
        amountReceived = curveIBEurAgEur.exchange(1, 0, amount, 0, address(this));
        if (ibOut != ibEur) {
            IERC20(ibEur).safeApprove(address(forex), amountReceived);
            amountReceived = forex.swapIBToIB(ibEur, ibOut, amountReceived, 0);
        }
        require(amountReceived > minOut, "slippage");
        IERC20(ibOut).safeTransfer(msg.sender, amountReceived);
    }

    function swapIBToUSD(address ibIn, address usdOut, uint amount, uint minOut)
        external returns (uint amountReceived)
    {
        IERC20(ibIn).safeTransferFrom(msg.sender, address(this), amount);
        if (ibIn != ibEur) {
            IERC20(ibEur).safeApprove(address(forex), amount);
            amount = forex.swapIBToIB(ibIn, ibEur, amount, 0);
        }

        IERC20(ibEur).safeApprove(address(curveIBEurAgEur), amount);
        amount = curveIBEurAgEur.exchange(0, 1, amount, 0, address(this));

        amountReceived = _burnAgEurForUsd(usdOut, amount, minOut);
    }

    function swapUSDToSynth(address usdIn, address synthOut, uint amount, uint minOut)
        external returns (uint amountReceived)
    {
        amount = _mintAgEurForUsd(usdIn, amount);
        IERC20(stableMasterFront.agToken()).safeApprove(address(curveIBEurAgEur), amount);
        amountReceived = curveIBEurAgEur.exchange(1, 0, amount, 0, address(this));
        IERC20(ibEur).safeApprove(address(forex), amountReceived);
        amountReceived = forex.swapIBToSynth(ibEur, synthOut, amountReceived, 0);
        require(amountReceived > minOut, "slippage");
        IERC20(synthOut).safeTransfer(msg.sender, amountReceived);
    }

    function swapSynthToUSD(address synthIn, address usdOut, uint amount, uint minOut)
        external returns (uint amountReceived)
    {
        IERC20(synthIn).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(synthIn).safeApprove(address(forex), amount);
        amount = forex.swapSynthToIB(synthIn, ibEur, amount, 0);

        IERC20(ibEur).safeApprove(address(curveIBEurAgEur), amount);
        amount = curveIBEurAgEur.exchange(0, 1, amount, 0, address(this));

        amountReceived = _burnAgEurForUsd(usdOut, amount, minOut);
    }

    function swapUSDToLP(address usdIn, address lpOut, uint amount, uint minOut)
        external returns (uint amountReceived)
    {
        amount = _mintAgEurForUsd(usdIn, amount);

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

    function swapLPToUSD(address lpIn, address usdOut, uint amount, uint minOut)
        external returns (uint amountReceived)
    {
        IERC20(lpIn).safeTransferFrom(msg.sender, address(this), amount);
        if (lpIn == address(curveIBEurAgEur)) {
            amountReceived = curveIBEurAgEur.remove_liquidity_one_coin(amount, 1, 0);
        } else {
            IERC20(lpIn).safeApprove(address(lpAdapter), amount);
            amountReceived = lpAdapter.swapLPToIB(lpIn, ibEur, amount, 0);
            IERC20(ibEur).safeApprove(address(curveIBEurAgEur), amountReceived);
            amountReceived = curveIBEurAgEur.exchange(0, 1, amountReceived, 0, address(this));
        }
        amountReceived = _burnAgEurForUsd(usdOut, amountReceived, minOut);
    }

    function mintAgEurForUsd(address usdIn, uint amount, uint minOut) external returns (uint amountReceived) {
        amountReceived = _mintAgEurForUsd(usdIn, amount);
        require(amountReceived > minOut, "slippage");
        IERC20(stableMasterFront.agToken()).safeTransfer(msg.sender, amountReceived);
    }

    function _mintAgEurForUsd(address usdIn, uint amount) internal returns (uint) {
        IERC20(usdIn).safeTransferFrom(msg.sender, address(this), amount);
        IERC20(usdIn).approve(address(stableMasterFront), amount);
        uint before = IERC20(stableMasterFront.agToken()).balanceOf(address(this));
        stableMasterFront.mint(amount, address(this), tokenToPoolManager[usdIn], 0);
        return IERC20(stableMasterFront.agToken()).balanceOf(address(this)) - before;
    }

    function burnAgEurForUsd(address usdOut, uint amount, uint minOut) external returns (uint) {
        IERC20(stableMasterFront.agToken()).safeTransferFrom(msg.sender, address(this), amount);
        return _burnAgEurForUsd(usdOut, amount, minOut);
    }

    function _burnAgEurForUsd(address usdOut, uint amount, uint minOut) internal returns (uint amountReceived) {
        uint before = IERC20(usdOut).balanceOf(address(this));
        stableMasterFront.burn(amount, address(this), address(this), tokenToPoolManager[usdOut], 0);
        amountReceived = IERC20(usdOut).balanceOf(address(this)) - before;
        require(amountReceived > minOut, "slippage");
        IERC20(usdOut).safeTransfer(msg.sender, amountReceived);
    }
}
