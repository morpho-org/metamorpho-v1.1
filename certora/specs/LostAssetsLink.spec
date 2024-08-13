// SPDX-License-Identifier: GPL-2.0-or-later

using MorphoHarness as Morpho;
using Util as Util;

methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function lostAssets() external returns(uint256) envfree;
    function totalAssets() external returns(uint256) envfree;
    function totalSupply() external returns(uint256) envfree;
    function lastTotalAssets() external returns(uint256) envfree;
    function realTotalAssets() external returns(uint256) envfree;
    function MORPHO() external returns(address) envfree;

    function _.expectedSupplyAssets(MorphoHarness.MarketParams marketParams, address user) external => summaryExpectedSupplyAssets(marketParams, user) expect (uint256);

    // We assume that the erc20 is view. It's ok as we don't care about what happens in the token.
    function _.transfer(address, uint256) external => NONDET;
    function _.transferFrom(address, address, uint256) external => NONDET;
    function _.balanceOf(address) external => NONDET;

    // We assume that the borrow rate is view.
    function _.borrowRate(MorphoHarness.MarketParams, MorphoHarness.Market) external => NONDET;

    // We deactivate callbacks. 
    // Ideally we can assume that they can't change arbitrarily the storage of Morpho 
    // and Metamorpho, but can only reenter through public entry-points, but I don't 
    // know how to do this.
    function _.onMorphoSupply(uint256, bytes) external => NONDET;
    function _.onMorphoRepay(uint256, bytes) external => NONDET;
    function _.onMorphoSupplyCollateral(uint256, bytes) external => NONDET;
    function _.onMorphoLiquidate(uint256, bytes) external => NONDET;
    function _.onMorphoFlashLoan(uint256, bytes) external => NONDET;

    function Morpho.supplyShares(MorphoHarness.Id, address) external returns uint256 envfree;
    function Morpho.virtualTotalSupplyAssets(MorphoHarness.Id) external returns uint256 envfree;
    function Morpho.virtualTotalSupplyShares(MorphoHarness.Id) external returns uint256 envfree;
    function Morpho.libMulDivDown(uint256, uint256, uint256) external returns uint256 envfree;
    function Morpho.libMulDivDown(uint256, uint256, uint256) external returns uint256 envfree;

    function Util.libId(MetaMorphoHarness.MarketParams) external returns(MetaMorphoHarness.Id) envfree;
}

function summaryExpectedSupplyAssets(MorphoHarness.MarketParams marketParams, address user) returns uint256 {
    MorphoHarness.Id id = Util.libId(marketParams);
    
    uint256 userShares = Morpho.supplyShares(id, user);
    uint256 totalSupplyAssets = Morpho.virtualTotalSupplyAssets(id);
    uint256 totalSupplyShares = Morpho.virtualTotalSupplyShares(id);

    return Morpho.libMulDivDown(userShares, totalSupplyAssets, totalSupplyShares);
}

// Note that it implies lostAssets <= lastTotalAssets.
invariant realPlusLostEqualsLastTotal()
    realTotalAssets() + lostAssets() == to_mathint(lastTotalAssets());
