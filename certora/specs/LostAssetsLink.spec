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
    function newLostAssets() external returns(uint256) envfree;
    function MORPHO() external returns(address) envfree;

    // Summaries.
    function _.expectedSupplyAssets(MorphoHarness.MarketParams marketParams, address user) external => summaryExpectedSupplyAssets(marketParams, user) expect (uint256);
    function _.idToMarketParams(MetaMorphoHarness.Id id) external => summaryIdToMarketParams(id) expect MetaMorphoHarness.MarketParams ALL;
    function _.mulDiv(uint256 x, uint256 y, uint256 denominator, Math.Rounding rounding) internal => summaryMulDiv(x, y, denominator, rounding) expect (uint256);

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
    function MathLib.mulDivDown(uint256 a, uint256 b, uint256 c) internal returns uint256 => summaryMulDivDown(a,b,c);
    function MathLib.mulDivUp(uint256 a, uint256 b, uint256 c) internal returns uint256 => summaryMulDivUp(a,b,c);

    function Util.libId(MetaMorphoHarness.MarketParams) external returns(MetaMorphoHarness.Id) envfree;
}

function summaryExpectedSupplyAssets(MorphoHarness.MarketParams marketParams, address user) returns uint256 {
    MorphoHarness.Id id = Util.libId(marketParams);
    
    uint256 userShares = Morpho.supplyShares(id, user);
    uint256 totalSupplyAssets = Morpho.virtualTotalSupplyAssets(id);
    uint256 totalSupplyShares = Morpho.virtualTotalSupplyShares(id);

    // Safe require because the reference implementation would revert.
    return require_uint256(userShares * totalSupplyAssets / totalSupplyShares);
}

// Metamorpho's mulDiv (from OZ).
function summaryMulDiv(uint256 x, uint256 y, uint256 d, Math.Rounding rounding) returns uint256 {
    if (rounding == Math.Rounding.Floor) {
        // Safe require because the reference implementation would revert.
        return require_uint256((x * y) / d);
    } else {
        // Safe require because the reference implementation would revert.
        return require_uint256((x * y + (d - 1)) / d);
    }
}

// Morpho's mulDivUp.
function summaryMulDivUp(uint256 x, uint256 y, uint256 d) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * y + (d - 1)) / d);
}

// Morpho's mulDivDown.
function summaryMulDivDown(uint256 x, uint256 y, uint256 d) returns uint256 {
    // Safe require because the reference implementation would revert.
    return require_uint256((x * y) / d);
}

function summaryIdToMarketParams(MetaMorphoHarness.Id id) returns MetaMorphoHarness.MarketParams {
    MetaMorphoHarness.MarketParams marketParams;

    // Safe require because:
    // - markets in the supply/withdraw queue have positive lastUpdate (see LastUpdated.spec)
    // - lastUpdate(id) > 0 => marketParams.id() == id is a verified invariant in Morpho Blue.
    require Util.libId(marketParams) == id;

    return marketParams;
}

// Note that it implies newLostAssets <= totalAssets.
// Note that it implies realTotalAssets + lostAssets = lastTotalAssets after accrueInterest().
invariant realPlusLostEqualsTotal()
    realTotalAssets() + newLostAssets() == to_mathint(totalAssets());


rule lostAssetsOnlyMovesAfterUpdateWQueueAndLiquidate(method f, env e, calldataarg args) 
filtered {
    f -> f.selector != sig:liquidate(MorphoHarness.MarketParams, address, uint256, uint256, bytes).selector &&
        f.selector != sig:updateWithdrawQueue(uint256[]).selector
         
}
{
    uint256 lostAssetsBefore = lostAssets();

    f(e, args);

    uint256 lostAssetsAfter = newLostAssets();

    assert lostAssetsBefore == lostAssetsAfter;
}
