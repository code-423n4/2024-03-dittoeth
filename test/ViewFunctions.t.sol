// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {C} from "contracts/libraries/Constants.sol";
import {MTypes, O} from "contracts/libraries/DataTypes.sol";
import {STypes} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {console} from "contracts/libraries/console.sol";

contract ViewFunctionsTest is OBFixture {
    using U256 for uint256;

    // OracleFacet
    function test_view_getProtocolAssetPrice() public {
        uint256 price = 4000 ether;
        assertEq(diamond.getProtocolAssetPrice(asset), price.inv());
    }

    // ShortRecordFacet
    function test_view_getShortRecords() public {
        assertEq(getShortRecordCount(sender), 0);
        assertEq(diamond.getShortRecords(asset, sender).length, 0);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(getShortRecordCount(sender), 1);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(getShortRecordCount(sender), 2);

        STypes.ShortRecord memory short = getShortRecord(sender, C.SHORT_STARTING_ID);
        STypes.ShortRecord memory short2 = getShortRecord(sender, C.SHORT_STARTING_ID + 1);
        assertEqShort(diamond.getShortRecords(asset, sender)[0], short2);
        assertEqShort(diamond.getShortRecords(asset, sender)[1], short);
    }

    // VaultFacet
    function test_view_getDethBalance() public {
        assertEq(diamond.getDethBalance(vault, sender), 0);

        vm.deal(sender, 10000 ether);
        uint256 deposit1 = 1000 ether;
        vm.prank(sender);
        diamond.depositEth{value: deposit1}(_bridgeReth);
        assertEq(diamond.getDethBalance(vault, sender), deposit1);
    }

    function test_view_getAssetBalance() public {
        assertEq(diamond.getAssetBalance(asset, sender), 0);
        depositUsd(sender, DEFAULT_AMOUNT);
        assertEq(diamond.getAssetBalance(asset, sender), DEFAULT_AMOUNT);
    }

    function test_view_getVault() public {
        assertEq(diamond.getVault(asset), vault);
    }

    // OrdersFacet
    function test_view_getXHintId() public {
        assertEq(diamond.getBidHintId(asset, DEFAULT_PRICE), 1);
        assertEq(diamond.getShortHintId(asset, DEFAULT_PRICE), 1);
        assertEq(diamond.getAskHintId(asset, DEFAULT_PRICE), 1);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, receiver);

        assertEq(diamond.getBidHintId(asset, DEFAULT_PRICE), 101);
        assertEq(diamond.getAskHintId(asset, DEFAULT_PRICE + 2), 103);
        assertEq(diamond.getShortHintId(asset, DEFAULT_PRICE + 2), 105);
    }

    function test_view_getShortIdAtOracle() public {
        assertEq(diamond.getShortIdAtOracle(asset), 1);

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE - 1, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, receiver);

        assertEq(diamond.getShortIdAtOracle(asset), 100);
    }

    function test_view_getHintArray() public {
        uint256 numHints = 10;
        for (uint80 i = 0; i < numHints; i++) {
            fundLimitBidOpt(DEFAULT_PRICE + i, DEFAULT_AMOUNT, receiver);
        }

        MTypes.OrderHint[] memory orderHintArray;
        orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE + 2, O.LimitBid, numHints);

        assertEq(orderHintArray.length, numHints);
        assertEq(orderHintArray[0].hintId, 102);
        assertEq(orderHintArray[1].hintId, 101);
        assertEq(orderHintArray[2].hintId, 100);

        //@dev after 100 is C.TAIl, so every hint will be 0
        for (uint256 i = 3; i < numHints; i++) {
            assertEq(orderHintArray[i].hintId, 0);
        }
    }

    function test_view_getAskHintArray() public {
        uint256 numHints = 10;
        for (uint80 i = 0; i < numHints; i++) {
            fundLimitAskOpt(DEFAULT_PRICE + i, DEFAULT_AMOUNT, receiver);
        }

        MTypes.OrderHint[] memory orderHintArray;
        orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE + 2, O.LimitAsk, numHints);

        assertEq(orderHintArray.length, numHints);
        assertEq(orderHintArray[0].hintId, 102);
        assertEq(orderHintArray[1].hintId, 103);
        assertEq(orderHintArray[2].hintId, 104);
        assertEq(orderHintArray[3].hintId, 105);
        assertEq(orderHintArray[4].hintId, 106);
        assertEq(orderHintArray[5].hintId, 107);
        assertEq(orderHintArray[6].hintId, 108);
        assertEq(orderHintArray[7].hintId, 109);
        assertEq(orderHintArray[8].hintId, 0);
        assertEq(orderHintArray[9].hintId, 0);
    }

    function createPartiallyFilledShorts() public {
        fundLimitShortOpt(DEFAULT_PRICE + 10 wei, DEFAULT_AMOUNT, sender); //100
        fundLimitBidOpt(DEFAULT_PRICE + 10 wei, DEFAULT_AMOUNT - 100 ether, receiver);
        fundLimitShortOpt(DEFAULT_PRICE + 7 wei, DEFAULT_AMOUNT, sender); //101
        fundLimitBidOpt(DEFAULT_PRICE + 7 wei, DEFAULT_AMOUNT - 100 ether, receiver);
        fundLimitShortOpt(DEFAULT_PRICE + 5 wei, DEFAULT_AMOUNT, receiver); //102
        fundLimitBidOpt(DEFAULT_PRICE + 5 wei, DEFAULT_AMOUNT - 100 ether, receiver);
        fundLimitShortOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT, extra); //103
        fundLimitBidOpt(DEFAULT_PRICE + 2 wei, DEFAULT_AMOUNT - 100 ether, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra); //104
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT - 100 ether, receiver);
    }

    function test_view_getShortOrderId() public {
        createPartiallyFilledShorts();
        uint16 shortOrderId;

        shortOrderId = diamond.getShortOrderId(asset, sender, C.SHORT_STARTING_ID);
        assertEq(shortOrderId, 100);
        shortOrderId = diamond.getShortOrderId(asset, sender, C.SHORT_STARTING_ID + 1);
        assertEq(shortOrderId, 101);
        shortOrderId = diamond.getShortOrderId(asset, receiver, C.SHORT_STARTING_ID);
        assertEq(shortOrderId, 102);
        shortOrderId = diamond.getShortOrderId(asset, extra, C.SHORT_STARTING_ID);
        assertEq(shortOrderId, 103);
        shortOrderId = diamond.getShortOrderId(asset, extra, C.SHORT_STARTING_ID + 1);
        assertEq(shortOrderId, 104);
    }

    function test_view_getShortOrderIdArray() public {
        createPartiallyFilledShorts();

        uint8[] memory shortRecordIds = new uint8[](2);
        shortRecordIds[0] = C.SHORT_STARTING_ID;
        shortRecordIds[1] = C.SHORT_STARTING_ID + 1;

        uint16[] memory shortOrderIdArray = diamond.getShortOrderIdArray(asset, sender, shortRecordIds);

        assertEq(shortOrderIdArray[0], 100);
        assertEq(shortOrderIdArray[1], 101);

        shortOrderIdArray = diamond.getShortOrderIdArray(asset, extra, shortRecordIds);
        assertEq(shortOrderIdArray[0], 103);
        assertEq(shortOrderIdArray[1], 104);
    }

    function test_view_getMinShortErc() public {
        assertEq(diamond.getMinShortErc(asset), 2000 ether);
        vm.startPrank(owner);
        diamond.setMinShortErc(asset, 3000);
        assertEq(diamond.getMinShortErc(asset), 3000 ether);
    }
}
