// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Events} from "contracts/libraries/Events.sol";
import {MTypes, O} from "contracts/libraries/DataTypes.sol";
import {C, VAULT} from "contracts/libraries/Constants.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";
import {Vm} from "forge-std/Vm.sol";

import {console} from "contracts/libraries/console.sol";

contract EventsTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;

    uint16[] public shortHints = new uint16[](1);

    function setUp() public override {
        super.setUp();
        deal(sender, 500 ether);
        deal(receiver, 500 ether);

        vm.prank(sender);
        vm.expectEmit(_diamond);
        emit Events.DepositEth(_bridgeReth, sender, 500 ether);
        diamond.depositEth{value: 500 ether}(_bridgeReth);

        vm.prank(receiver);
        vm.expectEmit(_diamond);
        emit Events.DepositEth(_bridgeSteth, receiver, 500 ether);
        diamond.depositEth{value: 500 ether}(_bridgeSteth);
    }

    function test_Events() public {
        MTypes.OrderHint[] memory orderHints = new MTypes.OrderHint[](1);

        vm.prank(receiver);
        vm.expectEmit(_diamond);
        emit Events.CreateOrder(_dusd, receiver, O.LimitShort, 100, 10_000 ether);
        diamond.createLimitShort(_dusd, DEFAULT_PRICE, 10_000 ether, orderHints, shortHints, initialCR);

        vm.startPrank(sender);
        vm.expectEmit(_diamond);
        emit Events.CreateOrder(_dusd, sender, O.LimitBid, 101, 10000 ether);
        diamond.createBid(_dusd, DEFAULT_PRICE - 0.00001 ether, 10000 ether, false, orderHints, shortHints);
        vm.expectEmit(_diamond);
        emit Events.CancelOrder(_dusd, 101, O.LimitBid);
        diamond.cancelBid(_dusd, 101);

        vm.expectEmit(_diamond);
        emit Events.MatchOrder(_dusd, sender, O.LimitBid, 102, uint88(DEFAULT_PRICE).mulU88(10000 ether), uint88(10000 ether));

        diamond.createBid(_dusd, DEFAULT_PRICE, 10000 ether, false, orderHints, shortHints);

        diamond.withdrawAsset(_dusd, 10000 ether);

        diamond.depositAsset(_dusd, 10000 ether);

        vm.expectEmit(_diamond);
        emit Events.CreateOrder(_dusd, sender, O.LimitAsk, 102, 5_000 ether);
        diamond.createAsk(asset, DEFAULT_PRICE, 5_000 ether, C.LIMIT_ORDER, orderHints);
        vm.stopPrank();

        vm.startPrank(receiver);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, 0);
        diamond.setApprovalForAll(address(this), true);
        vm.expectEmit(_diamond);
        emit Events.CreateShortRecord(_dusd, sender, 2);
        diamond.safeTransferFrom(receiver, sender, 1, "");
        vm.stopPrank();

        vm.prank(sender);
        vm.expectEmit(_diamond);
        emit Events.Transfer(sender, extra, 1);
        diamond.safeTransferFrom(sender, extra, 1, "");

        vm.prank(extra);
        vm.expectEmit(_diamond);
        emit Events.DeleteShortRecord(asset, extra, C.SHORT_STARTING_ID);
        diamond.safeTransferFrom(extra, receiver, 1, "");

        vm.startPrank(receiver);
        vm.expectEmit(_diamond);
        emit Events.DecreaseCollateral(_dusd, receiver, 2, 2 ether);
        diamond.decreaseCollateral(_dusd, 2, 2 ether);

        deal(_steth, _bridgeSteth, 700 ether);
        skip(2 hours);
        _setETH(4000 ether);
        diamond.updateYield(VAULT.ONE);

        address[] memory assetArr = new address[](1);
        assetArr[0] = _dusd;
        vm.expectEmit(_diamond);
        emit Events.DistributeYield(VAULT.ONE, receiver, 179999999999999999989, 179999999999999999989);
        diamond.distributeYield(assetArr);

        diamond.withdrawDittoReward(VAULT.ONE);

        vm.expectEmit(_diamond);
        emit Events.IncreaseCollateral(_dusd, receiver, 2, 1 ether);
        diamond.increaseCollateral(_dusd, 2, 1 ether);

        diamond.createBid(_dusd, DEFAULT_PRICE, 1000 ether, false, orderHints, shortHints);

        vm.expectEmit(_diamond);
        emit Events.ExitShortErcEscrowed(_dusd, receiver, 2, 500 ether);
        diamond.exitShortErcEscrowed(_dusd, 2, 500 ether, 0);

        diamond.withdrawAsset(_dusd, 500 ether);

        vm.expectEmit(_diamond);
        emit Events.ExitShortWallet(_dusd, receiver, 2, 500 ether);
        diamond.exitShortWallet(_dusd, 2, 500 ether, 0);

        vm.expectEmit(_diamond);
        emit Events.ExitShort(_dusd, receiver, 2, 500 ether);
        diamond.exitShort(_dusd, 2, 500 ether, DEFAULT_PRICE, shortHints, 0);
        vm.stopPrank();

        _setETH(2200 ether);

        vm.startPrank(sender);
        skip(11 hours);
        _setETH(2200 ether);

        vm.expectEmit(_diamond);
        emit Events.Liquidate(_dusd, receiver, 2, sender, 3500 ether);
        diamond.liquidate(_dusd, receiver, 2, shortHints, 0);

        _setETH(500 ether);
        skip(30 minutes);

        MTypes.BatchLiquidation[] memory batchLiquidation = new MTypes.BatchLiquidation[](1);
        batchLiquidation[0] = MTypes.BatchLiquidation({shorter: receiver, shortId: 2, shortOrderId: 0});

        vm.expectEmit(_diamond);
        emit Events.LiquidateSecondary(_dusd, batchLiquidation, sender, false);
        diamond.liquidateSecondary(_dusd, batchLiquidation, 5000 ether, false);

        uint88 withdrawReth = diamond.getVaultUserStruct(vault, sender).bridgeCreditReth;
        uint256 withdrawRethFee = 0; // no fee with credit
        vm.expectEmit(_diamond);
        emit Events.Withdraw(_bridgeReth, sender, withdrawReth - withdrawRethFee, withdrawRethFee);
        diamond.withdraw(_bridgeReth, withdrawReth);

        uint88 withdrawSteth = diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed;
        diamond.setBridgeCredit(sender, 0, withdrawSteth); // Fake credit to avoid needing to use fork test to avoid revert
        uint256 withdrawStethFee = 0;
        vm.expectEmit(_diamond);
        emit Events.Withdraw(_bridgeSteth, sender, withdrawSteth - withdrawStethFee, withdrawStethFee);
        diamond.withdraw(_bridgeSteth, withdrawSteth);
    }

    function test_MatchOrderEvents() public {
        MTypes.OrderHint[] memory orderHints = new MTypes.OrderHint[](1);
        vm.prank(receiver);
        diamond.createBid(_dusd, DEFAULT_PRICE, 10000 ether, false, orderHints, shortHints);

        vm.startPrank(sender);
        vm.expectEmit(_diamond);
        emit Events.MatchOrder(_dusd, sender, O.LimitShort, 101, uint88(DEFAULT_PRICE).mulU88(10000 ether), uint88(10000 ether));
        diamond.createLimitShort(_dusd, DEFAULT_PRICE, 20_000 ether, orderHints, shortHints, initialCR);

        diamond.cancelShort(_dusd, 101);
        diamond.createBid(_dusd, DEFAULT_PRICE, 5000 ether, false, orderHints, shortHints);
        vm.stopPrank();

        vm.prank(receiver);
        vm.expectEmit(_diamond);
        emit Events.MatchOrder(_dusd, receiver, O.LimitAsk, 102, uint88(DEFAULT_PRICE).mulU88(5000 ether), uint88(5000 ether));
        diamond.createAsk(asset, DEFAULT_PRICE, 10_000 ether, C.LIMIT_ORDER, orderHints);
    }
}
