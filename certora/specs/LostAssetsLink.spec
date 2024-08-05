// SPDX-License-Identifier: GPL-2.0-or-later

methods {
    // TODO: why do we need to do this?
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    // We assume that the following functions are envfree, meaning don't depend on 
    // tx, sender and block.
    function lostAssets() external returns(uint256) envfree;
    function totalAssets() external returns(uint256) envfree;
    function totalSupply() external returns(uint256) envfree;
    function lastTotalAssets() external returns(uint256) envfree;

    // Assume that it's a constant.
    function DECIMALS_OFFSET() external returns(uint8) => CONSTANT;

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
}

// TODO: this rule is timing out
invariant lostAssetsSmallerThanLastTotalAssets()
    lostAssets() <= lastTotalAssets();
