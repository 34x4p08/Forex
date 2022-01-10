// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

library Utils {
    function ensureMaxApproval(IERC20 asset, address actor, uint amount) internal {
        if (asset.allowance(address(this), actor) < amount) {
            asset.approve(actor, 0);
            asset.approve(actor, type(uint).max);
        }
    }
    function ensureExactApproval(IERC20 asset, address actor, uint amount) internal {
        asset.approve(actor, 0);
        asset.approve(actor, amount);
    }
}
