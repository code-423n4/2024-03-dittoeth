// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {F} from "contracts/libraries/DataTypes.sol";

import {U256, U128, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {C} from "contracts/libraries/Constants.sol";
import {LiquidationHelper} from "test/utils/LiquidationHelper.sol";
// import {console} from "contracts/libraries/console.sol";

contract LiquidationRevertTest is LiquidationHelper {
    using U256 for uint256;
    using U128 for uint128;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }

    ///Primary///
    function test_RevertCantLiquidateSelf() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether);
        vm.prank(sender);
        vm.expectRevert(Errors.CannotLiquidateSelf.selector);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
    }

    function test_RevertCRatioNotLowEnoughToLiquidate() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        vm.startPrank(receiver);
        _setETH(4000 ether); //reset eth
        vm.expectRevert(Errors.SufficientCollateral.selector);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
    }

    function test_RevertNoSellsAtAllToLiquidate() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether); //price in USD (min eth for liquidation ratio Formula: .0015P = 4 => P = 2666.67
        vm.expectRevert(Errors.NoSells.selector);
        vm.prank(receiver);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
    }

    function test_RevertNoSellsToLiquidateShortsUnderOracle() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        //@dev create short that can't be matched
        fundLimitShortOpt(DEFAULT_PRICE - 1 wei, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether); //price in USD (min eth for liquidation ratio Formula: .0015P = 4 => P = 2666.67
        vm.expectRevert(Errors.NoSells.selector);
        vm.prank(receiver);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
    }

    function test_RevertlowestSellPriceTooHigh() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether); //price in USD (min eth for liquidation ratio Formula: .0015P = 4 => P = 2666.67
        fundLimitAskOpt(uint80((diamond.getOracleAssetPrice(asset).mul(1.1 ether)) + 1 wei), DEFAULT_AMOUNT, receiver);
        vm.expectRevert(Errors.NoSells.selector);
        vm.prank(receiver);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
    }

    function test_RevertlowestSellPriceTooHighShort() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether); //price in USD (min eth for liquidation ratio Formula: .0015P = 4 => P = 2666.67
        fundLimitShortOpt(uint80((diamond.getOracleAssetPrice(asset).mul(1.1 ether)) + 1 wei), DEFAULT_AMOUNT, receiver);
        assertEq(diamond.getAssetStruct(asset).startingShortId, 101);
        vm.expectRevert(Errors.NoSells.selector);
        vm.prank(receiver);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
    }

    function test_RevertCantLiquidationTwice() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        depositEth(tapp, DEFAULT_TAPP);
        _setETH(2666 ether);

        vm.startPrank(receiver);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
    }

    function test_RevertBlackSwan() public {
        prepareAsk({askPrice: DEFAULT_PRICE, askAmount: DEFAULT_AMOUNT});
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        _setETH(730 ether); // c-ratio 1.095

        vm.prank(receiver);
        vm.expectRevert(Errors.CannotSocializeDebt.selector);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
    }

    function test_RevertTooManyHints() public {
        uint16[] memory shortHintArrayLong = new uint16[](11);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        _setETH(2666 ether);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        vm.prank(extra);
        vm.expectRevert(Errors.TooManyHints.selector);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayLong, 0);
    }

    function test_RevertOnlyAdminShutdownAdmin() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        _setETH(700 ether); // c-ratio 1.05
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.shutdownMarket(asset);
    }

    ///Market Shutdown///
    function shutdownMarket() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        _setETH(700 ether); // c-ratio 1.05
        vm.prank(owner);
        diamond.shutdownMarket(asset);
    }

    function test_ShutdownMarketEmpty() public {
        vm.expectRevert(stdError.divisionError);
        vm.prank(owner);
        diamond.shutdownMarket(asset);
    }

    function test_ShutdownMarketSufficientCollateral() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        vm.expectRevert(Errors.SufficientCollateral.selector);
        vm.prank(owner);
        diamond.shutdownMarket(asset);
    }

    function test_ShutdownMarketAlreadyFrozen() public {
        shutdownMarket();

        vm.expectRevert(Errors.AssetIsFrozen.selector);
        vm.prank(owner);
        diamond.shutdownMarket(asset);
    }

    function test_RedeemErcMarketUnfrozen() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        vm.expectRevert(Errors.AssetIsNotPermanentlyFrozen.selector);
        redeemErc(DEFAULT_AMOUNT, 0, receiver);
        vm.expectRevert(Errors.AssetIsNotPermanentlyFrozen.selector);
        redeemErc(0, DEFAULT_AMOUNT, receiver);
        vm.expectRevert(Errors.AssetIsNotPermanentlyFrozen.selector);
        redeemErc(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function test_RedeemErcEmptyWallet() public {
        shutdownMarket();

        vm.expectRevert(Errors.InsufficientWalletBalance.selector);
        redeemErc(DEFAULT_AMOUNT, 0, receiver);
    }

    function test_RedeemErcEmptyEscrow() public {
        shutdownMarket();

        vm.prank(receiver);
        diamond.withdrawAsset(asset, DEFAULT_AMOUNT);
        vm.expectRevert(stdError.arithmeticError);
        redeemErc(0, DEFAULT_AMOUNT, receiver);
    }
}
