// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U88} from "contracts/libraries/PRBMathHelper.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {C} from "contracts/libraries/Constants.sol";

import {console} from "contracts/libraries/console.sol";

contract AskRevertTest is OBFixture {
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
    }

    // Testing making more shortRecords than uint8 max
    function test_Revert_CannotMakeMoreSR() public {
        for (uint256 i = C.SHORT_STARTING_ID; i < C.SHORT_MAX_ID; i++) {
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        }

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        depositEthAndPrank(sender, 10 ether);
        vm.expectRevert(Errors.CannotMakeMoreThanMaxSR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_CannotCreateLimitShortNoDeposit() public {
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        diamond.createLimitShort(
            asset, 1 ether, DEFAULT_AMOUNT.mulU88(2 ether), badOrderHintArray, shortHintArrayStorage, initialCR
        );
    }

    function test_CannotCreateLimitAskNoDeposit() public {
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        createLimitAsk(1 ether, 2 ether);
    }

    function test_CannotCreateLimitShortWithoutEnoughDeposit() public {
        depositEthAndPrank(sender, 4 ether);
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        diamond.createLimitShort(asset, 1 ether, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);

        depositEthAndPrank(sender, 1 ether - 1 wei);
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        diamond.createLimitShort(asset, 1 ether, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_CannotCreateLimitAskWithoutEnoughDeposit() public {
        depositEthAndPrank(sender, 1 ether);
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        createLimitAsk(1 ether + 1 wei, 1 ether);
    }

    function test_CannotCreateMarketAskWithoutEnoughDeposit() public {
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT * 2);
    }

    function test_CannotCreateLimitShortWithPriceOrQuantity0() public {
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createLimitShort(asset, 0, 0, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_CannotCreateLimitAskWithPriceOrQuantity0() public {
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        createLimitAsk(0, 0);
    }

    function test_CannotCreateMarketAskWithPriceOrQuantity0() public {
        vm.startPrank(sender);
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createAsk(asset, DEFAULT_PRICE, 0, C.MARKET_ORDER, badOrderHintArray);

        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createAsk(asset, 0, 1 ether, C.MARKET_ORDER, badOrderHintArray);
    }

    function test_CannotSellUnderMinimumSize() public {
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createAsk(asset, DEFAULT_PRICE, 0.3999 ether, C.MARKET_ORDER, badOrderHintArray);
    }
}
