// SPDX-License-Identifier: GPL-2.0-or-later

methods {
    // TODO: why do we need to do this?
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    // We assume that the following functions are envfree, meaning don't depend on 
    // tx, sender and block.
    function hole() external returns(uint256) envfree;
    function totalAssets() external returns(uint256) envfree;
    function totalSupply() external returns(uint256) envfree;
    function lastTotalAssets() external returns(uint256) envfree;

    // Assume that it's a constant.
    function DECIMALS_OFFSET() external returns(uint8) => CONSTANT;

    // We assume that the erc20 is view. It's ok as we don't care about what happens in the token.
    function _.transfer(address, uint256) external => NONDET;
    function _.transferFrom(address, address, uint256) external => NONDET;
    function _.balanceOf(address) external => NONDET;

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

rule holeIncreases(method f, env e, calldataarg args) {
    uint256 holeBefore = hole();

    f(e, args);

    uint256 holeAfter = hole();

    assert holeBefore <= holeAfter;
}

rule lastTotalAssetsSmallerThanTotalAssets() {
    assert lastTotalAssets() <= totalAssets();
}

rule lastTotalAssetsIncreases(method f, env e, calldataarg args) 
filtered {
    f -> f.selector != sig:withdraw(uint256, address, address).selector && 
        f.selector != sig:redeem(uint256, address, address).selector && 
        f.selector != sig:updateWithdrawQueue(uint256[]).selector
}
{
    uint256 lastTotalAssetsBefore = lastTotalAssets();

    f(e, args);

    uint256 lastTotalAssetsAfter = lastTotalAssets();

    assert lastTotalAssetsBefore <= lastTotalAssetsAfter;
}

// this rule's vacuity check is timing out
rule lastTotalAssetsDecreasesCorrectlyOnWithdraw(env e, uint256 assets, address receiver, address owner) {
    uint256 lastTotalAssetsBefore = lastTotalAssets();

    withdraw(e, assets, receiver, owner);

    uint256 lastTotalAssetsAfter = lastTotalAssets();

    assert to_mathint(lastTotalAssetsAfter) >= lastTotalAssetsBefore - assets;
}

// this rule's vacuity check is timing out
rule lastTotalAssetsDecreasesCorrectlyOnRedeem(env e, uint256 shares, address receiver, address owner) {
    uint256 lastTotalAssetsBefore = lastTotalAssets();

    uint256 assets = redeem(e, shares, receiver, owner);

    uint256 lastTotalAssetsAfter = lastTotalAssets();

    assert to_mathint(lastTotalAssetsAfter) >= lastTotalAssetsBefore - assets;
}

ghost mathint sumBalances {
    init_state axiom sumBalances == 0;
}

hook Sstore _balances[KEY address user] uint256 newBalance (uint256 oldBalance) {
    sumBalances = sumBalances + newBalance - oldBalance;
}

invariant totalIsSumBalances()
    to_mathint(totalSupply()) == sumBalances;

// More precisely: share price does not decrease lower than the one at the last interaction.
// TODO: not passing yet.
rule sharePriceIncreases(method f, env e, calldataarg args) {
    requireInvariant totalIsSumBalances();

    // We query them in a state in which the vault is sync.
    uint256 lastTotalAssetsBefore = lastTotalAssets();
    uint256 totalSupplyBefore = totalSupply();

    f(e, args);

    uint256 totalAssetsAfter = totalAssets();
    uint256 totalSupplyAfter = totalSupply();
    require totalSupplyAfter > 0;

    assert lastTotalAssetsBefore * totalSupplyAfter <= totalAssetsAfter * totalSupplyBefore;
}

