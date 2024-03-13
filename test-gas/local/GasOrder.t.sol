// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {GasHelper} from "test-gas/GasHelper.sol";
import {C} from "contracts/libraries/Constants.sol";
import {MTypes, O} from "contracts/libraries/DataTypes.sol";

// import {console} from "contracts/libraries/console.sol";

contract GasCreate is GasHelper {
    using U88 for uint88;

    function setUp() public virtual override {
        super.setUp();
    }

    function testGas_CreateBid() public deposits {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateBid-New");
        diamond.createBid(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray, shortHintArray);
        stopMeasuringGas();
        assertEq(ob.getBids().length, 1);
    }

    function testGas_CreateAsk() public deposits {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateAsk-New");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        assertEq(ob.getAsks().length, 1);
    }

    function testGas_CreateShort() public deposits {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: DEFAULT_SHORT_HINT_ID});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateShort-New");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        assertEq(ob.getShorts().length, 1);
    }
}

contract GasCancelOrders is GasHelper {
    // canceling from the beginning or end saves 4800 gas
    function testGas_CancelAsk() public {
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 101
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 102

        address _asset = asset;

        vm.prank(receiver);
        startMeasuringGas("Order-CancelAsk");
        diamond.cancelAsk(_asset, 101);
        stopMeasuringGas();

        assertEq(ob.getAsks().length, 2);
    }

    function testGas_CancelBid() public {
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 101
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 102

        address _asset = asset;

        vm.prank(receiver);
        startMeasuringGas("Order-CancelBid");
        diamond.cancelBid(_asset, 101);
        stopMeasuringGas();

        assertEq(ob.getBids().length, 2);
    }

    function testGas_CancelShort() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 101
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 102
        // Partial match with 100
        ob.fundLimitBidOpt(DEFAULT_PRICE, minShortErc, sender);

        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CancelShort");
        diamond.cancelShort(_asset, 102);
        stopMeasuringGas();
        assertEq(ob.getShorts().length, 2);
    }

    function testGas_CancelShortAfterPartialFill() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 101
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 102
        // Partial match with 100
        ob.fundLimitBidOpt(DEFAULT_PRICE, minShortErc, sender);

        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CancelShort-RecordExists");
        diamond.cancelShort(_asset, 100);
        stopMeasuringGas();
        assertEq(ob.getShorts().length, 2);
    }

    function testGas_CancelShortAfterPartialFillCancelled() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 101
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 102
        // Full match with 100, partial match with 101
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, minShortErc, sender);
        // Exit shortRecord created by partial match with shortOrder 101
        uint8[] memory shortRecords = new uint8[](2);
        shortRecords[0] = C.SHORT_STARTING_ID + 1;
        shortRecords[1] = C.SHORT_STARTING_ID;
        uint16[] memory shortOrderIds = new uint16[](2);
        shortOrderIds[0] = 0;
        shortOrderIds[1] = 0;
        vm.prank(receiver);
        diamond.combineShorts(asset, shortRecords, shortOrderIds);

        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CancelShort-RecordExistsButCancelled");
        diamond.cancelShort(_asset, 101);
        stopMeasuringGas();
        assertEq(ob.getShorts().length, 1);
    }

    function testGas_CancelShortUnderMinShortErc() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        ob.fundLimitBidOpt(DEFAULT_PRICE, minShortErc - 1 wei, sender);
        assertEq(ob.getShorts().length, 1);

        address _asset = asset;

        vm.prank(receiver);
        startMeasuringGas("Order-CancelShort-underMinShortErc");
        diamond.cancelShort(_asset, 100);
        stopMeasuringGas();
        assertEq(ob.getShorts().length, 0);
    }
}

contract GasPlaceBidOnObWithHintTest is GasHelper {
    function setUp() public virtual override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE + 0, DEFAULT_AMOUNT, receiver); // 100
        ob.fundLimitBidOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, receiver); // 101
        ob.fundLimitBidOpt(DEFAULT_PRICE + 3, DEFAULT_AMOUNT, receiver); // 102
        ob.fundLimitBidOpt(DEFAULT_PRICE + 4, DEFAULT_AMOUNT, receiver); // 103

        // re-use id
        ob.fundLimitBidOpt(DEFAULT_PRICE + 5, DEFAULT_AMOUNT, receiver); // 104
        vm.prank(receiver);
        diamond.cancelBid(asset, 104);
    }

    function testGas_CreateAskOrderHintOffForward1() public deposits {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateBid-Reuse-HintOffPlus1");
        diamond.createBid(_asset, DEFAULT_PRICE + 3, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray, shortHintArray); // supposed to be 102
        stopMeasuringGas();
        assertEq(ob.getBids().length, 5);
    }

    function testGas_CreateAskOrderHintOffBack1() public deposits {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateBid-Reuse-HintOffMinus1");
        diamond.createBid(_asset, DEFAULT_PRICE + 2, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray, shortHintArray); // supposed to be 101
        stopMeasuringGas();
        assertEq(ob.getBids().length, 5);
    }

    // @dev testGasCreateBidIncomingIsBestPrice should be < testGasCreateBidIncomingIsNotBestPrice
    function testGas_CreateBidIncomingIsBestPrice() public deposits {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateBid-IgnoreHintEvaulation");
        diamond.createBid(_asset, DEFAULT_PRICE + 10, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray, shortHintArray);
        stopMeasuringGas();
        assertEq(ob.getBids().length, 5);
    }

    function testGas_CreateBidIncomingIsNotBestPrice() public deposits {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(receiver);
        startMeasuringGas("Order-CreateBid-UseHintEvaulation");
        diamond.createBid(_asset, DEFAULT_PRICE - 1, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray, shortHintArray);
        stopMeasuringGas();
        assertEq(ob.getBids().length, 5);
    }
}

