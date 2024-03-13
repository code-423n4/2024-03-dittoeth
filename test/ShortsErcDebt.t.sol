// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {STypes, SR} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {C} from "contracts/libraries/Constants.sol";
// import {console} from "contracts/libraries/console.sol";
import {Errors} from "contracts/libraries/Errors.sol";

contract ShortsErcDebtTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;

    uint64 public constant MULTIPLIER = 1 ether; // ercDebtRate

    uint88 private ercDebt100 = DEFAULT_AMOUNT.mulU88(1 ether + MULTIPLIER);
    uint88 private ercDebt101 = DEFAULT_AMOUNT.mulU88(1 ether + MULTIPLIER / 2);
    uint88 private ercDebt102 = DEFAULT_AMOUNT;
    uint88 private ercDebtTotal = ercDebt100 + ercDebt101 + ercDebt102;

    function setUp() public override {
        super.setUp();

        // ShortRecord C.SHORT_STARTING_ID created before black swan
        fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        // ShortRecord 101 created before black swan
        fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, receiver);
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        // Mimic black swan setting ercDebtRate
        testFacet.setErcDebtRate(asset, MULTIPLIER);

        // ShortRecord 101 completed after black swan
        fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, receiver);

        // ShortRecord 102 created after black swan
        fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        // Fake increasing asset ercDebt so it can be subtracted later
        uint80 ercDebtSocialized = uint80(DEFAULT_AMOUNT.mul(3 ether).div(2 ether));
        fundLimitBid(DEFAULT_PRICE, ercDebtSocialized, receiver);
        fundLimitShort(DEFAULT_PRICE, ercDebtSocialized, receiver);
    }

    function assertShortRecordsStillOpen(address shorter) public {
        STypes.ShortRecord memory short = getShortRecord(shorter, C.SHORT_STARTING_ID);
        assertTrue(short.status == SR.FullyFilled);

        short = getShortRecord(shorter, C.SHORT_STARTING_ID + 1);
        assertTrue(short.status == SR.FullyFilled);
    }

    function assertShortRecordsClosed(address shorter) public {
        STypes.ShortRecord memory short = getShortRecord(shorter, C.SHORT_STARTING_ID);
        assertTrue(short.status == SR.Closed);

        short = getShortRecord(shorter, C.SHORT_STARTING_ID + 1);
        assertTrue(short.status == SR.Closed);

        short = getShortRecord(shorter, C.SHORT_STARTING_ID + 2);
        assertTrue(short.status == SR.Closed);
    }

    function test_ErcDebtRateExitShortWallet() public {
        vm.prank(_diamond);
        token.mint(sender, ercDebtTotal);

        exitShortWallet(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender); // partial
        exitShortWallet(C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, sender); // partial
        exitShortWallet(C.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT, sender); // full
        assertShortRecordsStillOpen(sender);

        exitShortWallet(C.SHORT_STARTING_ID, ercDebt100 - DEFAULT_AMOUNT, sender); // full
        exitShortWallet(C.SHORT_STARTING_ID + 1, ercDebt101 - DEFAULT_AMOUNT, sender); // full
        assertShortRecordsClosed(sender);

        assertEq(token.balanceOf(sender), 0);
    }

    function test_ErcDebtRateExitShortErcEscrowed() public {
        depositUsd(sender, ercDebtTotal);

        exitShortErcEscrowed(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender); // partial
        exitShortErcEscrowed(C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, sender); // partial
        exitShortErcEscrowed(C.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT, sender); // full
        assertShortRecordsStillOpen(sender);

        exitShortErcEscrowed(C.SHORT_STARTING_ID, ercDebt100 - DEFAULT_AMOUNT, sender); // full
        exitShortErcEscrowed(C.SHORT_STARTING_ID + 1, ercDebt101 - DEFAULT_AMOUNT, sender); // full
        assertShortRecordsClosed(sender);

        assertEq(diamond.getAssetUserStruct(asset, sender).ercEscrowed, 0);
    }

    function test_ErcDebtRateExitShortPrimary() public {
        fundLimitAsk(DEFAULT_PRICE, ercDebtTotal, receiver);

        depositEthAndPrank(sender, 1 ether);
        increaseCollateral(C.SHORT_STARTING_ID, 0.001 ether);

        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender); // partial
        exitShort(C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, DEFAULT_PRICE, sender); // partial
        exitShort(C.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT, DEFAULT_PRICE, sender); // full
        assertShortRecordsStillOpen(sender);

        exitShort(C.SHORT_STARTING_ID, ercDebt100 - DEFAULT_AMOUNT, DEFAULT_PRICE, sender); // full
        exitShort(C.SHORT_STARTING_ID + 1, ercDebt101 - DEFAULT_AMOUNT, DEFAULT_PRICE, sender); // full
        assertShortRecordsClosed(sender);

        assertEq(getAsks().length, 0);
    }

    function test_ErcDebtRateLiquidateWallet() public {
        vm.prank(_diamond);
        token.mint(extra, ercDebtTotal);
        setETH(1000 ether);

        // Only full liquidation possible
        liquidateWallet(sender, C.SHORT_STARTING_ID, DEFAULT_AMOUNT * 2, extra); // c-ratio 0.75
        liquidateWallet(sender, C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT * 3 / 2, extra); // c-ratio 1.0
        liquidateWallet(sender, C.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT, extra); // c-ratio 1.5
        assertShortRecordsClosed(sender);

        assertEq(token.balanceOf(extra), 0);
    }

    function test_ErcDebtRateLiquidateErcEscrowed() public {
        depositUsd(extra, ercDebtTotal);
        setETH(1000 ether);

        // Only full liquidation possible
        liquidateErcEscrowed(sender, C.SHORT_STARTING_ID, DEFAULT_AMOUNT * 2, extra); // c-ratio 0.75
        liquidateErcEscrowed(sender, C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT * 3 / 2, extra); // c-ratio 1.0
        liquidateErcEscrowed(sender, C.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT, extra); // c-ratio 1.5
        assertShortRecordsClosed(sender);

        assertEq(diamond.getAssetUserStruct(asset, extra).ercEscrowed, 0);
    }

    function test_ErcDebtRateLiquidatePrimary() public {
        depositUsd(extra, ercDebtTotal);
        setETH(1600 ether);
        vm.startPrank(extra);

        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
        vm.stopPrank();
        liquidate(sender, C.SHORT_STARTING_ID, extra); // partial
        vm.prank(extra);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
        liquidate(sender, C.SHORT_STARTING_ID + 1, extra); // partial
        vm.prank(extra);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
        liquidate(sender, C.SHORT_STARTING_ID + 2, extra); // full
        assertShortRecordsStillOpen(sender);

        vm.prank(extra);
        createLimitAsk(DEFAULT_PRICE, ercDebtTotal - DEFAULT_AMOUNT * 3);
        liquidate(sender, C.SHORT_STARTING_ID, extra); // full
        liquidate(sender, C.SHORT_STARTING_ID + 1, extra); // full
        assertShortRecordsClosed(sender);

        assertEq(getAsks().length, 0);
    }

    function test_ErcDebtRateIncreaseCollateral() public {
        depositEth(sender, DEFAULT_AMOUNT); // more than necessary
        depositUsd(sender, ercDebtTotal);

        vm.startPrank(sender);
        increaseCollateral(C.SHORT_STARTING_ID, DEFAULT_PRICE);
        increaseCollateral(C.SHORT_STARTING_ID + 1, DEFAULT_PRICE);
        increaseCollateral(C.SHORT_STARTING_ID + 2, DEFAULT_PRICE);
        vm.stopPrank();

        exitShortErcEscrowed(C.SHORT_STARTING_ID, ercDebt100, sender);
        exitShortErcEscrowed(C.SHORT_STARTING_ID + 1, ercDebt101, sender);
        exitShortErcEscrowed(C.SHORT_STARTING_ID + 2, ercDebt102, sender);
        assertShortRecordsClosed(sender);

        assertEq(diamond.getAssetUserStruct(asset, sender).ercEscrowed, 0);
    }

    function test_ErcDebtRateCombineShorts() public {
        depositUsd(sender, ercDebtTotal);

        vm.prank(sender);
        combineShorts({id1: C.SHORT_STARTING_ID, id2: C.SHORT_STARTING_ID + 1});
        vm.prank(sender);
        combineShorts({id1: C.SHORT_STARTING_ID, id2: C.SHORT_STARTING_ID + 2});
        exitShortErcEscrowed(C.SHORT_STARTING_ID, ercDebtTotal, sender);
        assertShortRecordsClosed(sender);

        assertEq(diamond.getAssetUserStruct(asset, sender).ercEscrowed, 0);
    }
}
