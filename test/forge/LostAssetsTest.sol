// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "./helpers/IntegrationTest.sol";

contract LostAssetsTest is IntegrationTest {
    using stdStorage for StdStorage;
    using MorphoBalancesLib for IMorpho;
    using MarketParamsLib for MarketParams;

    function _writeTotalSupplyAssets(bytes32 id, uint128 newValue) internal {
        uint256 marketSlot = 3;
        bytes32 totalSupplySlot = keccak256(abi.encode(id, marketSlot));
        bytes32 totalSupplyValue = vm.load(address(morpho), totalSupplySlot);
        bytes32 newTotalSupplyValue = (totalSupplyValue >> 128 << 128) | bytes32(uint256(newValue));
        vm.store(address(morpho), totalSupplySlot, newTotalSupplyValue);
    }

    function setUp() public override {
        super.setUp();

        _setCap(allMarkets[0], CAP);
        _sortSupplyQueueIdleLast();
    }

    function testWriteTotalSupplyAssets(bytes32 id, uint128 newValue) public {
        _writeTotalSupplyAssets(id, newValue);

        assertEq(morpho.market(Id.wrap(id)).totalSupplyAssets, newValue);
    }

    function testTotalAssetsNoDecrease(uint256 assets, uint128 expectedLostAssets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        expectedLostAssets = uint128(bound(expectedLostAssets, 0, totalSupplyAssetsBefore));

        uint256 totalAssetsBefore = vault.totalAssets();
        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - expectedLostAssets);
        uint256 totalAssetsAfter = vault.totalAssets();

        assertEq(totalAssetsAfter, totalAssetsBefore, "totalAssets decreased");
    }

    function testLastTotalAssetsNoDecrease(uint256 assets, uint128 expectedLostAssets) public {
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

        assertGe(lastTotalAssetsAfter, lastTotalAssetsBefore, "totalAssets decreased");
    }

    function testLostAssetsValue() public {
        loanToken.setBalance(SUPPLIER, 1 ether);

        vm.prank(SUPPLIER);
        vault.deposit(1 ether, ONBEHALF);

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), 0.5 ether);

        vault.deposit(0, ONBEHALF); // update lostAssets.

        assertEq(vault.lostAssets(), 0.5 ether, "expected lostAssets");
    }

    function testLostAssetsValue(uint256 assets, uint128 expectedLostAssets) public returns (uint128) {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        expectedLostAssets = uint128(bound(expectedLostAssets, 0, totalSupplyAssetsBefore));

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - expectedLostAssets);

        vault.deposit(0, ONBEHALF); // update lostAssets.

        assertEq(vault.lostAssets(), expectedLostAssets, "expected lostAssets");

        return expectedLostAssets;
    }

    function testResupplyOnLostAssets(uint256 assets, uint128 expectedLostAssets, uint256 assets2) public {
        expectedLostAssets = testLostAssetsValue(assets, expectedLostAssets);

        assets2 = bound(assets2, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets2);

        vm.prank(SUPPLIER);
        vault.deposit(assets2, ONBEHALF);

        assertEq(vault.lostAssets(), expectedLostAssets, "lostAssets after resupply");
    }

    function testNewLostAssetsOnLostAssets(
        uint256 firstSupply,
        uint128 firstLostAssets,
        uint256 secondSupply,
        uint128 secondLostAssets
    ) public {
        firstLostAssets = testLostAssetsValue(firstSupply, firstLostAssets);

        secondSupply = bound(secondSupply, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, secondSupply);

        vm.prank(SUPPLIER);
        vault.deposit(secondSupply, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        secondLostAssets = uint128(bound(secondLostAssets, 0, totalSupplyAssetsBefore));

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - secondLostAssets);

        vault.deposit(0, ONBEHALF); // update lostAssets.

        assertEq(vault.lostAssets(), firstLostAssets + secondLostAssets, "lostAssets after new loss");
    }

    function testLostAssetsEvent(uint256 assets, uint128 expectedLostAssets) public {
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

    function testMaxWithdrawWithLostAssets(uint256 assets, uint128 expectedLostAssets) public {
        assets = bound(assets, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        loanToken.setBalance(SUPPLIER, assets);

        vm.prank(SUPPLIER);
        vault.deposit(assets, ONBEHALF);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        expectedLostAssets = uint128(bound(expectedLostAssets, 1, totalSupplyAssetsBefore));

        assertEq(vault.maxWithdraw(ONBEHALF), totalSupplyAssetsBefore);

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore - expectedLostAssets);

        vault.deposit(0, ONBEHALF); // update lostAssets.

        assertEq(vault.maxWithdraw(ONBEHALF), totalSupplyAssetsBefore - expectedLostAssets);
    }

    function testInterestAccrualWithLostAssets(uint256 assets, uint128 expectedLostAssets, uint128 interest) public {
        expectedLostAssets = testLostAssetsValue(assets, expectedLostAssets);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        interest = uint128(bound(interest, 1, type(uint128).max - totalSupplyAssetsBefore));

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore + interest);

        uint256 expectedTotalAssets = morpho.expectedSupplyAssets(allMarkets[0], address(vault));
        uint256 totalAssetsAfter = vault.totalAssets();

        assertEq(totalAssetsAfter, expectedTotalAssets + expectedLostAssets);
    }

    function testDonationWithLostAssets(uint256 assets, uint128 expectedLostAssets, uint256 donation) public {
        expectedLostAssets = testLostAssetsValue(assets, expectedLostAssets);

        donation = bound(donation, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        uint256 totalAssetsBefore = vault.totalAssets();

        loanToken.setBalance(SUPPLIER, donation);
        vm.prank(SUPPLIER);
        morpho.supply(allMarkets[0], donation, 0, address(vault), "");

        uint256 totalAssetsAfter = vault.totalAssets();

        assertEq(totalAssetsAfter, totalAssetsBefore + donation);
    }

    function testForcedMarketRemoval(uint256 assets0, uint256 assets1) public {
        assets0 = bound(assets0, MIN_TEST_ASSETS, MAX_TEST_ASSETS);
        assets1 = bound(assets1, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        _setCap(allMarkets[0], type(uint128).max);
        Id[] memory supplyQueue = new Id[](1);
        supplyQueue[0] = allMarkets[0].id();
        vm.prank(CURATOR);
        vault.setSupplyQueue(supplyQueue);

        loanToken.setBalance(SUPPLIER, assets0);
        vm.prank(SUPPLIER);
        vault.deposit(assets0, address(vault));

        _setCap(allMarkets[1], type(uint128).max);
        supplyQueue[0] = allMarkets[1].id();
        vm.prank(CURATOR);
        vault.setSupplyQueue(supplyQueue);

        loanToken.setBalance(SUPPLIER, assets1);
        vm.prank(SUPPLIER);
        vault.deposit(assets1, address(vault));

        _setCap(allMarkets[0], 0);
        vm.prank(CURATOR);
        vault.submitMarketRemoval(allMarkets[0]);
        vm.warp(block.timestamp + vault.timelock());

        uint256 totalAssetsBefore = vault.totalAssets();

        uint256[] memory withdrawQueue = new uint256[](2);
        withdrawQueue[0] = 0;
        withdrawQueue[1] = 2;
        vm.prank(CURATOR);
        vault.updateWithdrawQueue(withdrawQueue);

        uint256 totalAssetsAfter = vault.totalAssets();

        vault.deposit(0, ONBEHALF); // update lostAssets.

        assertEq(totalAssetsBefore, totalAssetsAfter + assets0);
        assertEq(vault.lostAssets(), 0);
    }
}
