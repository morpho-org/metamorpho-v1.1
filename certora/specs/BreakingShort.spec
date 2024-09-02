// SPDX-License-Identifier: GPL-2.0-or-later

methods {
    function convertToAssets(uint256) external returns(uint256) envfree;
    function balanceOf(address) external returns(uint256) envfree;
}

function networth(address user) returns int256 {
    int256 debt = require_int256(10^18);
    int256 deposit = require_int256(balanceOf(user));
    uint256 assets = require_uint256(deposit - debt);
    return require_int256(convertToAssets(assets));
}

rule decreasingNetworth(env e, method f, calldataarg args, address user) {
    int256 initialNetworth = networth(user);

    f(e, args);

    int256 finalNetworth = networth(user);

    assert finalNetworth <= initialNetworth;
}
