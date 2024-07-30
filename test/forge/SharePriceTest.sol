// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/IntegrationTest.sol";

contract ModifiedMorpho {
    address public owner;
    address public feeRecipient;
    mapping(bytes32 => mapping(address => Position)) public position;
    mapping(bytes32 => Market) public market;

    function writeTotalSupplyAssets(bytes32 id, uint128 newValue) external {
        market[id].totalSupplyAssets = newValue;
    }
}

contract SharePriceTest is IntegrationTest {
    using stdStorage for StdStorage;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    bytes modifiedCode = _makeModifiedCode();
    bytes normalCode = address(morpho).code;

    function _makeModifiedCode() internal returns (bytes memory) {
        return address(new ModifiedMorpho()).code;
    }

    function _writeTotalSupplyAssets(bytes32 id, uint128 newValue) internal {
        vm.etch(address(morpho), modifiedCode);
        ModifiedMorpho(address(morpho)).writeTotalSupplyAssets(id, newValue);
        vm.etch(address(morpho), normalCode);
    }

    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP);
        _sortSupplyQueueIdleLast();
    }

    function test_totalAssetsCannotDecrease(uint256 assets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint256 totalAssetsBefore = vault.totalAssets();
        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), 0);
        uint256 totalAssetsAfter = vault.totalAssets();

        assertGe(totalAssetsAfter, totalAssetsBefore, "totalAssets decreased");
    }

    function invariant_totalAssetsCannotDecrease() public {
        uint256 totalAssetsBefore = vault.totalAssets();
        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), 0);
        uint256 totalAssetsAfter = vault.totalAssets();

        assertGe(totalAssetsAfter, totalAssetsBefore, "totalAssets decreased");
    }
}
