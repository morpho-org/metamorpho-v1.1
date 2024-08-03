// SPDX-License-Identifier: GPL-2.0-or-later

methods {
    // TODO: why do we need to do this?
    function multicall(bytes[]) external returns(bytes[]) => NONDET DELETE;

    function hole() external returns(uint256) envfree;
    function totalAssets() external returns(uint256) envfree;
    function totalSupply() external returns(uint256) envfree;
    function lastTotalAssets() external returns(uint256) envfree;

    // Assume that it's a constant.
    function DECIMALS_OFFSET() external returns(uint8) => CONSTANT;

    // Assume that this method is view.
    function _.expectedSupplyAssets(MetaMorphoHarness.MarketParams market, address user) external => NONDET;
}

rule holeIncreases(method f, env e, calldataarg args) {
    uint256 holeBefore = hole();

    f(e, args);

    uint256 holeAfter = hole();

    assert holeBefore <= holeAfter;
}

invariant holeSmallerThanLastTotalAssets()
    hole() <= lastTotalAssets();

invariant lastTotalAssetsSmallerThanTotalAssets()
    lastTotalAssets() <= totalAssets();

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

// More precisely: share price does not decrease lower than the one at the last interaction.
rule sharePriceIncreases(method f, env e, calldataarg args) 
{
    // We query them in a state in which the vault is sync.
    uint256 lastTotalAssetsBefore = lastTotalAssets();
    uint256 totalSupplyBefore = totalSupply();

    f(e, args);

    uint256 totalAssetsAfter = totalAssets();
    uint256 totalSupplyAfter = totalSupply();

    assert lastTotalAssetsBefore * totalSupplyAfter <= totalAssetsAfter * totalSupplyBefore;
}
