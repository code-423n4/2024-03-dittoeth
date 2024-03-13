// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";
import {C} from "contracts/libraries/Constants.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract AskHintTest is OBFixture {
    uint256 private startGas;
    uint256 private gasUsed;
    uint256 private gasUsedOptimized;

    bool private constant ASK = true;
    bool private constant SHORT = false;

    // @dev AskHintTest is testing both ask and shorts
    function setUp() public override {
        super.setUp();
    }

    function currentOrders(O orderType) public view returns (STypes.Order[] memory orders) {
        if (orderType == O.LimitBid) {
            return getBids();
        } else if (orderType == O.LimitAsk) {
            return getAsks();
        } else if (orderType == O.LimitShort) {
            return getShorts();
        } else {
            revert("Invalid OrderType");
        }
    }

    ///////////Testing gas for optimized orders < non-optimized
    function addAskOrdersForTesting(bool askType, uint256 numOrders) public {
        depositEth(receiver, 1000000 ether);
        depositUsd(receiver, 1000000 ether);
        vm.startPrank(receiver);

        MTypes.OrderHint[] memory orderHintArray;

        //fill up market
        for (uint256 i = 0; i < numOrders; i++) {
            if (askType == SHORT) {
                orderHintArray = diamond.getHintArray(asset, DEFAULT_AMOUNT * 5, O.LimitShort, 1);
                diamond.createLimitShort(
                    asset, DEFAULT_PRICE * 5, DEFAULT_AMOUNT * 5, orderHintArray, shortHintArrayStorage, initialCR
                );
            } else {
                orderHintArray = diamond.getHintArray(asset, DEFAULT_AMOUNT * 5, O.LimitAsk, 1);
                diamond.createAsk(asset, DEFAULT_PRICE * 5, DEFAULT_AMOUNT * 5, C.LIMIT_ORDER, orderHintArray);
            }
        }

        //add one more order (non optimized)
        if (askType == SHORT) {
            orderHintArray = diamond.getHintArray(asset, DEFAULT_AMOUNT * 6, O.LimitShort, 1);
            startGas = gasleft();
            diamond.createLimitShort(asset, DEFAULT_PRICE * 6, DEFAULT_AMOUNT * 6, orderHintArray, shortHintArrayStorage, initialCR);
        } else {
            orderHintArray = diamond.getHintArray(asset, DEFAULT_AMOUNT * 6, O.LimitAsk, 1);
            startGas = gasleft();
            diamond.createAsk(asset, DEFAULT_PRICE * 6, DEFAULT_AMOUNT * 6, C.LIMIT_ORDER, orderHintArray);
        }
        gasUsed = startGas - gasleft();
        // emit log_named_uint("gasUsed", gasUsed);

        //add one more order (optimized)
        if (askType == SHORT) {
            orderHintArray = diamond.getHintArray(asset, DEFAULT_AMOUNT * 6, O.LimitShort, 1);
            startGas = gasleft();
            diamond.createLimitShort(asset, DEFAULT_PRICE * 6, DEFAULT_AMOUNT * 6, orderHintArray, shortHintArrayStorage, initialCR);
        } else {
            orderHintArray = diamond.getHintArray(asset, DEFAULT_AMOUNT * 6, O.LimitAsk, 1);
            startGas = gasleft();
            diamond.createAsk(asset, DEFAULT_PRICE * 6, DEFAULT_AMOUNT * 6, C.LIMIT_ORDER, orderHintArray);
        }
        gasUsedOptimized = startGas - gasleft();
        // emit log_named_uint("gasUsedOptimized", gasUsedOptimized);
        vm.stopPrank();
    }

    function test_OptGasAddingShortNumOrders2() public {
        uint256 numOrders = 2;
        addAskOrdersForTesting(SHORT, numOrders);
        assertGt(gasUsed, gasUsedOptimized);
    }

    function test_OptGasAddingShortNumOrders25() public {
        uint256 numOrders = 25;
        addAskOrdersForTesting(SHORT, numOrders);
        assertGt(gasUsed, gasUsedOptimized);
    }

    function test_OptGasAddingSellNumOrders2() public {
        uint256 numOrders = 2;
        addAskOrdersForTesting(ASK, numOrders);
        assertGt(gasUsed, gasUsedOptimized);
    }

    function test_OptGasAddingSellNumOrders25() public {
        uint256 numOrders = 25;
        addAskOrdersForTesting(ASK, numOrders);
        assertGt(gasUsed, gasUsedOptimized);
    }

    //HINT!
    function fundHint() public {
        fundOrder(O.LimitAsk, DEFAULT_PRICE, DEFAULT_AMOUNT, sender); //100
        fundOrder(O.LimitAsk, DEFAULT_PRICE + 3 wei, DEFAULT_AMOUNT, sender); //101
        fundOrder(O.LimitAsk, DEFAULT_PRICE + 5 wei, DEFAULT_AMOUNT, sender); //102
        fundOrder(O.LimitAsk, DEFAULT_PRICE + 10 wei, DEFAULT_AMOUNT, sender); //103
    }

    function assertEqHint(STypes.Order[] memory asks) public {
        assertEq(asks[0].id, 100);
        assertEq(asks[1].id, 101);
        assertEq(asks[2].id, 104);
        assertEq(asks[3].id, 102);
        assertEq(asks[4].id, 103);

        assertEq(asks[0].price, DEFAULT_PRICE);
        assertEq(asks[1].price, DEFAULT_PRICE + 3 wei);
        assertEq(asks[2].price, DEFAULT_PRICE + 4 wei);
        assertEq(asks[3].price, DEFAULT_PRICE + 5 wei);
        assertEq(asks[4].price, DEFAULT_PRICE + 10 wei);
    }

    function test_HintMoveBackAsk1() public {
        fundHint();
        fundLimitAskOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, sender);
        assertEqHint(currentOrders(O.LimitAsk));
    }

    function test_HintMoveBackAsk2() public {
        fundHint();
        fundLimitAskOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, sender);
        assertEqHint(currentOrders(O.LimitAsk));
    }

    function test_HintMoveForwardAsk1() public {
        fundHint();
        fundLimitAskOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, sender);
        assertEqHint(currentOrders(O.LimitAsk));
    }

    function test_HintExactMatchAsk() public {
        fundHint();
        fundLimitAskOpt(DEFAULT_PRICE + 4 wei, DEFAULT_AMOUNT, sender);
        assertEqHint(currentOrders(O.LimitAsk));
    }

    function test_HintAsk() public {
        fundHint();
        fundLimitAskOpt(DEFAULT_PRICE + 4, DEFAULT_AMOUNT, sender);
        assertEqHint(currentOrders(O.LimitAsk));
    }

    //PrevId/NextId
    function test_ProperIDSettingAsk() public {
        uint16 numOrders = 10;
        for (uint16 i = 1; i <= numOrders; i++) {
            fundLimitAskOpt(DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, receiver);
        }

        uint16 _id = C.HEAD;
        (uint16 prevId, uint16 nextId) = testFacet.getAskKey(asset, _id);
        uint256 index = 0;
        STypes.Order[] memory asks = getAsks();

        while (index <= asks.length) {
            (, _id) = testFacet.getAskKey(asset, _id);
            (prevId, nextId) = testFacet.getAskKey(asset, _id);
            if ((_id != C.HEAD && _id != C.TAIL) && (nextId != C.HEAD && nextId != C.TAIL)) {
                // testFacet.logAsks(asset);
                assertTrue(prevId < nextId);
            }
            index++;
        }
    }

    function test_ProperIDSettingAskForLoop() public {
        //NOTE: This test is good for logging
        // uint256 C.HEAD = 1;
        uint80 numOrders = 50;

        //creating asks
        for (uint80 i = 1; i <= numOrders; i++) {
            fundLimitAskOpt(DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, receiver);
        }
        for (uint80 i = numOrders; i > 0; i--) {
            fundLimitAskOpt(DEFAULT_PRICE + i, i * DEFAULT_AMOUNT, receiver);
        }

        checkOrdersPriceValidity();
    }

    // order Hint Array
    function createSellsInMarket(bool sellType) public {
        if (sellType == ASK) {
            fundLimitAskOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
            fundLimitAskOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
            fundLimitAskOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
            fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            assertEq(getAsks()[0].id, 103);
            depositUsdAndPrank(receiver, DEFAULT_AMOUNT);
        } else {
            fundLimitShortOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            assertEq(getShorts()[0].id, 103);
            // @dev arbitrary amt
            depositEthAndPrank(receiver, DEFAULT_AMOUNT * 10);
        }
    }

    function revertOnBadHintIdArray(bool sellType) public {
        vm.expectRevert(Errors.BadHintIdArray.selector);
        if (sellType == ASK) {
            diamond.createAsk(asset, DEFAULT_PRICE * 2, DEFAULT_AMOUNT, C.LIMIT_ORDER, badOrderHintArray);
            // orderHintArray
        } else {
            diamond.createLimitShort(asset, DEFAULT_PRICE * 2, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
        }
    }

    function test_Revert_BadHintIdArrayAsk() public {
        createSellsInMarket({sellType: ASK});
        revertOnBadHintIdArray({sellType: ASK});
    }

    function test_FindProperAskHintId() public {
        createSellsInMarket({sellType: ASK});
        revertOnBadHintIdArray({sellType: ASK});
        fundLimitAskOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, receiver);
    }

    function test_RevertBadHintIdArrayShort() public {
        createSellsInMarket({sellType: SHORT});
        revertOnBadHintIdArray({sellType: SHORT});
    }

    function test_FindProperShortHintId() public {
        createSellsInMarket({sellType: SHORT});
        revertOnBadHintIdArray({sellType: SHORT});

        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE * 2, O.LimitShort, 1);

        vm.prank(receiver);
        diamond.createLimitShort(asset, DEFAULT_PRICE * 2, DEFAULT_AMOUNT, orderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_GetAskHintArray() public {
        createSellsInMarket({sellType: ASK});

        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitAsk, 1);

        assertEq(orderHintArray[0].creationTime, getAsks()[0].creationTime);

        vm.prank(receiver);
        diamond.createAsk(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray);
        assertEq(getAsks()[1].id, 104);
    }

    function test_GetShortHintArray() public {
        createSellsInMarket({sellType: SHORT});

        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitShort, 1);

        assertEq(orderHintArray[0].creationTime, getShorts()[0].creationTime);

        vm.prank(receiver);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArrayStorage, initialCR);
        assertEq(getShorts()[1].id, 104);
    }

    function test_AddBestAskNotUsingOrderHint() public {
        createSellsInMarket({sellType: ASK});
        vm.stopPrank();
        fundLimitAskOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, receiver);
        assertEq(getAsks().length, 5);
        assertEq(getAsks()[0].id, 104);
        assertEq(getAsks()[1].id, 103);
        assertEq(getAsks()[2].id, 100);
    }

    function test_AddBestShortNotUsingOrderHint() public {
        createSellsInMarket({sellType: SHORT});
        vm.stopPrank();
        fundLimitShortOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, receiver);
        assertEq(getShorts().length, 5);
        assertEq(getShorts()[0].id, 104);
        assertEq(getShorts()[1].id, 103);
        assertEq(getShorts()[2].id, 100);
    }

    //testing when creationTime is different
    function createMatchAndReuseFirstSell(bool sellType) public returns (MTypes.OrderHint[] memory orderHintArray) {
        if (sellType == ASK) {
            fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitAsk, 1);
        } else if (sellType == SHORT) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitShort, 1);
        }

        assertEq(orderHintArray[0].hintId, 100);
        assertEq(orderHintArray[0].creationTime, 1 seconds);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        skip(1 seconds);

        orderHintArray = new MTypes.OrderHint[](1);
        orderHintArray[0] = MTypes.OrderHint({hintId: 100, creationTime: 123});

        if (sellType == ASK) {
            fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            assertNotEq(orderHintArray[0].creationTime, getAsks()[0].creationTime);
        } else if (sellType == SHORT) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            assertNotEq(orderHintArray[0].creationTime, getShorts()[0].creationTime);
        }

        return orderHintArray;
    }

    function test_AddAskReusedMatched() public {
        MTypes.OrderHint[] memory orderHintArray = createMatchAndReuseFirstSell({sellType: ASK});

        //create ask with outdated hint array
        depositUsdAndPrank(sender, DEFAULT_AMOUNT);
        diamond.createAsk(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray);
    }

    function test_AddShortReusedMatched() public {
        MTypes.OrderHint[] memory orderHintArray = createMatchAndReuseFirstSell({sellType: SHORT});

        //create short with outdated hint array
        depositEthAndPrank(sender, 10 ether);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArrayStorage, initialCR);
    }

    // @dev pass in a hint that needs to move backwards on linked list
    function test_GetOrderIdDirectionPrevAsk() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(DEFAULT_PRICE + 3 wei, DEFAULT_AMOUNT, sender);

        MTypes.OrderHint[] memory orderHintArray = new MTypes.OrderHint[](1);
        orderHintArray[0] = MTypes.OrderHint({hintId: 103, creationTime: 1});

        depositUsdAndPrank(sender, DEFAULT_AMOUNT);
        diamond.createAsk(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray);
    }

    function test_GetOrderIdDirectionPrevShort() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitShortOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);
        fundLimitShortOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT, sender);
        fundLimitShortOpt(DEFAULT_PRICE + 3 wei, DEFAULT_AMOUNT, sender);

        MTypes.OrderHint[] memory orderHintArray = new MTypes.OrderHint[](1);
        orderHintArray[0] = MTypes.OrderHint({hintId: 103, creationTime: 1});

        depositEthAndPrank(sender, 10 ether);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArrayStorage, initialCR);
    }
}
