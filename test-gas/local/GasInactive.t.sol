// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {GasHelper} from "test-gas/GasHelper.sol";
import {C} from "contracts/libraries/Constants.sol";
import {MTypes} from "contracts/libraries/DataTypes.sol";

// import {console} from "contracts/libraries/console.sol";

// @dev re-use by cancel or matched is the same cost
contract GasCreateCancelledTest is GasHelper {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        super.setUp();

        ob.depositUsd(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(receiver, 100 ether);
        ob.depositUsd(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(sender, 100 ether);
    }

    function testGas_CreateFromCancelledAsk() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;

        vm.startPrank(receiver);
        diamond.createAsk(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray); // 100
        diamond.createAsk(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray); // 101
        diamond.cancelAsk(asset, 100);

        startMeasuringGas("Order-CreateAsk-Reuse");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray); // 100
        stopMeasuringGas();
    }

    function testGas_CreateFromCancelledShort() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: DEFAULT_SHORT_HINT_ID});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.startPrank(receiver);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArray, initialCR); // 100
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArray, initialCR); // 101
        diamond.cancelShort(asset, 100);

        startMeasuringGas("Order-CreateShort-Reuse");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArray, initialCR); // 100
        stopMeasuringGas();
    }

    function testGas_CreateFromCancelledBid() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.startPrank(receiver);
        diamond.createBid(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray, shortHintArray); // 100
        diamond.createBid(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray, shortHintArray); // 101
        diamond.cancelBid(asset, 100);

        startMeasuringGas("Order-CreateBid-Reuse");
        diamond.createBid(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray, shortHintArray); // 100
        stopMeasuringGas();
    }
}
