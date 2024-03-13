// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {C} from "contracts/libraries/Constants.sol";
// import {console} from "contracts/libraries/console.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";

contract TestFacetTest is OBFixture {
    using U256 for uint256;

    function test_TestFacetMisc() public {
        diamond.nonZeroVaultSlot0(1);
        diamond.setErcDebtRate(asset, 1);
    }

    function test_setReentrantStatus() public {
        assertEq(diamond.getReentrantStatus(), C.NOT_ENTERED);
        diamond.setReentrantStatus(C.ENTERED);
        assertEq(diamond.getReentrantStatus(), C.ENTERED);
    }

    function test_getUserOrder_Bids() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        STypes.Order[] memory bids = diamond.getUserOrders(asset, receiver, O.LimitBid);
        assertEq(bids.length, 3);
    }

    function test_getUserOrder_Ask() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        STypes.Order[] memory asks = diamond.getUserOrders(asset, receiver, O.LimitAsk);
        assertEq(asks.length, 3);
    }

    function test_getUserOrder_Short() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        STypes.Order[] memory shorts = diamond.getUserOrders(asset, receiver, O.LimitShort);
        assertEq(shorts.length, 3);
    }

    address[] private bridges;

    function test_DeleteBridge() public {
        uint256 VAULT = 2;
        assertEq(diamond.getBridges(VAULT).length, 0);

        address newBridge1 = makeAddr("1");
        address newBridge2 = makeAddr("2");
        address newBridge3 = makeAddr("3");

        vm.prank(owner);
        diamond.createBridge(newBridge1, VAULT, 0);
        bridges = [newBridge1];
        assertEq(diamond.getBridges(VAULT), bridges);
        assertEq(diamond.getBridges(VAULT).length, 1);
        assertEq(diamond.getBridgeVault(newBridge1), VAULT);
        assertEq(diamond.getBridgeVault(newBridge2), 0);
        assertEq(diamond.getBridgeVault(newBridge3), 0);

        vm.prank(owner);
        diamond.createBridge(newBridge2, VAULT, 0);
        bridges = [newBridge1, newBridge2];
        assertEq(diamond.getBridges(VAULT), bridges);
        assertEq(diamond.getBridges(VAULT).length, 2);
        assertEq(diamond.getBridgeVault(newBridge1), VAULT);
        assertEq(diamond.getBridgeVault(newBridge2), VAULT);
        assertEq(diamond.getBridgeVault(newBridge3), 0);

        vm.prank(owner);
        diamond.createBridge(newBridge3, VAULT, 0);
        bridges = [newBridge1, newBridge2, newBridge3];
        assertEq(diamond.getBridges(VAULT), bridges);
        assertEq(diamond.getBridges(VAULT).length, 3);
        assertEq(diamond.getBridgeVault(newBridge1), VAULT);
        assertEq(diamond.getBridgeVault(newBridge2), VAULT);
        assertEq(diamond.getBridgeVault(newBridge3), VAULT);

        vm.prank(owner);
        diamond.deleteBridge(newBridge1);
        bridges = [newBridge3, newBridge2];
        assertEq(diamond.getBridges(VAULT), bridges);
        assertEq(diamond.getBridges(VAULT).length, 2);
        assertEq(diamond.getBridgeVault(newBridge1), 0);
        assertEq(diamond.getBridgeVault(newBridge2), VAULT);
        assertEq(diamond.getBridgeVault(newBridge2), VAULT);

        vm.prank(owner);
        diamond.deleteBridge(newBridge2);
        bridges = [newBridge3];
        assertEq(diamond.getBridges(VAULT), bridges);
        assertEq(diamond.getBridges(VAULT).length, 1);
        assertEq(diamond.getBridgeVault(newBridge1), 0);
        assertEq(diamond.getBridgeVault(newBridge2), 0);
        assertEq(diamond.getBridgeVault(newBridge3), VAULT);

        vm.prank(owner);
        diamond.deleteBridge(newBridge3);
        assertEq(diamond.getBridges(VAULT).length, 0);
        assertEq(diamond.getBridgeVault(newBridge1), 0);
        assertEq(diamond.getBridgeVault(newBridge2), 0);
        assertEq(diamond.getBridgeVault(newBridge3), 0);
    }
}
