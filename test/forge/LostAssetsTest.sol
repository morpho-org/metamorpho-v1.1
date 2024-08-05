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

contract LostAssetsTest is IntegrationTest {
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

    function test_totalAssetsDecrease(uint256 assets, uint128 expectedLostAssets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        expectedLostAssets = uint128(bound(expectedLostAssets, 0, totalSupplyAssetsBefore));

        uint256 totalAssetsBefore = vault.totalAssets();
        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - expectedLostAssets);
        uint256 totalAssetsAfter = vault.totalAssets();

        assertLe(totalAssetsAfter, totalAssetsBefore, "totalAssets did not decreased");
    }

    function test_lastTotalAssetsNoDecrease(uint256 assets, uint128 expectedLostAssets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        expectedLostAssets = uint128(bound(expectedLostAssets, 0, totalSupplyAssetsBefore));

        uint256 lastTotalAssetsBefore = vault.lastTotalAssets();
        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - expectedLostAssets);
        vault.deposit(0, ONBEHALF); // update lostAssets.
        uint256 lastTotalAssetsAfter = vault.lastTotalAssets();

        assertGe(lastTotalAssetsAfter, lastTotalAssetsBefore, "totalAssets did not decreased");
    }

    function test_lostAssetsValue() public {
        loanToken.setBalance(SUPPLIER, 1 ether);

        vm.prank(SUPPLIER);
        vault.deposit(1 ether, ONBEHALF);

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), 0.5 ether);

        vault.deposit(0, ONBEHALF); // update lostAssets.

        assertEq(vault.lostAssets(), 0.5 ether, "lostAssets");
    }

    function test_lostAssetsValue(uint256 assets, uint128 expectedLostAssets) public returns (uint128) {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        expectedLostAssets = uint128(bound(expectedLostAssets, 0, totalSupplyAssetsBefore));

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - expectedLostAssets);

        vault.deposit(0, ONBEHALF); // update lostAssets.

        assertEq(vault.lostAssets(), expectedLostAssets, "lostAssets");

        return expectedLostAssets;
    }

    function test_resupplyOnLostAssets(uint256 assets, uint128 expectedLostAssets, uint256 assets2) public {
        expectedLostAssets = test_lostAssetsValue(assets, expectedLostAssets);

        assets2 = bound(assets2, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets2);

        vm.prank(SUPPLIER);
        vault.deposit(assets2, ONBEHALF);

        assertEq(vault.lostAssets(), expectedLostAssets, "lostAssets");
    }

    function test_newLostAssetsOnLostAssets(
        uint256 firstSupply,
        uint128 firstLostAssets,
        uint256 secondSupply,
        uint128 secondLostAssets
    ) public {
        firstLostAssets = test_lostAssetsValue(firstSupply, firstLostAssets);

        secondSupply = bound(secondSupply, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, secondSupply);

        vm.prank(SUPPLIER);
        vault.deposit(secondSupply, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        secondLostAssets = uint128(bound(secondLostAssets, 0, totalSupplyAssetsBefore));

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - secondLostAssets);

        vault.deposit(0, ONBEHALF); // update lostAssets.

        assertEq(vault.lostAssets(), firstLostAssets + secondLostAssets, "lostAssets");
    }

    function test_LostAssetsEvent(uint256 assets, uint128 expectedLostAssets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        expectedLostAssets = uint128(bound(expectedLostAssets, 0, totalSupplyAssetsBefore));

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - expectedLostAssets);

        vm.expectEmit();
        emit EventsLib.UpdateLostAssets(expectedLostAssets);
        vault.deposit(0, ONBEHALF); // update lostAssets.

        assertEq(vault.lostAssets(), expectedLostAssets, "totalAssets decreased");
    }

    function test_maxWithdrawWithLostAssets() public {
        loanToken.setBalance(SUPPLIER, 1 ether);

        vm.prank(SUPPLIER);
        vault.deposit(1 ether, ONBEHALF);

        assertEq(vault.maxWithdraw(ONBEHALF), 1 ether);

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), 0.5 ether);

        vault.deposit(0, ONBEHALF); // update lostAssets.

        assertEq(vault.maxWithdraw(ONBEHALF), 0.5 ether);
    }

    function test_maxWithdrawWithLostAssets(uint256 assets, uint128 expectedLostAssets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        expectedLostAssets = uint128(bound(expectedLostAssets, 0, totalSupplyAssetsBefore));

        assertEq(vault.maxWithdraw(ONBEHALF), totalSupplyAssetsBefore);

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - expectedLostAssets);

        vault.deposit(0, ONBEHALF); // update lostAssets.

        assertEq(vault.maxWithdraw(ONBEHALF), totalSupplyAssetsBefore - expectedLostAssets);
    }
}
