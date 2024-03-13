// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {F, MTypes} from "contracts/libraries/DataTypes.sol";
import {C} from "contracts/libraries/Constants.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
// import {console} from "contracts/libraries/console.sol";

contract ReentrancyTest is OBFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        testFacet.setReentrantStatus(C.ENTERED);
    }

    //Non-view
    function test_ReentrancyCreateAsk() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.createAsk(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, badOrderHintArray);
    }

    function test_ReentrancyCreateBid() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.createBid(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, badOrderHintArray, shortHintArrayStorage);
    }

    function test_ReentrancyDeposit() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.deposit(_bridgeReth, DEFAULT_AMOUNT);
    }

    function test_ReentrancyDepositEth() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.depositEth{value: 5 ether}(_bridgeSteth);
    }

    function test_ReentrancyWithdraw() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.withdraw(_bridgeReth, 1);
    }

    function test_ReentrancyExitShortWallet() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.exitShortWallet(asset, 1, 1, 0);
    }

    function test_ReentrancyExitShortErcEscrowed() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.exitShortErcEscrowed(asset, 1, 1, 0);
    }

    function test_ReentrancyExitShort() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.exitShort(asset, 100, 2 ether, DEFAULT_PRICE, shortHintArrayStorage, 0);
    }

    function test_ReentrancyRedeemErc() public {
        vm.prank(owner);
        diamond.setFrozenT(asset, F.Permanent);
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.redeemErc(asset, 0, DEFAULT_AMOUNT);
    }

    function test_ReentrancyLiquidateWallet() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        liquidateWallet(sender, 100, DEFAULT_AMOUNT, receiver);
    }

    function test_ReentrancyLiquidateErcEscrowed() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        liquidateErcEscrowed(sender, 100, DEFAULT_AMOUNT, receiver);
    }

    function test_ReentrancyLiquidate() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.liquidate(asset, sender, 100, shortHintArrayStorage, 0);
    }

    function test_ReentrancyCancelBid() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.cancelBid(asset, 1);
    }

    function test_ReentrancyCancelAsk() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.cancelAsk(asset, 1);
    }

    function test_ReentrancyCancelShort() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.cancelShort(asset, 1);
    }

    function test_ReentrancyIncreaseCollateral() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.increaseCollateral(asset, 100, 120 ether);
    }

    function test_ReentrancyDecreaseCollateral() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.decreaseCollateral(asset, 100, 120 ether);
    }

    function test_ReentrancyCombineShorts() public {
        uint8[] memory shortRecords = new uint8[](3);
        shortRecords[0] = C.SHORT_STARTING_ID;
        shortRecords[1] = C.SHORT_STARTING_ID + 1;
        shortRecords[2] = C.SHORT_STARTING_ID + 2;

        uint16[] memory shortOrderIds = new uint16[](3);
        shortOrderIds[0] = 0;
        shortOrderIds[1] = 0;
        shortOrderIds[2] = 0;
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.combineShorts(asset, shortRecords, shortOrderIds);
    }

    function test_ReentrancyDepositAsset() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.depositAsset(_dusd, 1 ether);
    }

    function test_ReentrancyWithdrawAsset() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.withdrawAsset(asset, DEFAULT_AMOUNT);
    }

    function test_ReentrancyUpdateYield() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.updateYield(vault);
    }

    function test_ReentrancyDistributeYield() public {
        address[] memory assets = new address[](1);
        assets[0] = asset;

        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.distributeYield(assets);
    }

    function test_ReentrancyClaimDittoMatchedReward() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.claimDittoMatchedReward(vault);
    }

    function test_ReentrancyWithdrawDittoReward() public {
        vm.expectRevert(Errors.ReentrantCall.selector);
        diamond.withdrawDittoReward(vault);
    }

    //View

    function test_ReentrancyViewGetAssetCollateralRatio() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getAssetCollateralRatio(asset);
    }

    function test_ReentrancyViewBids() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getBids(asset);
    }

    function test_ReentrancyViewAsks() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getAsks(asset);
    }

    function test_ReentrancyViewShorts() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getShorts(asset);
    }

    function test_ReentrancyViewGetShortIdAtOracle() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getShortIdAtOracle(asset);
    }

    function test_ReentrancyViewGetShortRecords() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getShortRecords(asset, sender);
    }

    function test_ReentrancyViewGetShortRecord() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getShortRecord(asset, sender, 1);
    }

    function test_ReentrancyViewgetShortRecordCount() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getShortRecordCount(asset, sender);
    }

    function test_ReentrancyViewGetDethBalance() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getDethBalance(vault, sender);
    }

    function test_ReentrancyViewGetAssetBalance() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getAssetBalance(asset, sender);
    }

    function test_ReentrancyViewGetUndistributedYield() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getUndistributedYield(vault);
    }

    function test_ReentrancyViewGetYield() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getYield(asset, sender);
    }

    function test_ReentrancyViewGetDittoMatchedReward() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getDittoMatchedReward(vault, sender);
    }

    function test_ReentrancyViewGetDittoReward() public {
        vm.expectRevert(Errors.ReentrantCallView.selector);
        diamond.getDittoReward(vault, sender);
    }
}
