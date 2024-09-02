// SPDX-License-Identifier: GPL-2.0-or-later

using MorphoHarness as Morpho;
using Util as Util;

methods {
    function convertToAssets(uint256) external returns(uint256) envfree;
    function balanceOf(address) external returns(uint256) envfree;

    function Morpho.supplyShares(MorphoHarness.Id, address) external returns uint256 envfree;
    function Morpho.totalSupplyAssets(MorphoHarness.Id) external returns uint256 envfree;
    function Morpho.totalSupplyShares(MorphoHarness.Id) external returns uint256 envfree;
    function Morpho.libMulDivDown(uint256, uint256, uint256) external returns uint256 envfree;

    function Util.toAssetsDown(uint256, uint256, uint256) external returns(uint256) envfree;

    function _.expectedSupplyAssets(MorphoHarness.Id id, address user) external => supplyAssets(id, user) expect uint256;
}

function networth(address user) returns int256 {
    int256 debt = require_int256(10^18);
    int256 deposit = require_int256(balanceOf(user));
    uint256 assets = require_uint256(deposit - debt);
    return require_int256(convertToAssets(assets));
}

function supplyAssets(MetaMorphoHarness.Id id, address user) returns uint256 {
    uint256 shares = Morpho.supplyShares(id, user);
    uint256 totalSupplyAssets = Morpho.totalSupplyAssets(id);
    uint256 totalSupplyShares = Morpho.totalSupplyShares(id);
    require shares <= totalSupplyShares;
    return Util.toAssetsDown(shares, totalSupplyAssets, totalSupplyShares);
}

rule decreasingNetworth(env e, method f, calldataarg args, address user) {
    int256 initialNetworth = networth(user);

    f(e, args);

    int256 finalNetworth = networth(user);

    assert finalNetworth <= initialNetworth;
}
