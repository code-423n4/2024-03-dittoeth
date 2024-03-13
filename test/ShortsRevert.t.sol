// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {C} from "contracts/libraries/Constants.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {MTypes, STypes, O, SR} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract ShortsRevertTest is OBFixture {
    uint16 private lastShortId;

    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }

    function makeShorts() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(2 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(2 ether, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(3 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(3 ether, DEFAULT_AMOUNT, sender);

        r.ercEscrowed = DEFAULT_AMOUNT * 3;

        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function test_CannotExitWithNoShorts() public {
        // @dev have to set here like this because the revert will incorrectly catch the getLastShortId()
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.exitShort(asset, 100, DEFAULT_AMOUNT, DEFAULT_PRICE, shortHintArrayStorage, 0);
    }

    function test_RevertCombineMaxShorts() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, 300_000_000 ether, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, 300_000_000 ether, sender);
        fundLimitBidOpt(DEFAULT_PRICE, 300_000_000 ether, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, 300_000_000 ether, sender);

        uint8[] memory shortRecords = new uint8[](3);
        shortRecords[0] = C.SHORT_STARTING_ID;
        shortRecords[1] = C.SHORT_STARTING_ID + 1;
        shortRecords[2] = C.SHORT_STARTING_ID + 2;

        uint16[] memory shortOrderIds = new uint16[](3);
        shortOrderIds[0] = 0;
        shortOrderIds[1] = 0;
        shortOrderIds[2] = 0;
        vm.expectRevert(stdError.arithmeticError);
        vm.prank(sender);
        diamond.combineShorts(asset, shortRecords, shortOrderIds);
    }

    function test_CannotExitWithInvalidIdLow() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        // @dev have to set here like this because the revert will incorrectly catch the getLastShortId()
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.exitShort(asset, 99, DEFAULT_AMOUNT, DEFAULT_PRICE, shortHintArrayStorage, 0);
    }

    function test_ExitShortFirstElement() public {
        makeShorts();
        //create ask to allow exit short
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID);
        assertGt(shortRecord.collateral, 0);
        assertEq(getShortRecordCount(sender), 3);
        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
        assertEq(getShortRecordCount(sender), 2);
        // @dev have to set here like this because the revert will incorrectly catch the getLastShortId()
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, shortHintArrayStorage, 0);
    }

    function test_ExitShortLastElement() public {
        makeShorts();
        //create ask to allow exit short
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID + 2);
        assertGt(shortRecord.collateral, 0);
        assertEq(getShortRecordCount(sender), 3);
        exitShort(C.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
        assertEq(getShortRecordCount(sender), 2);
        // @dev have to set here like this because the revert will incorrectly catch the getLastShortId()
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT, DEFAULT_PRICE, shortHintArrayStorage, 0);
    }

    function test_ExitShortMiddleElement() public {
        makeShorts();
        //create ask to allow exit short
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID + 1);
        assertGt(shortRecord.collateral, 0);
        assertEq(getShortRecordCount(sender), 3);
        exitShort(C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
        assertEq(getShortRecordCount(sender), 2);
        // @dev have to set here like this because the revert will incorrectly catch the getLastShortId()
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, DEFAULT_PRICE, shortHintArrayStorage, 0);
    }

    function test_CantExitShortTwice() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender);

        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender);

        assertEq(getShortRecordCount(sender), 2);

        fundLimitAskOpt(1 ether, DEFAULT_AMOUNT, receiver);

        // First Exit
        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, 1 ether, sender);
        assertEq(getShortRecordCount(sender), 1);
        // Second Exits
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, shortHintArrayStorage, 0);
        vm.expectRevert(Errors.InvalidShortId.selector);
        vm.prank(extra);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
        // Second Exits Wallet
        vm.prank(_diamond);
        token.mint(sender, 1 ether);
        vm.prank(sender);
        token.increaseAllowance(_diamond, 1 ether);
        vm.expectRevert(Errors.InvalidShortId.selector);
        exitShortWallet(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);
        vm.expectRevert(Errors.SecondaryLiquidationNoValidShorts.selector);
        liquidateWallet(sender, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, receiver);
        // Second Exits Escrowed
        depositUsd(sender, 1 ether);
        vm.expectRevert(Errors.InvalidShortId.selector);
        exitShortErcEscrowed(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);
        vm.expectRevert(Errors.SecondaryLiquidationNoValidShorts.selector);
        liquidateErcEscrowed(sender, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, receiver);
        // Combine Short
        vm.expectRevert(Errors.InvalidShortId.selector);
        combineShorts({id1: C.SHORT_STARTING_ID, id2: C.SHORT_STARTING_ID + 1});
    }

    function test_ExitBuyBackTooHigh() public {
        makeShorts();
        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID + 1);
        //create ask to allow exit short
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        assertGt(shortRecord.collateral, 0);
        // @dev have to set here like this because the revert will incorrectly catch the getLastShortId()
        depositEthAndPrank(sender, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 2);
        vm.expectRevert(Errors.InvalidBuyback.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(2 ether), DEFAULT_PRICE, shortHintArrayStorage, 0);
    }

    function test_ExitBidEthTooHigh() public {
        makeShorts();
        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID + 1);
        //create ask to allow exit short
        fundLimitAskOpt(11 ether, DEFAULT_AMOUNT, receiver);
        assertGt(shortRecord.collateral, 0);
        // @dev have to set here like this because the revert will incorrectly catch the getLastShortId()

        depositEthAndPrank(sender, 13 ether);
        vm.expectRevert(Errors.InsufficientCollateral.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, 13 ether, shortHintArrayStorage, 0);
    }

    // @dev lowestAskKey == C.TAIL && startingShortId == C.HEAD
    function test_ExitShortPriceTooLowScenario1() public {
        makeShorts();
        depositEthAndPrank(sender, C.MIN_DEPOSIT);
        vm.expectRevert(Errors.ExitShortPriceTooLow.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE - 1, shortHintArrayStorage, 0);
    }

    // @dev lowestAskKey == C.TAIL && s.shorts[e.asset][startingShortId].price > price
    function test_ExitShortPriceTooLowScenario2() public {
        makeShorts();
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        depositEthAndPrank(sender, C.MIN_DEPOSIT);
        vm.expectRevert(Errors.ExitShortPriceTooLow.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE - 1, shortHintArrayStorage, 0);
    }

    // @dev s.asks[e.asset][lowestAskKey].price > price && startingShortId == C.HEAD);
    function test_ExitShortPriceTooLowScenario3() public {
        makeShorts();
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        depositEthAndPrank(sender, C.MIN_DEPOSIT);
        vm.expectRevert(Errors.ExitShortPriceTooLow.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE - 1, shortHintArrayStorage, 0);
    }

    //dev s.asks[e.asset][lowestAskKey].price > price && s.shorts[e.asset][startingShortId].price > price);
    function test_ExitShortPriceTooLowScenario4() public {
        makeShorts();
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        depositEthAndPrank(sender, C.MIN_DEPOSIT);
        vm.expectRevert(Errors.ExitShortPriceTooLow.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE - 1, shortHintArrayStorage, 0);
    }

    // @dev Only allow partial exit if the CR is same or better than before.
    // @dev Even undercollateralized (< minCR) can be partially exitted if this condition is met

    function test_Revert_PostExitCRLtPreExitCR() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        //set price to black swan levels
        setETH(400 ether);
        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID);
        uint256 beforeExitCR = diamond.getCollateralRatio(asset, shortRecord);
        assertGt(diamond.getAssetNormalizedStruct(asset).penaltyCR, beforeExitCR);

        uint80 price = DEFAULT_PRICE * 10;
        //buyback at a higher lowest Ask price
        fundLimitAskOpt(price, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);

        //try reverting
        vm.prank(sender);
        vm.expectRevert(Errors.PostExitCRLtPreExitCR.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(0.5 ether), price, shortHintArrayStorage, 0);

        // try passing
        depositEthAndPrank(sender, DEFAULT_AMOUNT.mulU88(5 ether));
        increaseCollateral(C.SHORT_STARTING_ID, uint80(DEFAULT_AMOUNT.mulU88(0.001 ether)));
        vm.prank(sender);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(0.5 ether), price, shortHintArrayStorage, 0);

        shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID);
        uint256 afterExitCR = diamond.getCollateralRatio(asset, shortRecord);
        assertGe(afterExitCR, beforeExitCR);
    }

    //wallet tests
    function test_ExitWalletBuyBackTooHigh() public {
        makeShorts();
        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID + 1);
        assertGt(shortRecord.collateral, 0);

        vm.expectRevert(Errors.InvalidBuyback.selector);
        exitShortWallet(C.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(2 ether), sender);
    }

    function test_ExitWalletNotEnoughInWallet() public {
        makeShorts();
        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID + 1);
        assertGt(shortRecord.collateral, 0);

        vm.expectRevert(Errors.InsufficientWalletBalance.selector);
        exitShortWallet(C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, sender);
    }

    function test_NotEnoughEthToIncreaseCollateral() public {
        makeShorts();
        vm.prank(sender);
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        increaseCollateral(C.SHORT_STARTING_ID, 1 wei);
    }

    function test_IncreaseCollateralTooMuch() public {
        makeShorts();

        depositEthAndPrank(sender, 1 ether);
        vm.expectRevert(Errors.CollateralHigherThanMax.selector);
        increaseCollateral(C.SHORT_STARTING_ID, 1 ether);
    }

    function test_CantDecreaseCollateralBeyondZero() public {
        makeShorts();

        vm.prank(sender);
        vm.expectRevert(Errors.InsufficientCollateral.selector);
        decreaseCollateral(C.SHORT_STARTING_ID, 30001 ether);
    }

    function test_Revert_CannotDecreaseCollateralBelowCR() public {
        makeShorts();

        vm.prank(sender);
        vm.expectRevert(Errors.CRLowerThanMin.selector);
        decreaseCollateral(C.SHORT_STARTING_ID, 30000 ether);
    }

    function test_Revert_CannotDecreaseCollateralBelowCR2() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        setETH(2666 ether);

        vm.prank(sender);
        vm.expectRevert(Errors.CRLowerThanMin.selector);
        decreaseCollateral(C.SHORT_STARTING_ID, 1 wei);
    }

    function test_ExitShortWithZero() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender);
        // @dev have to set here like this because the revert will incorrectly catch the getLastShortId()
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidBuyback.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, 0, DEFAULT_PRICE, shortHintArrayStorage, 0);

        vm.expectRevert(Errors.InvalidBuyback.selector);
        exitShortWallet(C.SHORT_STARTING_ID, 0, sender);

        vm.expectRevert(Errors.InvalidBuyback.selector);
        exitShortErcEscrowed(C.SHORT_STARTING_ID, 0, sender);
    }

    function test_CantexitShortErcEscrowedWhenErcIsTooLow() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender);
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        exitShortErcEscrowed(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);
    }

    function test_CombineShortsOnlyOne() public {
        makeShorts();

        uint8[] memory shortIds = new uint8[](1);
        shortIds[0] = C.SHORT_STARTING_ID;
        uint16[] memory shortOrderIds = new uint16[](1);
        shortOrderIds[0] = 0;
        vm.prank(sender);
        vm.expectRevert(Errors.InsufficientNumberOfShorts.selector);
        diamond.combineShorts(asset, shortIds, shortOrderIds);
    }

    function test_CombineShortsInvalidId() public {
        makeShorts();

        // if non-first element is invalid
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        combineShorts(100, 0);

        // if first element is invalid
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        combineShorts(0, 100);

        // if both are invalid
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector);
        combineShorts(0, 1);
    }

    function test_CombineShortsSameIdx3() public {
        makeShorts();

        uint8[] memory shortIds = new uint8[](3);
        shortIds[0] = C.SHORT_STARTING_ID;
        shortIds[1] = C.SHORT_STARTING_ID + 1;
        shortIds[2] = C.SHORT_STARTING_ID + 1;

        uint16[] memory shortOrderIds = new uint16[](3);
        shortOrderIds[0] = 0;
        shortOrderIds[1] = 0;
        shortOrderIds[2] = 0;

        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector); // same id
        diamond.combineShorts(asset, shortIds, shortOrderIds);

        shortIds[0] = C.SHORT_STARTING_ID;
        shortIds[1] = C.SHORT_STARTING_ID;
        shortIds[2] = C.SHORT_STARTING_ID;
        //aasd
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector); // same id
        diamond.combineShorts(asset, shortIds, shortOrderIds);

        shortIds[0] = C.SHORT_STARTING_ID + 1;
        shortIds[1] = C.SHORT_STARTING_ID + 1;
        shortIds[2] = C.SHORT_STARTING_ID + 1;

        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortId.selector); // same id
        diamond.combineShorts(asset, shortIds, shortOrderIds);
    }

    function test_CombineShortsSameIdx2() public {
        makeShorts();

        uint8[] memory shortIds = new uint8[](2);
        shortIds[0] = C.SHORT_STARTING_ID;
        shortIds[1] = C.SHORT_STARTING_ID;

        uint16[] memory shortOrderIds = new uint16[](2);
        shortOrderIds[0] = 0;
        shortOrderIds[1] = 0;

        vm.prank(sender);
        vm.expectRevert(Errors.FirstShortDeleted.selector); // same id
        diamond.combineShorts(asset, shortIds, shortOrderIds);

        shortIds[0] = C.SHORT_STARTING_ID + 1;
        shortIds[1] = C.SHORT_STARTING_ID + 1;

        vm.prank(sender);
        vm.expectRevert(Errors.FirstShortDeleted.selector); // same id
        diamond.combineShorts(asset, shortIds, shortOrderIds);
    }

    function test_CannotShortUnderMinimumSize() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        depositEthAndPrank(receiver, DEFAULT_AMOUNT); // more than necessary
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, 0.3999 ether, badOrderHintArray, shortHintArrayStorage, initialCR);

        vm.prank(receiver);
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createLimitShort(asset, 0.0000001 ether, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    //test can't leave behind MIN ETH
    function test_CannotExitPrimaryAndLeaveBehindDust() public {
        makeShorts();
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        depositEthAndPrank(sender, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT) * 2);
        vm.expectRevert(Errors.CannotLeaveDustAmount.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT - 1 wei, DEFAULT_PRICE, shortHintArrayStorage, 0);
    }

    function test_CannotExitPrimaryAndLeaveBehindDust_NotEnoughBidErcAmount() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT - 1 wei, receiver);
        vm.prank(sender);
        vm.expectRevert(Errors.CannotLeaveDustAmount.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, shortHintArrayStorage, 0);
    }

    function test_CannotExitSecondaryAndLeaveBehindDust() public {
        makeShorts();
        vm.prank(_diamond);
        token.mint(sender, DEFAULT_AMOUNT);
        vm.prank(sender);
        vm.expectRevert(Errors.CannotLeaveDustAmount.selector);
        diamond.exitShortWallet(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT - 1 wei, 0);
        depositUsdAndPrank(sender, DEFAULT_AMOUNT * 3);
        vm.expectRevert(Errors.CannotLeaveDustAmount.selector);
        diamond.exitShortErcEscrowed(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT - 1 wei, 0);
    }

    function test_Revert_AlreadyMinted_PartialFill() public {
        assertEq(diamond.getTokenId(), 1);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(diamond.getTokenId(), 1);
        vm.startPrank(sender);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, C.STARTING_ID + 1);
        assertEq(diamond.getTokenId(), 2);
        vm.expectRevert(Errors.AlreadyMinted.selector);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, C.STARTING_ID + 1);
    }

    function test_Revert_AlreadyMinted_FullyFilled() public {
        assertEq(diamond.getTokenId(), 1);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(diamond.getTokenId(), 1);
        vm.startPrank(sender);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, 0);
        assertEq(diamond.getTokenId(), 2);
        vm.expectRevert(Errors.AlreadyMinted.selector);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, 0);
    }

    function test_Revert_InvalidInitialCR_InitialCRLtInitialCR() public {
        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, DEFAULT_AMOUNT, O.LimitShort, 1);

        uint16 initialCR = diamond.getAssetStruct(asset).initialCR - C.BID_CR - 1 wei;
        vm.expectRevert(Errors.InvalidCR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_Revert_InvalidInitialCR_InitialCRGteCRATIO_MAX_INITIAL() public {
        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, DEFAULT_AMOUNT, O.LimitShort, 1);

        uint16 shortOrderCROverMax = uint16((C.CRATIO_MAX_INITIAL * C.TWO_DECIMAL_PLACES) / 1 ether);
        vm.expectRevert(Errors.InvalidCR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArrayStorage, shortOrderCROverMax);
    }
}
