// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface ICurvePool {
    function remove_liquidity_one_coin(uint256, int128, uint256) external returns (uint256);
    function calc_withdraw_one_coin(uint256, int128) external view returns (uint256);
    function calc_token_amount(uint256[2] calldata, bool) external view returns (uint256);
    function add_liquidity(uint256[2] calldata, uint256) external returns (uint256);
    function coins(uint) external view returns (address);
    function get_dy(int128, int128, uint) external view returns (uint);
    function get_dy_underlying(int128, int128, uint) external view returns (uint);
    function exchange(int128, int128, uint, uint) external returns (uint);
    function exchange_underlying(int128, int128, uint, uint) external returns (uint);
}