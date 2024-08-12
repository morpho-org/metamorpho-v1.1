// SPDX-License-Identifier: GPL-2.0-or-later

methods {
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function lostAssets() external returns(uint256) envfree;
    function totalAssets() external returns(uint256) envfree;
    function totalSupply() external returns(uint256) envfree;
    function lastTotalAssets() external returns(uint256) envfree;
    function realTotalAssets() external returns(uint256) envfree;
    function fee() external returns(uint96) envfree;
    function maxFee() external returns(uint256) envfree;

    // We assume that Morpho and the ERC20s can't touch back Metamorpho.
    // TODO: improve this, and assume that there can be reentrancies through public entry-points.
    function _.supply(MetaMorphoHarness.MarketParams, uint256, uint256, address, bytes) external => NONDET;
    function _.withdraw(MetaMorphoHarness.MarketParams, uint256, uint256, address, address) external => NONDET;
    function _.accrueInterest(MetaMorphoHarness.MarketParams) external => NONDET;
    function _.idToMarketParams(MetaMorphoHarness.Id) external => NONDET;
    function _.supplyShares(MetaMorphoHarness.Id, address) external => NONDET;
    function _.expectedSupplyAssets(MetaMorphoHarness.MarketParams, address) external => CONSTANT;
    function _.market(MetaMorphoHarness.Id) external => NONDET;
    
    function _.transfer(address, uint256) external => NONDET;
    function _.transferFrom(address, address, uint256) external => NONDET;
    function _.balanceOf(address) external => NONDET;
}

rule lostAssetsIncreases(method f, env e, calldataarg args) {
    uint256 lostAssetsBefore = lostAssets();

    f(e, args);

    uint256 lostAssetsAfter = lostAssets();

    assert lostAssetsBefore <= lostAssetsAfter;
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

hook Sload uint256 balance _balances[KEY address addr] {
    require sumBalances >= to_mathint(balance);
}

hook Sstore _balances[KEY address user] uint256 newBalance (uint256 oldBalance) {
    sumBalances = sumBalances + newBalance - oldBalance;
}

strong invariant totalIsSumBalances()
    to_mathint(totalSupply()) == sumBalances;

// // More precisely: share price does not decrease lower than the one at the last interaction.
// // TODO: not passing, but I don't understand how
// rule sharePriceIncreases(method f, env e, calldataarg args) {
//     requireInvariant totalIsSumBalances();
//     require assert_uint256(fee()) == 0;

//     // We query them in a state in which the vault is sync.
//     uint256 lastTotalAssetsBefore = lastTotalAssets();
//     uint256 totalSupplyBefore = totalSupply();
//     require totalSupplyBefore > 0;

//     f(e, args);

//     uint256 totalAssetsAfter = lastTotalAssets();
//     uint256 totalSupplyAfter = totalSupply();
//     require totalSupplyAfter > 0;

//     uint256 decimalsOffset = assert_uint256(DECIMALS_OFFSET());
//     require decimalsOffset == 18;

//     assert (lastTotalAssetsBefore + 1) * (totalSupplyAfter + 10^decimalsOffset) <= (totalAssetsAfter + 1) * (totalSupplyBefore + 10^decimalsOffset);
// }
