// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {STypes, MTypes, O, SR} from "contracts/libraries/DataTypes.sol";
import {C} from "contracts/libraries/Constants.sol";

import {OBFixture} from "test/utils/OBFixture.sol";

import {console} from "contracts/libraries/console.sol";

contract shortRecordCounterTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }

    function test_shortRecordCounter_UnfilledShortOrders() public {
        for (uint256 i = C.SHORT_STARTING_ID; i < C.SHORT_MAX_ID; i++) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        }
        vm.prank(sender);
        vm.expectRevert(Errors.CannotMakeMoreThanMaxSR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_shortRecordCounter_MaxActiveShorts() public {
        for (uint256 i = C.SHORT_STARTING_ID; i < C.SHORT_MAX_ID; i++) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }

        vm.prank(sender);
        vm.expectRevert(Errors.CannotMakeMoreThanMaxSR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_shortRecordCounter_UnfilledShortOrders_CancelShort() public {
        for (uint256 i = C.SHORT_STARTING_ID; i < C.SHORT_MAX_ID; i++) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        }

        vm.prank(sender);
        cancelShort(C.STARTING_ID);
        //@dev cancelling the short opened up a slot for the shorter to make another short
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        vm.prank(sender);
        vm.expectRevert(Errors.CannotMakeMoreThanMaxSR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_shortRecordCounter_DeleteShortRecord_ExitShortPrimary() public {
        for (uint256 i = C.SHORT_STARTING_ID; i < C.SHORT_MAX_ID; i++) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }

        //@dev exit a short
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);

        //@dev deleting the short opened up a slot for the shorter to make another short
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        vm.prank(sender);
        vm.expectRevert(Errors.CannotMakeMoreThanMaxSR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_shortRecordCounter_DeleteShortRecord_ExitShortErcEscrowed() public {
        for (uint256 i = C.SHORT_STARTING_ID; i < C.SHORT_MAX_ID; i++) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }

        //@dev exit a short
        depositUsd(sender, DEFAULT_AMOUNT);
        exitShortErcEscrowed(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);

        //@dev deleting the short opened up a slot for the shorter to make another short
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        vm.prank(sender);
        vm.expectRevert(Errors.CannotMakeMoreThanMaxSR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_shortRecordCounter_DeleteShortRecord_ExitShortWallet() public {
        for (uint256 i = C.SHORT_STARTING_ID; i < C.SHORT_MAX_ID; i++) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }

        //@dev exit a short
        vm.prank(_diamond);
        token.mint(sender, DEFAULT_AMOUNT);
        exitShortWallet(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);

        //@dev deleting the short opened up a slot for the shorter to make another short
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        vm.prank(sender);
        vm.expectRevert(Errors.CannotMakeMoreThanMaxSR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_shortRecordCounter_DeleteShortRecord_LiquidationPrimary() public {
        for (uint256 i = C.SHORT_STARTING_ID; i < C.SHORT_MAX_ID; i++) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }

        _setETH(2600 ether);

        //@dev liquidate a short
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        vm.prank(extra);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);

        //@dev deleting the short opened up a slot for the shorter to make another short
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        vm.prank(sender);
        vm.expectRevert(Errors.CannotMakeMoreThanMaxSR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_shortRecordCounter_DeleteShortRecord_LiquidationErcEscrowed() public {
        for (uint256 i = C.SHORT_STARTING_ID; i < C.SHORT_MAX_ID; i++) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }

        _setETH(750 ether);

        //@dev liquidate a short
        depositUsd(extra, DEFAULT_AMOUNT);
        liquidateErcEscrowed(sender, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, extra);

        //@dev deleting the short opened up a slot for the shorter to make another short
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        vm.prank(sender);
        vm.expectRevert(Errors.CannotMakeMoreThanMaxSR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_shortRecordCounter_DeleteShortRecord_LiquidationWallet() public {
        for (uint256 i = C.SHORT_STARTING_ID; i < C.SHORT_MAX_ID; i++) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }

        _setETH(750 ether);

        //@dev liquidate a short
        vm.prank(_diamond);
        token.mint(extra, DEFAULT_AMOUNT);
        liquidateWallet(sender, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, extra);

        //@dev deleting the short opened up a slot for the shorter to make another short
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        vm.prank(sender);
        vm.expectRevert(Errors.CannotMakeMoreThanMaxSR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_shortRecordCounter_DeleteShortRecord_CombineShort() public {
        for (uint256 i = C.SHORT_STARTING_ID; i < C.SHORT_MAX_ID; i++) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }

        vm.prank(sender);
        combineShorts({id1: C.SHORT_STARTING_ID, id2: C.SHORT_STARTING_ID + 2});

        //@dev deleting the short opened up a slot for the shorter to make another short
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        vm.prank(sender);
        vm.expectRevert(Errors.CannotMakeMoreThanMaxSR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_shortRecordCounter_DeleteShortRecord_TransferShort() public {
        for (uint256 i = C.SHORT_STARTING_ID; i < C.SHORT_MAX_ID; i++) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }

        vm.prank(sender);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, 0);
        vm.prank(sender);
        diamond.transferFrom(sender, extra, 1);

        //@dev deleting the short opened up a slot for the shorter to make another short
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        vm.prank(sender);
        vm.expectRevert(Errors.CannotMakeMoreThanMaxSR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }
}
