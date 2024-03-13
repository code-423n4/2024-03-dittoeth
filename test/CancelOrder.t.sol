// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {STypes, MTypes, O, SR} from "contracts/libraries/DataTypes.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract CancelOrderTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;

    uint256 private startGas;
    uint256 private gasUsed;

    function setUp() public override {
        super.setUp();
    }

    function test_CancelBid() public {
        fundLimitBidOpt(4 ether, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(3 ether, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(2 ether, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 4);

        assertEq(bids[0].id, 100);
        assertEq(bids[0].price, 4 ether);
        assertEq(bids[1].id, 101);
        assertEq(bids[1].price, 3 ether);
        assertEq(bids[2].id, 102);
        assertEq(bids[2].price, 2 ether);
        assertEq(bids[3].id, 103);
        assertEq(bids[3].price, 1 ether);

        vm.prank(receiver);
        gasUsed = gasleft();
        cancelBid(101);
        emit log_named_uint("gasUsed", gasUsed - gasleft());

        bids = getBids();
        assertEq(bids.length, 3);
        assertEq(bids[0].id, 100);
        assertEq(bids[1].id, 102);
        assertEq(bids[2].id, 103);
    }

    function test_CancelShort() public {
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(2 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(3 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(4 ether, DEFAULT_AMOUNT, receiver);

        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts.length, 4);
        assertEq(shorts[0].id, 100);
        assertEq(shorts[0].price, 1 ether);
        assertEq(shorts[1].id, 101);
        assertEq(shorts[1].price, 2 ether);
        assertEq(shorts[2].id, 102);
        assertEq(shorts[2].price, 3 ether);
        assertEq(shorts[3].id, 103);
        assertEq(shorts[3].price, 4 ether);

        vm.startPrank(receiver);
        gasUsed = gasleft();
        cancelShort(101);
        emit log_named_uint("gasUsed", gasUsed - gasleft());

        shorts = getShorts();
        assertEq(shorts.length, 3);
        assertEq(shorts[0].id, 100);
        assertEq(shorts[1].id, 102);
        assertEq(shorts[2].id, 103);
    }

    function test_CancelAsk() public {
        fundLimitAskOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(2 ether, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(3 ether, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(4 ether, DEFAULT_AMOUNT, receiver);

        STypes.Order[] memory asks = getAsks();
        assertEq(asks.length, 4);
        assertEq(asks[0].id, 100);
        assertEq(asks[0].price, 1 ether);
        assertEq(asks[1].id, 101);
        assertEq(asks[1].price, 2 ether);
        assertEq(asks[2].id, 102);
        assertEq(asks[2].price, 3 ether);
        assertEq(asks[3].id, 103);
        assertEq(asks[3].price, 4 ether);

        vm.startPrank(receiver);
        gasUsed = gasleft();
        cancelAsk(101);
        emit log_named_uint("gasUsed", gasUsed - gasleft());

        asks = getAsks();
        assertEq(asks.length, 3);
        assertEq(asks[0].id, 100);
        assertEq(asks[1].id, 102);
        assertEq(asks[2].id, 103);
    }

    //cancel orders that have been partially filled
    function test_CancelPartiallyFilledBid() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(1 ether, DEFAULT_AMOUNT.mulU88(0.5 ether), sender);

        STypes.Order[] memory bids = getBids();
        assertEq(bids.length, 1);

        r.ercEscrowed = DEFAULT_AMOUNT.mulU88(0.5 ether);
        assertStruct(receiver, r);
        s.ethEscrowed = DEFAULT_AMOUNT.mulU88(0.5 ether).mul(1 ether);
        assertStruct(sender, s);

        vm.prank(receiver);
        cancelBid(100);
        r.ethEscrowed = DEFAULT_AMOUNT.mulU88(0.5 ether).mul(1 ether);
        assertStruct(receiver, r);
        assertStruct(sender, s);
    }

    function test_CancelPartiallyFilledShort() public {
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);

        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts.length, 1);

        s.ethEscrowed = 0;
        assertStruct(sender, s);
        r.ercEscrowed = DEFAULT_AMOUNT.mulU88(0.5 ether);
        assertStruct(receiver, r);

        assertTrue(getShortRecord(sender, 2).status == SR.PartialFill);
        assertEq(getShortRecord(sender, 2).ercDebt, DEFAULT_AMOUNT.mulU88(0.5 ether));

        vm.prank(sender);
        cancelShort(100);

        s.ethEscrowed = DEFAULT_AMOUNT.mulU88(0.5 ether).mul(1 ether).mul(LibOrders.convertCR(initialCR));
        assertStruct(sender, s);

        assertTrue(getShortRecord(sender, 2).status == SR.FullyFilled);
        assertEq(getShortRecord(sender, 2).ercDebt, DEFAULT_AMOUNT.mulU88(0.5 ether));
    }

    function test_CancelPartiallyFilledAsk() public {
        fundLimitAskOpt(1 ether, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT.mulU88(0.5 ether), receiver);

        STypes.Order[] memory asks = getAsks();
        assertEq(asks.length, 1);

        s.ethEscrowed = DEFAULT_AMOUNT.mulU88(0.5 ether).mul(1 ether);
        assertStruct(sender, s);
        r.ercEscrowed = DEFAULT_AMOUNT.mulU88(0.5 ether);
        assertStruct(receiver, r);

        vm.prank(sender);
        cancelAsk(100);

        s.ercEscrowed = DEFAULT_AMOUNT.mulU88(0.5 ether);
        assertStruct(sender, s);
    }

    function testFail_CancelPreventUseAsHintId() public {
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender); // 100
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender); // 101
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender); // 102

        fundLimitBidOpt(1 ether, 3 ether, sender); // 103

        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender); // 104

        // never matches
        vm.expectRevert("invalid hint");
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT, sender); // 105
    }

    //Testing removing orders far from head
    function setOrderIdAndMakeOrders(O orderType) public {
        vm.prank(owner);
        testFacet.setOrderIdT(asset, 64900);

        //Make lots of orders
        if (orderType == O.LimitBid) {
            for (uint256 i; i < 100; i++) {
                fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            }
        } else if (orderType == O.LimitAsk) {
            for (uint256 i; i < 100; i++) {
                fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            }
        } else if (orderType == O.LimitShort) {
            for (uint256 i; i < 100; i++) {
                fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            }
        }
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
    }

    function test_CancelOrderIfOrderIDTooHighBid() public {
        setOrderIdAndMakeOrders({orderType: O.LimitBid});
        r.ethEscrowed = 0;
        assertStruct(receiver, r);

        vm.prank(owner);
        diamond.cancelOrderFarFromOracle({asset: asset, orderType: O.LimitBid, lastOrderId: 64999, numOrdersToCancel: 5});
        assertEq(getBids().length, 95);

        r.ethEscrowed = DEFAULT_AMOUNT.mul(DEFAULT_PRICE) * 5;
        assertStruct(receiver, r);

        // successfully make bid using reused Id
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
    }

    function test_CancelOrderIfOrderIDTooHighAsk() public {
        setOrderIdAndMakeOrders({orderType: O.LimitAsk});
        r.ercEscrowed = 0;
        assertStruct(receiver, r);

        vm.prank(owner);
        diamond.cancelOrderFarFromOracle({asset: asset, orderType: O.LimitAsk, lastOrderId: 64999, numOrdersToCancel: 5});
        assertEq(getAsks().length, 95);

        r.ercEscrowed = DEFAULT_AMOUNT * 5;
        assertStruct(receiver, r);

        //successfully make ask using reused Id
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
    }

    function test_CancelOrderIfOrderIDTooHighShort() public {
        setOrderIdAndMakeOrders({orderType: O.LimitShort});
        r.ethEscrowed = 0;
        assertStruct(receiver, r);

        vm.prank(owner);
        diamond.cancelOrderFarFromOracle({asset: asset, orderType: O.LimitShort, lastOrderId: 64999, numOrdersToCancel: 5});
        assertEq(getShorts().length, 95);

        r.ethEscrowed = (DEFAULT_AMOUNT.mul(DEFAULT_PRICE)).mul(diamond.getAssetNormalizedStruct(asset).initialCR) * 5;
        assertStruct(receiver, r);

        //successfully make short using reused Id
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
    }

    // Revert
    function test_RevertOrderIdTooLow() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        vm.expectRevert(Errors.OrderIdCountTooLow.selector);
        vm.prank(owner);
        diamond.cancelOrderFarFromOracle({asset: asset, orderType: O.LimitBid, lastOrderId: 64999, numOrdersToCancel: 5});
    }

    function test_RevertMoreThan1000Orders() public {
        vm.prank(owner);
        testFacet.setOrderIdT(asset, 65000);
        vm.expectRevert(Errors.CannotCancelMoreThan1000Orders.selector);
        vm.prank(owner);
        diamond.cancelOrderFarFromOracle({asset: asset, orderType: O.LimitBid, lastOrderId: 64999, numOrdersToCancel: 1001});
    }

    function test_RevertNotLastOrderDAO() public {
        setOrderIdAndMakeOrders({orderType: O.LimitBid});

        vm.prank(owner);
        vm.expectRevert(Errors.NotLastOrder.selector);
        diamond.cancelOrderFarFromOracle({asset: asset, orderType: O.LimitBid, lastOrderId: 59998, numOrdersToCancel: 5});
    }
}
