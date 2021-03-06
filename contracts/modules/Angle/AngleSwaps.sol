// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

import "../../utils/Utils.sol";
import "./AngleUtils.sol";

interface IOracle {
    function readQuoteLower(uint) external view returns (uint);
    function readUpper() external view returns (uint);
}

/// no slippage checks, no intakes and no outputs, only internal swap logic
library AngleSwaps {
    using SafeERC20 for IERC20;
    using Utils for IERC20;

    IStableMasterFront constant public stableMasterFront = IStableMasterFront(0x5adDc89785D75C86aB939E9e15bfBBb7Fc086A87);
    address constant public curveIBEurAgEur = 0xB37D6c07482Bc11cd28a1f11f1a6ad7b66Dec933;
    address constant public curveIBEurSEur = 0x1F71f05CF491595652378Fe94B7820344A551B8E;
    address public constant ibEur = 0x96E61422b6A9bA0e068B6c5ADd4fFaBC6a4aae27;
    address public constant agEur = 0x1a7e4e63778B4f12a199C062f3eFdD288afCBce8;

    function quoteMint(address poolManager, uint amount) public view returns (uint) {
        (,,address perpetualManager, address oracle,uint256 stocksUsers,,,,IStableMasterFront.MintBurnData memory feeData) =
            stableMasterFront.collateralMap(poolManager);
        uint256 amountForUserInStable = IOracle(oracle).readQuoteLower(amount);
        uint fees = AngleUtils._computeFeeMint(amountForUserInStable, feeData, stocksUsers, perpetualManager);
        amountForUserInStable = (amountForUserInStable * (1e9 - fees)) / 1e9;
        require(stocksUsers + amountForUserInStable <= feeData.capOnStableMinted, "16");
        return amountForUserInStable;
    }

    function quoteBurn(address poolManager, uint amount) public view returns (uint) {
        (,,address perpetualManager, address oracle, uint256 stocksUsers,, uint256 collatBase,,IStableMasterFront.MintBurnData memory feeData) =
            stableMasterFront.collateralMap(poolManager);
        uint256 oracleValue = IOracle(oracle).readUpper();
        uint256 redeemInC = (amount *
            (AngleUtils.BASE_PARAMS -
                AngleUtils._computeFeeBurn(amount, feeData, stocksUsers, perpetualManager)
            ) * collatBase
        ) / (oracleValue * AngleUtils.BASE_PARAMS);
        return redeemInC;
    }

    function mint(address poolManager, uint amount) internal returns (uint) {
        (address usdIn,,,,,,,,) = stableMasterFront.collateralMap(poolManager);
        IERC20(usdIn).ensureMaxApproval(address(stableMasterFront), amount);
        uint before = IERC20(agEur).balanceOf(address(this));
        stableMasterFront.mint(amount, address(this), poolManager, 0);
        return IERC20(agEur).balanceOf(address(this)) - before;
    }

    function burn(address poolManager, uint amount) internal returns (uint amountReceived) {
        (address usdOut,,,,,,,,) = stableMasterFront.collateralMap(poolManager);
        uint before = IERC20(usdOut).balanceOf(address(this));
        stableMasterFront.burn(amount, address(this), address(this), poolManager, 0);
        amountReceived = IERC20(usdOut).balanceOf(address(this)) - before;
    }
}
