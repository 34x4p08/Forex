// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import "../../ISynthIBForex.sol";
import "../Curve/ILPAdapter.sol";

interface IStableMasterFront {

    // Struct to handle all the parameters to manage the fees
    // related to a given collateral pool (associated to the stablecoin)
    struct MintBurnData {
        // Values of the thresholds to compute the minting fees
        // depending on HA hedge (scaled by `BASE_PARAMS`)
        uint64[] xFeeMint;
        // Values of the fees at thresholds (scaled by `BASE_PARAMS`)
        uint64[] yFeeMint;
        // Values of the thresholds to compute the burning fees
        // depending on HA hedge (scaled by `BASE_PARAMS`)
        uint64[] xFeeBurn;
        // Values of the fees at thresholds (scaled by `BASE_PARAMS`)
        uint64[] yFeeBurn;
        // Max proportion of collateral from users that can be covered by HAs
        // It is exactly the same as the parameter of the same name in `PerpetualManager`, whenever one is updated
        // the other changes accordingly
        uint64 targetHAHedge;
        // Minting fees correction set by the `FeeManager` contract: they are going to be multiplied
        // to the value of the fees computed using the hedge curve
        // Scaled by `BASE_PARAMS`
        uint64 bonusMalusMint;
        // Burning fees correction set by the `FeeManager` contract: they are going to be multiplied
        // to the value of the fees computed using the hedge curve
        // Scaled by `BASE_PARAMS`
        uint64 bonusMalusBurn;
        // Parameter used to limit the number of stablecoins that can be issued using the concerned collateral
        uint256 capOnStableMinted;
    }

    // Struct to handle all the variables and parameters to handle SLPs in the protocol
    // including the fraction of interests they receive or the fees to be distributed to
    // them
    struct SLPData {
        // Last timestamp at which the `sanRate` has been updated for SLPs
        uint256 lastBlockUpdated;
        // Fees accumulated from previous blocks and to be distributed to SLPs
        uint256 lockedInterests;
        // Max interests used to update the `sanRate` in a single block
        // Should be in collateral token base
        uint256 maxInterestsDistributed;
        // Amount of fees left aside for SLPs and that will be distributed
        // when the protocol is collateralized back again
        uint256 feesAside;
        // Part of the fees normally going to SLPs that is left aside
        // before the protocol is collateralized back again (depends on collateral ratio)
        // Updated by keepers and scaled by `BASE_PARAMS`
        uint64 slippageFee;
        // Portion of the fees from users minting and burning
        // that goes to SLPs (the rest goes to surplus)
        uint64 feesForSLPs;
        // Slippage factor that's applied to SLPs exiting (depends on collateral ratio)
        // If `slippage = BASE_PARAMS`, SLPs can get nothing, if `slippage = 0` they get their full claim
        // Updated by keepers and scaled by `BASE_PARAMS`
        uint64 slippage;
        // Portion of the interests from lending
        // that goes to SLPs (the rest goes to surplus)
        uint64 interestsForSLPs;
    }
    function mint(uint256 amount, address user, address poolManager, uint256 minStableAmount) external;
    function agToken() external view returns (address);

    function collateralMap(address poolManager)
    external
    view
    returns (
        address token,
        address sanToken,
        address perpetualManager,
        address oracle,
        uint256 stocksUsers,
        uint256 sanRate,
        uint256 collatBase,
        SLPData memory slpData,
        MintBurnData memory feeData
    );
}

interface IUniRouter {
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
    external
    payable
    returns (uint[] memory amounts);
}

interface ICurvePool {
    function remove_liquidity_one_coin(uint256, int128, uint256) external returns (uint256);
    function calc_withdraw_one_coin(uint256, int128) external view returns (uint256);
    function calc_token_amount(uint256[2] calldata, bool) external view returns (uint256);
    function add_liquidity(uint256[2] calldata, uint256) external returns (uint256);
    function coins(uint) external view returns (address);
    function get_dy(int128, int128, uint) external view returns (uint);
}

contract AgEurAdapterView {

    IUniRouter constant router = IUniRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
//    ISushiRouter constant router = ISushiRouter(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
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
            uint[2] memory amounts;
            amounts[1] = amount;
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
