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

    function test_writeTotalSupplyAssets(bytes32 id, uint128 newValue) public {
        _writeTotalSupplyAssets(id, newValue);

        assertEq(morpho.market(Id.wrap(id)).totalSupplyAssets, newValue);
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

    function test_maxWithdrawWithLostAssets(uint256 assets, uint128 expectedLostAssets) public {
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

    function test_interestAccrualWithLostAssets(uint256 assets, uint128 expectedLostAssets, uint128 interest) public {
        expectedLostAssets = test_lostAssetsValue(assets, expectedLostAssets);

        uint128 totalSupplyAssetsBefore = morpho.market(allMarkets[0].id()).totalSupplyAssets;
        interest = uint128(bound(interest, 1, type(uint128).max - totalSupplyAssetsBefore));

        _writeTotalSupplyAssets(Id.unwrap(allMarkets[0].id()), totalSupplyAssetsBefore + interest);

        uint256 expectedTotalAssets = morpho.expectedSupplyAssets(allMarkets[0], address(vault));
        uint256 totalAssetsAfter = vault.totalAssets();

        assertEq(totalAssetsAfter, expectedTotalAssets + expectedLostAssets);
    }

    function test_donationWithLostAssets(uint256 assets, uint128 expectedLostAssets, uint256 donation) public {
        expectedLostAssets = test_lostAssetsValue(assets, expectedLostAssets);

        donation = bound(donation, MIN_TEST_ASSETS, MAX_TEST_ASSETS);

        uint256 totalAssetsBefore = vault.totalAssets();

        loanToken.setBalance(SUPPLIER, donation);
        vm.prank(SUPPLIER);
        vault.deposit(donation, address(vault));

        uint256 totalAssetsAfter = vault.totalAssets();

        assertEq(totalAssetsAfter, totalAssetsBefore + donation);
    }

    function test_forcedMarketRemoval(uint256 assets0, uint256 assets1) public {
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

        assertEq(totalAssetsBefore, totalAssetsAfter);
        assertEq(vault.lostAssets(), assets0);
    }

    /// Cover.

    function test_cover(uint256 assets, uint128 lostAssets, uint256 covered) external {
        lostAssets = test_lostAssetsValue(assets, lostAssets);

        uint256 totalAssetsBefore = vault.totalAssets();

        covered = bound(covered, 0, lostAssets);

        loanToken.setBalance(address(this), covered);
        vault.coverLostAssets(covered);

        assertEq(vault.lostAssets(), lostAssets - covered);
        assertEq(vault.totalAssets(), totalAssetsBefore);
    }

    function test_coverEvent(uint256 assets, uint128 lostAssets, uint256 covered) external {
        lostAssets = test_lostAssetsValue(assets, lostAssets);

        covered = bound(covered, 0, lostAssets);

        loanToken.setBalance(address(this), covered);

        vm.expectEmit();
        emit EventsLib.UpdateLostAssets(lostAssets - covered);
        vault.coverLostAssets(covered);
    }

    function test_coverError(uint256 assets, uint128 lostAssets, uint256 covered) external {
        lostAssets = test_lostAssetsValue(assets, lostAssets);

        covered = bound(covered, lostAssets + 1, type(uint128).max);

        loanToken.setBalance(address(this), covered);

        vm.expectRevert(stdError.arithmeticError);
        vault.coverLostAssets(covered);
    }
}
