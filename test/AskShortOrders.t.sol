// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {STypes, MTypes, O, SR} from "contracts/libraries/DataTypes.sol";
import {Events} from "contracts/libraries/Events.sol";
import {C} from "contracts/libraries/Constants.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";

import {OBFixture} from "test/utils/OBFixture.sol";

import {console} from "contracts/libraries/console.sol";

contract ShortOrdersTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }

    //HELPERS
    function checkEscrowedAndOrders(
        uint256 receiverErcEscrowed,
        uint256 senderErcEscrowed,
        uint256 senderEthEscrowed,
        uint256 bidLength,
        uint256 shortLength
    ) public {
        r.ercEscrowed = receiverErcEscrowed;
        assertStruct(receiver, r);
        s.ercEscrowed = senderErcEscrowed;
        s.ethEscrowed = senderEthEscrowed;
        assertStruct(sender, s);
        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, bidLength);
        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts.length, shortLength);
        // Asset level ercDebt
        assertEq(diamond.getAssetStruct(asset).ercDebt, receiverErcEscrowed);
    }
    //Matching Orders

    function test_AddingShortWithNoBids() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertStruct(sender, s);

        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts[0].price, DEFAULT_PRICE);
    }

    function test_AddingLimitShortPriceEqualBidPrice() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            shortLength: 1
        });
    }

    function test_AddingLimitShortPriceLessThanBidPrice() public {
        fundLimitBidOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            shortLength: 0
        });
    }

    // @dev no matching because price is out of range
    function test_ShortPriceGreaterThanBidPrice() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT * 2, sender);

        checkEscrowedAndOrders({receiverErcEscrowed: 0, senderErcEscrowed: 0, senderEthEscrowed: 0, bidLength: 1, shortLength: 1});

        assertEq(getBids()[0].price, DEFAULT_PRICE);
        assertEq(getBids()[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(getBids()[0].id, 100);
        assertEq(getBids().length, 1);

        assertEq(getShorts()[0].price, DEFAULT_PRICE + 1 wei);
        assertEq(getShorts()[0].ercAmount, DEFAULT_AMOUNT * 2);
        assertEq(getShorts()[0].id, 101);
        assertEq(getShorts().length, 1);
    }

    function test_AddingLimitShortUsdGreaterThanBidUsd() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            shortLength: 1
        });
        assertEq(getShorts()[0].price, DEFAULT_PRICE);
    }

    function test_AddingLimitShortUsdGreaterThanBidUsd2() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(1.5 ether), receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 5, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT.mulU88(1.5 ether),
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            shortLength: 1
        });
        assertEq(getShorts()[0].price, DEFAULT_PRICE);
    }

    function test_AddingLimitShortWithMultipleBids() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 1,
            shortLength: 0
        });
    }

    //partial fill
    function test_AddingShortUsdLessThanBidUsd() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 1,
            shortLength: 0
        });
        assertEq(getBids()[0].price, DEFAULT_PRICE);
        assertEq(getBids()[0].ercAmount, DEFAULT_AMOUNT);
    }

    function test_AddingShortUsdLessThanBidUsd2() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 5, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(1.5 ether), sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT.mulU88(1.5 ether),
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 1,
            shortLength: 0
        });

        assertEq(getBids()[0].price, DEFAULT_PRICE);
        assertEq(getBids()[0].ercAmount, DEFAULT_AMOUNT.mulU88(3.5 ether));
    }

    function test_AddingShortUsdLessThanBidUsdUntilBidIsFullyFilled() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 5, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(1.5 ether), sender);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(3.5 ether), sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 5,
            senderErcEscrowed: 0,
            senderEthEscrowed: 0,
            bidLength: 0,
            shortLength: 0
        });
    }

    // Test skipping shorts under oracle price
    function test_SkipShortsAllShortsUnderOracle() public {
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT, sender); //100
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT * 2, sender); //101
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT * 3, sender); //102
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT * 4, sender); //103

        //check asks
        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(shorts[1].ercAmount, DEFAULT_AMOUNT * 2);
        assertEq(shorts[2].ercAmount, DEFAULT_AMOUNT * 3);
        assertEq(shorts[3].ercAmount, DEFAULT_AMOUNT * 4);

        //create Bid...that shouldn't be matched!
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        shorts = getShorts();
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(shorts[1].ercAmount, DEFAULT_AMOUNT * 2);
        assertEq(shorts[2].ercAmount, DEFAULT_AMOUNT * 3);
        assertEq(shorts[3].ercAmount, DEFAULT_AMOUNT * 4);

        STypes.Order[] memory bids = getBids();
        assertEq(bids[0].ercAmount, DEFAULT_AMOUNT);
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    // skip most shorts, match on 1
    function test_SkipShortsSomeShortsUnderOracle() public {
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT, sender); //not matched
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT * 2, sender); //not matched
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT * 3, sender); //not matched
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, sender); //partially matched

        //check asks
        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(shorts[1].ercAmount, DEFAULT_AMOUNT * 2);
        assertEq(shorts[2].ercAmount, DEFAULT_AMOUNT * 3);
        assertEq(shorts[3].ercAmount, DEFAULT_AMOUNT * 4);

        //create Bid...should match the 4th short!
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        shorts = getShorts();
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(shorts[1].ercAmount, DEFAULT_AMOUNT * 2);
        assertEq(shorts[2].ercAmount, DEFAULT_AMOUNT * 3);
        assertEq(shorts[3].ercAmount, DEFAULT_AMOUNT * 3); //1 less!

        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 0);

        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    // match ask, skip short, match 1
    function test_SkipShortsSomeShortsUnderOracleWithAsks() public {
        fundLimitAskOpt(LOWER_PRICE, DEFAULT_AMOUNT, sender); //matched bc ask
        fundLimitAskOpt(LOWER_PRICE, DEFAULT_AMOUNT * 2, sender); //matched bc ask
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT * 3, sender); //not matched/skipped
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, sender); //matched

        //check asks
        STypes.Order[] memory asks = getAsks();
        assertEq(asks[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(asks[1].ercAmount, DEFAULT_AMOUNT * 2);
        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT * 3);
        assertEq(shorts[1].ercAmount, DEFAULT_AMOUNT * 4);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, receiver);

        asks = getAsks();
        assertEq(asks.length, 0);
        shorts = getShorts();
        assertEq(shorts.length, 2);
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT * 3);
        assertEq(shorts[1].ercAmount, DEFAULT_AMOUNT * 3);

        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 0);

        r.ethEscrowed = (DEFAULT_PRICE.mul(DEFAULT_AMOUNT) * 4)
            - (LOWER_PRICE.mul(DEFAULT_AMOUNT) + (LOWER_PRICE.mul(DEFAULT_AMOUNT * 2)) + (DEFAULT_PRICE.mul(DEFAULT_AMOUNT)));

        r.ercEscrowed = DEFAULT_AMOUNT * 4;
        assertStruct(receiver, r);
        s.ethEscrowed = LOWER_PRICE.mul(DEFAULT_AMOUNT) + (LOWER_PRICE.mul(DEFAULT_AMOUNT * 2));
        assertStruct(sender, s);
    }

    // partial match
    function test_SkipShortsSomeShortsUnderOracleWithAsks2() public {
        fundLimitAskOpt(LOWER_PRICE, DEFAULT_AMOUNT, sender); //matched bc ask
        fundLimitAskOpt(LOWER_PRICE, DEFAULT_AMOUNT * 2, sender); //matched bc ask
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT * 3, sender); //not matched/skipped
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, sender); //matched

        //check asks
        STypes.Order[] memory asks = getAsks();
        assertEq(asks[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(asks[1].ercAmount, DEFAULT_AMOUNT * 2);
        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT * 3);
        assertEq(shorts[1].ercAmount, DEFAULT_AMOUNT * 4);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 8, receiver);
        asks = getAsks();
        assertEq(asks.length, 0);
        shorts = getShorts();
        assertEq(shorts.length, 1);
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT * 3);

        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 1);
        assertEq(bids[0].ercAmount, DEFAULT_AMOUNT);

        r.ethEscrowed = (DEFAULT_PRICE.mul(DEFAULT_AMOUNT * 8))
            - (
                LOWER_PRICE.mul(DEFAULT_AMOUNT) + (LOWER_PRICE.mul(DEFAULT_AMOUNT) * 2)
                    + (DEFAULT_PRICE.mul(DEFAULT_AMOUNT).mul(4 ether)) + DEFAULT_PRICE.mul(DEFAULT_AMOUNT)
            );

        r.ercEscrowed = DEFAULT_AMOUNT * 7;
        assertStruct(receiver, r);
        s.ethEscrowed = LOWER_PRICE.mul(DEFAULT_AMOUNT) + (LOWER_PRICE.mul(DEFAULT_AMOUNT * 2));
        assertStruct(sender, s);
    }

    function test_SkipShortsSomeShortsUnderOracleWithAsks3() public {
        fundLimitAskOpt(LOWER_PRICE, DEFAULT_AMOUNT, sender); //matched bc ask
        fundLimitAskOpt(LOWER_PRICE, DEFAULT_AMOUNT * 2, sender); //matched bc ask
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT * 3, sender); //not matched/skipped
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, sender); //matched

        //check asks
        STypes.Order[] memory asks = getAsks();
        assertEq(asks[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(asks[1].ercAmount, DEFAULT_AMOUNT * 2);
        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT * 3);
        assertEq(shorts[1].ercAmount, DEFAULT_AMOUNT * 4);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 7, receiver);

        asks = getAsks();
        assertEq(asks.length, 0);
        shorts = getShorts();
        assertEq(shorts.length, 1);
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT * 3);

        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 0);

        r.ethEscrowed = (DEFAULT_PRICE.mul(DEFAULT_AMOUNT * 7))
            - (
                LOWER_PRICE.mul(DEFAULT_AMOUNT) + (LOWER_PRICE.mul(DEFAULT_AMOUNT) * 2)
                    + (DEFAULT_PRICE.mul(DEFAULT_AMOUNT).mul(4 ether))
            );

        r.ercEscrowed = DEFAULT_AMOUNT * 7;
        assertStruct(receiver, r);
        s.ethEscrowed = LOWER_PRICE.mul(DEFAULT_AMOUNT) + (LOWER_PRICE.mul(DEFAULT_AMOUNT * 2));
        assertStruct(sender, s);
    }

    function test_SkipShortsSomeShortsUnderOracleWithManyAsks() public {
        for (uint256 i = 0; i < 7; i++) {
            fundLimitAskOpt(LOWER_PRICE, DEFAULT_AMOUNT, sender); //matched bc ask
        }
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT, sender); //not matched/skipped
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT, sender); //not matched/skipped
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT, sender); //not matched/skipped
        fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT, sender); //not matched/skipped
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, sender); //matched

        //check asks
        STypes.Order[] memory asks = getAsks();
        assertEq(asks.length, 7);
        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts.length, 5);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 13, receiver);

        asks = getAsks();
        assertEq(asks.length, 0);
        shorts = getShorts();
        assertEq(shorts.length, 4);
        assertEq(shorts[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(shorts[1].ercAmount, DEFAULT_AMOUNT);
        assertEq(shorts[2].ercAmount, DEFAULT_AMOUNT);
        assertEq(shorts[3].ercAmount, DEFAULT_AMOUNT);

        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 1);

        r.ethEscrowed = DEFAULT_AMOUNT.mulU88(7); //leftover change
        r.ercEscrowed = DEFAULT_AMOUNT * 9;
        assertStruct(receiver, r);
        s.ethEscrowed = LOWER_PRICE.mul(DEFAULT_AMOUNT * 7);
        assertStruct(sender, s);
    }

    function test_SkipShortsManyShortsUnderOracleWithAsks() public {
        fundLimitAskOpt(LOWER_PRICE, DEFAULT_AMOUNT, sender); //matched bc ask
        fundLimitAskOpt(LOWER_PRICE, DEFAULT_AMOUNT, sender); //matched bc ask

        //make more than 10 shorts that can't be matched
        for (uint256 i = 0; i < 30; i++) {
            fundLimitShortOpt(LOWER_PRICE, DEFAULT_AMOUNT, sender); //not matched/skipped
        }

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); //matched
        //need to skip to trigger BadShortHint Error
        skip(1 hours);

        //check asks
        STypes.Order[] memory asks = getAsks();
        assertEq(asks.length, 2);
        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts.length, 31);

        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitBid, 1);
        depositEthAndPrank(receiver, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT * 7));
        ethAggregator.setRoundData(
            92233720368547778907 wei,
            3900 ether / C.BASE_ORACLE_DECIMALS,
            block.timestamp,
            block.timestamp,
            92233720368547778907 wei
        );
        vm.expectRevert(Errors.BadShortHint.selector);
        diamond.createBid(asset, DEFAULT_PRICE, DEFAULT_AMOUNT * 3, C.LIMIT_ORDER, orderHintArray, shortHintArrayStorage);
        ethAggregator.setRoundData(
            92233720368547778907 wei,
            4000 ether / C.BASE_ORACLE_DECIMALS,
            block.timestamp,
            block.timestamp,
            92233720368547778907 wei
        );

        shortHintArrayStorage[1] = 132;
        vm.prank(receiver);
        diamond.createBid(asset, DEFAULT_PRICE, DEFAULT_AMOUNT * 3, C.LIMIT_ORDER, orderHintArray, shortHintArrayStorage);

        asks = getAsks();
        assertEq(asks.length, 0);
        shorts = getShorts();
        assertEq(shorts.length, 30);

        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 0);
    }

    function test_SkipAllShortsMatchAsk() public {
        fundLimitShortOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, sender); //100
        fundLimitShortOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, sender); //101
        fundLimitShortOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, sender); //102
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); //103

        vm.prank(sender);
        cancelShort(100);

        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts.length, 2);
        STypes.Order[] memory asks = getAsks();
        assertEq(asks.length, 1);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 5, receiver);

        shorts = getShorts();
        assertEq(shorts.length, 2);

        asks = getAsks();
        assertEq(asks.length, 0);

        assertEq(getBids().length, 1);
        assertEq(getBids()[0].ercAmount, DEFAULT_AMOUNT * 4);
    }

    function test_SkipAllShortsMatchAsk2() public {
        for (uint256 i = 0; i < 50; i++) {
            fundLimitShortOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, sender); //100
        }
        fundLimitAskOpt(DEFAULT_PRICE * 5, DEFAULT_AMOUNT, sender); //151

        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts.length, 50);
        STypes.Order[] memory asks = getAsks();
        assertEq(asks.length, 1);
        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 0);
        shortHintArrayStorage = setShortHintArray();
        fundLimitBidOpt(DEFAULT_PRICE * 5, DEFAULT_AMOUNT * 5, receiver);

        shorts = getShorts();
        assertEq(shorts.length, 50);
        asks = getAsks();
        assertEq(asks.length, 0);
        bids = getBids();
        assertEq(bids.length, 1);
        assertEq(bids[0].ercAmount, DEFAULT_AMOUNT * 4);
    }

    function test_ShortDeletedEvent() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        vm.expectEmit(_diamond);
        emit Events.DeleteShortRecord(asset, sender, C.SHORT_STARTING_ID);
        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
    }

    function test_ShortRecordEventScenario() public {
        // Create SR to combine into later
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        depositEth(sender, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT * 2).mulU88(LibOrders.convertCR(initialCR)));
        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitShort, 1);

        vm.expectEmit(_diamond);
        emit Events.CreateShortRecord(asset, sender, C.SHORT_STARTING_ID + 1);
        vm.prank(sender);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT * 2, orderHintArray, shortHintArrayStorage, initialCR);

        STypes.ShortRecord memory short = getShortRecord(sender, C.SHORT_STARTING_ID + 1);
        assertTrue(short.status == SR.PartialFill);

        //DeleteShortRecord Event isn't sent b/c there's an active short order
        //This should set SR to Cancelled
        uint8[] memory shortRecords = new uint8[](2);
        shortRecords[0] = C.SHORT_STARTING_ID;
        shortRecords[1] = C.SHORT_STARTING_ID + 1;
        uint16[] memory shortOrderIds = new uint16[](2);
        shortOrderIds[0] = 0;
        shortOrderIds[1] = 101;

        // @dev Short Record Delete Event sends because short record exited as well as the attached short order
        vm.expectEmit(_diamond);
        emit Events.DeleteShortRecord(asset, sender, C.SHORT_STARTING_ID + 1);
        vm.prank(sender);
        diamond.combineShorts(asset, shortRecords, shortOrderIds);

        short = getShortRecord(sender, C.SHORT_STARTING_ID + 1);
        assertTrue(short.status == SR.Closed);

        //The Short Record ID is now available for reuse
        // @dev the short was auto cancelled
        short = getShortRecord(sender, C.HEAD);
        assertEq(short.prevId, C.SHORT_STARTING_ID + 1);
        assertEq(short.nextId, C.SHORT_STARTING_ID);
    }

    //Testing max orderId
    function test_CanStillMatchOrderWhenShortOrderIdIsMaxed() public {
        vm.prank(owner);
        // @dev 65535 is max value
        testFacet.setOrderIdT(asset, 65534);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65535);
        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, HIGHER_PRICE, O.LimitShort, 1);

        //trigger overflow when incoming ask can't be matched
        depositEthAndPrank(receiver, 10 ether);
        vm.expectRevert(stdError.arithmeticError);
        diamond.createLimitShort(asset, HIGHER_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArrayStorage, initialCR);

        // @dev Can still match since orderId isn't used invoked until it needs to be added on ob
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65535);
    }

    // @dev Scenario: There are eligible asks to be matched, one eligible short with lowest price, one ineligibleShort
    function test_MatchOnlyEligibleSells() public {
        fundLimitShortOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, sender); //won't be matched
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT, sender);
        assertEq(getShorts().length, 2);
        assertEq(getAsks().length, 2);

        // @dev ignores the short under oracle price
        fundLimitBidOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT * 4, receiver);
        assertEq(getShorts().length, 1);
        assertEq(getAsks().length, 0);
        assertEq(getBids().length, 1);
    }

    function test_ShortDustAmountCancelled() public {
        // Before
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, 0);
        // Match
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // Should be filled
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // Should not be filled
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1, sender);
        // After
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(diamond.getShortRecord(asset, sender, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT);
        assertTrue(diamond.getShortRecord(asset, sender, C.SHORT_STARTING_ID).status == SR.FullyFilled);
        // Short is not on the orderbook
        assertEq(diamond.getShortOrder(asset, C.HEAD).prevId, C.HEAD);
        assertEq(diamond.getShortOrder(asset, C.HEAD).nextId, C.HEAD);
        assertEq(diamond.getBidOrder(asset, C.STARTING_ID).ercAmount, DEFAULT_AMOUNT);
    }

    function test_ShortDustAmountFromBidCancelled() public {
        uint256 amount =
            DEFAULT_AMOUNT + uint256(diamond.getAssetNormalizedStruct(asset).minBidEth).mul(C.DUST_FACTOR).div(DEFAULT_PRICE);
        // Before
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, 0);
        // Match
        fundLimitBidOpt(DEFAULT_PRICE, uint88(amount) - 1, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        // After
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(diamond.getShortRecord(asset, sender, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT);
        assertTrue(diamond.getShortRecord(asset, sender, C.SHORT_STARTING_ID).status == SR.FullyFilled);
        // Bid is considered fully filled and reuseable
        assertEq(diamond.getBidOrder(asset, C.HEAD).prevId, 100);
        assertEq(diamond.getBidOrder(asset, C.HEAD).nextId, C.HEAD);
    }
}
