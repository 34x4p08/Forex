// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

library Utils {
    using SafeERC20 for IERC20;

    function ensureMaxApproval(IERC20 asset, address actor, uint amount) internal {
        if (asset.allowance(address(this), actor) < amount) {
            asset.safeApprove(actor, 0);
            asset.safeApprove(actor, type(uint).max);
        }
    }
    function ensureExactApproval(IERC20 asset, address actor, uint amount) internal {
        asset.approve(actor, 0);
        asset.approve(actor, amount);
    }
}
