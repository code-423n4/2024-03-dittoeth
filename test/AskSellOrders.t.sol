// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {C} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract SellOrdersTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }

    //HELPERS
    function createBidsAtDefaultPrice() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function createBidsForPartialAsk() public {
        createBidsAtDefaultPrice();
        fundLimitBidOpt(DEFAULT_PRICE - 1, DEFAULT_AMOUNT, receiver); //shouldn't match
    }

    function checkEscrowedAndOrders(
        uint256 receiverErcEscrowed,
        uint256 senderErcEscrowed,
        uint256 senderEthEscrowed,
        uint256 bidLength,
        uint256 askLength
    ) public {
        r.ercEscrowed = receiverErcEscrowed;
        assertStruct(receiver, r);
        s.ercEscrowed = senderErcEscrowed;
        s.ethEscrowed = senderEthEscrowed;
        assertStruct(sender, s);
        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, bidLength);
        STypes.Order[] memory asks = getAsks();
        assertEq(asks.length, askLength);
        // Asset level ercDebt
        assertEq(diamond.getAssetStruct(asset).ercDebt, 0);
    }

    //Matching Orders
    function test_AddingSellWithNoBids() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        STypes.Order[] memory asks = getAsks();
        assertEq(asks[0].price, DEFAULT_PRICE);
    }

    function test_AddingLimitSellAskUsdGreaterThanBidUsd() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 1
        });
        assertEq(getAsks()[0].price, DEFAULT_PRICE);
    }

    function test_AddingLimitSellAskWithMultipleBids() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 1,
            askLength: 0
        });

        assertEq(getBids()[0].price, DEFAULT_PRICE);
    }

    //partial fills from ask
    function test_AddingSellUsdLessThanBidUsd() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 1,
            askLength: 0
        });

        assertEq(getBids()[0].price, DEFAULT_PRICE);
        assertEq(getBids()[0].ercAmount, DEFAULT_AMOUNT);
    }

    function test_AddingSellUsdLessThanBidUsd2() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 5, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(1.5 ether), sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT.mulU88(1.5 ether),
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(1.5 ether),
            bidLength: 1,
            askLength: 0
        });

        assertEq(getBids()[0].price, DEFAULT_PRICE);
        assertEq(getBids()[0].ercAmount, (DEFAULT_AMOUNT).mul(3.5 ether));
    }

    function test_AddingSellUsdLessThanBidUsdUntilBidIsFullyFilled() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 5, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(1.5 ether), sender);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(3.5 ether), sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 5,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mul(5 ether),
            bidLength: 0,
            askLength: 0
        });
    }

    function test_PartialMarketSellDueToInsufficientBidsOnOB() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundMarketAsk(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: DEFAULT_AMOUNT,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 0
        });
    }

    function test_PartialLimitAsk() public {
        createBidsForPartialAsk();
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(3.5 ether), sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 3,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mul(DEFAULT_AMOUNT * 3),
            bidLength: 1,
            askLength: 1
        });
    }

    //Testing empty OB scenarios
    function test_PartialMarketAskOBSuddenlyEmpty() public {
        createBidsAtDefaultPrice();
        fundMarketAsk(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 3,
            senderErcEscrowed: DEFAULT_AMOUNT,
            senderEthEscrowed: DEFAULT_PRICE.mul(DEFAULT_AMOUNT * 3),
            bidLength: 0,
            askLength: 0
        });
    }

    function test_PartialLimitAskOBSuddenlyEmpty() public {
        createBidsAtDefaultPrice();
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT * 4, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT * 3,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mul(DEFAULT_AMOUNT * 3),
            bidLength: 0,
            askLength: 1
        });
    }

    //test matching based on price differences
    function test_AddingLimitSellAskPriceEqualBidPrice() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 0
        });
    }

    //@dev no match because price out of range
    function test_AddingLimitSellAskPriceGreaterBidPrice() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({receiverErcEscrowed: 0, senderErcEscrowed: 0, senderEthEscrowed: 0, bidLength: 1, askLength: 1});
    }

    function test_AddingLimitSellAskPriceLessBidPrice() public {
        fundLimitBidOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        checkEscrowedAndOrders({
            receiverErcEscrowed: DEFAULT_AMOUNT,
            senderErcEscrowed: 0,
            senderEthEscrowed: (DEFAULT_PRICE + 1 wei).mulU88(DEFAULT_AMOUNT),
            bidLength: 0,
            askLength: 0
        });
    }

    function test_MarketSellNoBids() public {
        assertEq(getAsks().length, 0);
        fundMarketAsk(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(getAsks().length, 0);
    }

    //OrderType and prevOrderType
    function test_PrevOrderTypeCancelledAsk() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getAsks()[0].orderType == O.LimitAsk);
        assertTrue(getAsks()[0].prevOrderType == O.Uninitialized);

        vm.prank(sender);
        cancelAsk(100);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getAsks()[0].orderType == O.LimitAsk);
        assertTrue(getAsks()[0].prevOrderType == O.Cancelled);
    }

    function test_PrevOrderTypeMatchedAsk() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getAsks()[0].orderType == O.LimitAsk);
        assertTrue(getAsks()[0].prevOrderType == O.Uninitialized);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getAsks()[0].orderType == O.LimitAsk);
        assertTrue(getAsks()[0].prevOrderType == O.Matched);
    }

    function test_PrevOrderTypeCancelledShort() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getShorts()[0].orderType == O.LimitShort);
        assertTrue(getShorts()[0].prevOrderType == O.Uninitialized);

        vm.prank(sender);
        cancelShort(100);

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getShorts()[0].orderType == O.LimitShort);
        assertTrue(getShorts()[0].prevOrderType == O.Cancelled);
    }

    function test_PrevOrderTypeMatchedShort() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getShorts()[0].orderType == O.LimitShort);
        assertTrue(getShorts()[0].prevOrderType == O.Uninitialized);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertTrue(getShorts()[0].orderType == O.LimitShort);
        assertTrue(getShorts()[0].prevOrderType == O.Matched);
    }

    //Testing max orderId
    function test_CanStillMatchOrderWhenAskOrderIdIsMaxed() public {
        vm.prank(owner);
        //@dev 65535 is max value
        testFacet.setOrderIdT(asset, 65534);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65535);
        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, HIGHER_PRICE, O.LimitAsk, 1);

        //trigger overflow when incoming ask can't be matched
        depositUsdAndPrank(receiver, DEFAULT_AMOUNT);
        vm.expectRevert(stdError.arithmeticError);
        diamond.createAsk(
            asset,
            DEFAULT_PRICE * 10, // not matched
            DEFAULT_AMOUNT,
            C.LIMIT_ORDER,
            orderHintArray
        );

        //@dev Can still match since orderId isn't used invoked until it needs to be added on ob
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65535);
    }

    function test_AskDustAmountCancelled() public {
        // Before
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, 0);
        // Match
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // Should be filled
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // Should not be filled
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1, sender);
        // After
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT));
        // Ask is not on the orderbook
        assertEq(diamond.getAskOrder(asset, C.HEAD).prevId, C.HEAD);
        assertEq(diamond.getAskOrder(asset, C.HEAD).nextId, C.HEAD);
        assertEq(diamond.getBidOrder(asset, C.STARTING_ID).ercAmount, DEFAULT_AMOUNT);
    }

    function test_AskDustAmountFromBidCancelled() public {
        uint256 amount =
            DEFAULT_AMOUNT + uint256(diamond.getAssetNormalizedStruct(asset).minBidEth).mul(C.DUST_FACTOR).div(DEFAULT_PRICE);
        // Before
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, 0);
        // Match
        fundLimitBidOpt(DEFAULT_PRICE, uint88(amount) - 1, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        // After
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT));
        // Bid is considered fully filled and reuseable
        assertEq(diamond.getBidOrder(asset, C.HEAD).prevId, 100);
        assertEq(diamond.getBidOrder(asset, C.HEAD).nextId, C.HEAD);
    }
}