contract GasPlaceAskOnObWithHintTest is GasHelper {
    function setUp() public virtual override {
        super.setUp();
        ob.fundLimitAskOpt(DEFAULT_PRICE + 4, DEFAULT_AMOUNT, sender); // 100
        ob.fundLimitAskOpt(DEFAULT_PRICE + 3, DEFAULT_AMOUNT, sender); // 101
        ob.fundLimitAskOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, sender); // 102
        ob.fundLimitAskOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, sender); // 103

        // re-use id
        ob.fundLimitAskOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, sender); // 104
        vm.prank(sender);
        diamond.cancelAsk(asset, 104);
    }

    // @dev testGasCreateAskIncomingIsBestPrice should be < testGasCreateAskIncomingIsNotBestPrice
    function testGas_CreateAskIncomingIsBestPrice() public deposits {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-CreateAsk-IgnoreHintEvaulation");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        assertEq(ob.getAsks().length, 5);
    }

    function testGas_CreateAskIncomingIsNotBestPrice() public deposits {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-CreateAsk-UseHintEvaulation");
        diamond.createAsk(_asset, DEFAULT_PRICE + 10, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        assertEq(ob.getAsks().length, 5);
    }
}

contract GasPlaceShortOnObWithHintTest is GasHelper {
    function setUp() public virtual override {
        super.setUp();
        ob.fundLimitShortOpt(DEFAULT_PRICE + 4, DEFAULT_AMOUNT, sender); // 100
        ob.fundLimitShortOpt(DEFAULT_PRICE + 3, DEFAULT_AMOUNT, sender); // 101
        ob.fundLimitShortOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, sender); // 102
        ob.fundLimitShortOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, sender); // 103

        // re-use id
        ob.fundLimitShortOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, sender); // 104
        vm.prank(sender);
        diamond.cancelShort(asset, 104);
    }

    // @dev testGasCreateShortIncomingIsBestPrice should be < testGasCreateShortIncomingIsNotBestPrice
    function testGas_CreateShortIncomingIsBestPrice() public deposits {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-CreateShort-IgnoreHintEvaulation");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        assertEq(ob.getShorts().length, 5);
    }

    function testGas_CreateShortIncomingIsNotBestPrice() public deposits {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-CreateShort-UseHintEvaulation");
        diamond.createLimitShort(_asset, DEFAULT_PRICE + 10, DEFAULT_AMOUNT, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        assertEq(ob.getShorts().length, 5);
    }
}

contract GasCancelBidFarFromHead is GasHelper {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(owner);
        testFacet.setOrderIdT(asset, 64900);
        for (uint256 i; i < 100; i++) {
            ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getBids().length, 100);
    }

    function testGas_CancelBidFarFromHead() public {
        address _asset = asset;
        vm.prank(owner);
        startMeasuringGas("Order-GasCancelBidFarFromHead");
        diamond.cancelOrderFarFromOracle({asset: _asset, orderType: O.LimitBid, lastOrderId: 64999, numOrdersToCancel: 1});
        stopMeasuringGas();
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getBids().length, 99);
    }

    function testGas_CancelBidFarFromHeadDAO100X() public {
        address _asset = asset;
        vm.prank(owner);
        startMeasuringGas("Order-GasCancelBidFarFromHead-DAO-100X");
        diamond.cancelOrderFarFromOracle({asset: _asset, orderType: O.LimitBid, lastOrderId: 64999, numOrdersToCancel: 100});
        stopMeasuringGas();
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getBids().length, 0);
    }
}

contract GasCancelAskFarFromHead is GasHelper {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(owner);
        testFacet.setOrderIdT(asset, 64900);
        for (uint256 i; i < 100; i++) {
            ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getAsks().length, 100);
    }

    function testGas_CancelAskFarFromHead() public {
        address _asset = asset;
        vm.prank(owner);
        startMeasuringGas("Order-GasCancelAskFarFromHead");
        diamond.cancelOrderFarFromOracle({asset: _asset, orderType: O.LimitAsk, lastOrderId: 64999, numOrdersToCancel: 1});
        stopMeasuringGas();
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getAsks().length, 99);
    }

    function testGas_CancelAskFarFromHeadDAO100X() public {
        address _asset = asset;
        vm.prank(owner);
        startMeasuringGas("Order-GasCancelAskFarFromHead-DAO-100X");
        diamond.cancelOrderFarFromOracle({asset: _asset, orderType: O.LimitAsk, lastOrderId: 64999, numOrdersToCancel: 100});
        stopMeasuringGas();
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getAsks().length, 0);
    }
}

contract GasCancelShortFarFromHead is GasHelper {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(owner);
        testFacet.setOrderIdT(asset, 64900);
        for (uint256 i; i < 100; i++) {
            ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getShorts().length, 100);
    }

    function testGas_CancelShortFarFromHead() public {
        address _asset = asset;
        vm.prank(owner);
        startMeasuringGas("Order-GasCancelShortFarFromHead");
        diamond.cancelOrderFarFromOracle({asset: _asset, orderType: O.LimitShort, lastOrderId: 64999, numOrdersToCancel: 1});
        stopMeasuringGas();
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getShorts().length, 99);
    }

    function testGas_CancelShortFarFromHeadDAO100X() public {
        address _asset = asset;
        vm.prank(owner);
        startMeasuringGas("Order-GasCancelShortFarFromHead-DAO-100X");
        diamond.cancelOrderFarFromOracle({asset: _asset, orderType: O.LimitShort, lastOrderId: 64999, numOrdersToCancel: 100});
        stopMeasuringGas();
        assertEq(diamond.getAssetNormalizedStruct(asset).orderId, 65000);
        assertEq(ob.getShorts().length, 0);
    }
}
