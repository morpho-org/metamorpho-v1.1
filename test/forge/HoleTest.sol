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

contract HoleTest is IntegrationTest {
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

    function test_totalAssetsDecrease(uint256 assets, uint128 expectedHole) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        expectedHole = uint128(bound(expectedHole, 0, totalSupplyAssetsBefore));

        uint256 totalAssetsBefore = vault.totalAssets();
        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - expectedHole);
        uint256 totalAssetsAfter = vault.totalAssets();

        assertLe(totalAssetsAfter, totalAssetsBefore, "totalAssets did not decreased");
    }

    function test_lastTotalAssetsNoDecrease(uint256 assets, uint128 expectedHole) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        expectedHole = uint128(bound(expectedHole, 0, totalSupplyAssetsBefore));

        uint256 lastTotalAssetsBefore = vault.lastTotalAssets();
        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - expectedHole);
        vault.deposit(0, ONBEHALF); // update hole.
        uint256 lastTotalAssetsAfter = vault.lastTotalAssets();

        assertGe(lastTotalAssetsAfter, lastTotalAssetsBefore, "totalAssets did not decreased");
    }

    function test_holeValue() public {
        loanToken.setBalance(SUPPLIER, 1 ether);

        vm.prank(SUPPLIER);
        vault.deposit(1 ether, ONBEHALF);

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), 0.5 ether);

        vault.deposit(0, ONBEHALF); // update hole.

        assertEq(vault.hole(), 0.5 ether, "hole");
    }

    function test_holeValue(uint256 assets, uint128 expectedHole) public returns (uint128) {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        expectedHole = uint128(bound(expectedHole, 0, totalSupplyAssetsBefore));

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - expectedHole);

        vault.deposit(0, ONBEHALF); // update hole.

        assertEq(vault.hole(), expectedHole, "hole");

        return expectedHole;
    }

    function test_resupplyOnHole(uint256 assets, uint128 expectedHole, uint256 assets2) public {
        expectedHole = test_holeValue(assets, expectedHole);

        assets2 = bound(assets2, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets2);

        vm.prank(SUPPLIER);
        vault.deposit(assets2, ONBEHALF);

        assertEq(vault.hole(), expectedHole, "hole");
    }

    function test_newHoleOnHole(uint256 firstSupply, uint128 firstHole, uint256 secondSupply, uint128 secondHole)
        public
    {
        firstHole = test_holeValue(firstSupply, firstHole);

        secondSupply = bound(secondSupply, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, secondSupply);

        vm.prank(SUPPLIER);
        vault.deposit(secondSupply, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        secondHole = uint128(bound(secondHole, 0, totalSupplyAssetsBefore));

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - secondHole);

        vault.deposit(0, ONBEHALF); // update hole.

        assertEq(vault.hole(), firstHole + secondHole, "hole");
    }

    function test_HoleEvent(uint256 assets, uint128 expectedHole) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        expectedHole = uint128(bound(expectedHole, 0, totalSupplyAssetsBefore));

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - expectedHole);

        vm.expectEmit();
        emit EventsLib.UpdateHole(expectedHole);
        vault.deposit(0, ONBEHALF); // update hole.

        assertEq(vault.hole(), expectedHole, "totalAssets decreased");
    }

    function test_maxWithdrawWithHole() public {
        loanToken.setBalance(SUPPLIER, 1 ether);

        vm.prank(SUPPLIER);
        vault.deposit(1 ether, ONBEHALF);

        assertEq(vault.maxWithdraw(ONBEHALF), 1 ether);

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), 0.5 ether);

        vault.deposit(0, ONBEHALF); // update hole.

        assertEq(vault.maxWithdraw(ONBEHALF), 0.5 ether);
    }

    function test_maxWithdrawWithHole(uint256 assets, uint128 expectedHole) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        expectedHole = uint128(bound(expectedHole, 0, totalSupplyAssetsBefore));

        assertEq(vault.maxWithdraw(ONBEHALF), totalSupplyAssetsBefore);

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - expectedHole);

        vault.deposit(0, ONBEHALF); // update hole.

        assertEq(vault.maxWithdraw(ONBEHALF), totalSupplyAssetsBefore - expectedHole);
    }
}
