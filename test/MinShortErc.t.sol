// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {U256, U128, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {C} from "contracts/libraries/Constants.sol";
import {STypes, MTypes, SR} from "contracts/libraries/DataTypes.sol";
import {C, VAULT} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {LiquidationHelper} from "test/utils/LiquidationHelper.sol";
import {PrimaryScenarios} from "test/utils/TestTypes.sol";
import {SecondaryScenarios, SecondaryType} from "test/utils/TestTypes.sol";

import {console} from "contracts/libraries/console.sol";

contract MinShortErcTest is LiquidationHelper {
    using U256 for uint256;
    using U128 for uint128;
    using U88 for uint88;
    using U80 for uint80;

    bool SR_UNDER = true;
    bool SR_OVER = false;
    bool ORDER_UNDER = true;
    bool ORDER_OVER = false;

    function setUp() public override {
        super.setUp();
    }

    //CancelShort
    function test_CancelShort_PartialFill_SRUnderMinShortErc() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 underMinShortErc = minShortErc - 100 ether;
        uint88 receiverEth = DEFAULT_PRICE.mulU88(underMinShortErc);
        uint88 initialCollateral = receiverEth.mulU88(diamond.getAssetNormalizedStruct(asset).initialCR) + receiverEth;
        uint88 ethInShortOrder =
            DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT - underMinShortErc).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, underMinShortErc, receiver);

        //Pre-cancelShort check
        assertEq(getShorts().length, 1);
        assertEq(getShorts()[0].addr, sender);
        assertEq(getShorts()[0].ercAmount, DEFAULT_AMOUNT - underMinShortErc);

        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID);

        //check shortRecord
        assertEq(shortRecord.ercDebt, underMinShortErc);
        assertEq(shortRecord.collateral, initialCollateral);

        //check shorter's balance
        s.ercEscrowed = 0;
        s.ethEscrowed = 0;
        assertStruct(sender, s);

        //check system wide balance
        assertEq(diamond.getAssetStruct(asset).ercDebt, underMinShortErc);
        assertEq(diamond.getAssetStruct(asset).dethCollateral, initialCollateral);
        assertEq(diamond.getVaultStruct(vault).dethCollateral, initialCollateral);

        //Mimic rate change
        diamond.setErcDebtRate(asset, 1 ether);
        diamond.setDethYieldRate(vault, 1 ether);

        vm.prank(sender);
        cancelShort(C.STARTING_ID);

        //Post-cancelShort check
        assertEq(getShorts().length, 0);
        uint88 debtDiff = minShortErc - shortRecord.ercDebt;
        uint88 collateralIncreaseAmt = DEFAULT_PRICE.mulU88(debtDiff).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);
        uint256 debtRate = debtDiff.div(debtDiff + underMinShortErc).mul(1 ether);
        uint88 ethFilled = DEFAULT_PRICE.mulU88(debtDiff).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);
        uint256 yieldRate = ethFilled.div(initialCollateral + ethFilled).mul(1 ether);

        // @dev shortRecord's debt and collateral should increase
        shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID);
        //check shortRecord
        assertEq(shortRecord.ercDebt, minShortErc);
        assertEq(shortRecord.collateral, initialCollateral + collateralIncreaseAmt);
        assertEq(shortRecord.ercDebtRate, debtRate);
        assertEq(shortRecord.dethYieldRate, yieldRate);

        //check shorter's balance
        // @dev ercEsrowed increased by debtDiff via cancelShort() call within the liquidate function
        s.ercEscrowed = debtDiff;
        // @dev the shorter receives less eth back after cancel to increase SR's collateral
        s.ethEscrowed = ethInShortOrder - collateralIncreaseAmt;
        assertStruct(sender, s);

        //check system wide balance
        assertEq(diamond.getAssetStruct(asset).ercDebt, minShortErc);
        assertEq(diamond.getAssetStruct(asset).dethCollateral, initialCollateral + collateralIncreaseAmt);
        assertEq(diamond.getVaultStruct(vault).dethCollateral, initialCollateral + collateralIncreaseAmt);
    }

    function test_CancelShort_PartialFill_SRNotUnderMinShortErc() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 underMinShortErc = minShortErc - 100 ether;
        uint88 receiverEth = DEFAULT_PRICE.mulU88(underMinShortErc);
        uint88 initialShorterCollateral = receiverEth.mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);
        uint88 initialTotalCollateral = initialShorterCollateral + receiverEth;
        uint88 ethInShortOrder =
            DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT - underMinShortErc).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, underMinShortErc, receiver);

        //Pre-cancelShort check
        assertEq(getShorts().length, 1);
        assertEq(getShorts()[0].addr, sender);
        assertEq(getShorts()[0].ercAmount, DEFAULT_AMOUNT - underMinShortErc);

        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID);

        //check shortRecord
        assertEq(shortRecord.ercDebt, underMinShortErc);
        assertEq(shortRecord.collateral, initialTotalCollateral);

        //check shorter's balance
        s.ercEscrowed = 0;
        s.ethEscrowed = 0;
        assertStruct(sender, s);

        //check system wide balance
        assertEq(diamond.getAssetStruct(asset).ercDebt, underMinShortErc);
        assertEq(diamond.getAssetStruct(asset).dethCollateral, initialTotalCollateral);
        assertEq(diamond.getVaultStruct(vault).dethCollateral, initialTotalCollateral);

        //fill short order to make ercDebt == minShortErc
        fundLimitBidOpt(DEFAULT_PRICE, 100 ether, receiver);
        vm.prank(sender);
        cancelShort(C.STARTING_ID);

        //Post-cancelShort check
        assertEq(getShorts().length, 0);

        // @dev shortRecord's debt and collateral should increase
        shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID);
        assertEq(shortRecord.ercDebt, minShortErc);

        uint88 receiverEth2 = DEFAULT_PRICE.mulU88(100 ether);
        uint88 secondShorterCollateral = receiverEth2.mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);
        uint88 secondTotalCollateral = secondShorterCollateral + receiverEth2;

        //check shortRecord
        assertEq(shortRecord.ercDebt, minShortErc);
        assertEq(shortRecord.collateral, initialTotalCollateral + secondTotalCollateral);

        //check shorter's balance
        // @dev the shorter receives less eth back after cancel to increase SR's collateral
        s.ercEscrowed = 0;
        s.ethEscrowed = ethInShortOrder - secondShorterCollateral;
        assertStruct(sender, s);

        //check system wide balance
        assertEq(diamond.getAssetStruct(asset).ercDebt, minShortErc);
        assertEq(diamond.getAssetStruct(asset).dethCollateral, initialTotalCollateral + secondTotalCollateral);
        assertEq(diamond.getVaultStruct(vault).dethCollateral, initialTotalCollateral + secondTotalCollateral);
    }

    //Primary Liquidation
    function primaryLiquidationSetup(bool underMinShortErcSR, bool underMinShortErcSO)
        public
        returns (uint88 ercFilled, uint88 ercLeft)
    {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));

        if (underMinShortErcSR) {
            ercFilled = minShortErc - 100 ether;
        } else if (underMinShortErcSO) {
            ercFilled = DEFAULT_AMOUNT - minShortErc + 1 ether;
        } else {
            ercFilled = DEFAULT_AMOUNT - minShortErc;
        }
        ercLeft = DEFAULT_AMOUNT - ercFilled;

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, ercFilled, receiver);
        assertEq(getShorts().length, 1);
        assertEq(diamond.getShortRecordCount(asset, sender), 1);

        // @dev check balances before liquidation
        assertStruct(sender, s); // 0
        assertStruct(extra, e); // 0
    }

    function primaryLiquidationAsserts(
        bool underMinShortErcSR,
        bool underMinShortErcSO,
        uint88 ercFilled,
        uint88 ercLeft,
        LiquidationStruct memory m,
        uint88 ercDebt
    ) public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 debtDiff;
        uint88 collateralIncreaseAmt;
        uint88 ethInShortOrder;
        if (underMinShortErcSR) {
            debtDiff = minShortErc - ercDebt;
            collateralIncreaseAmt = DEFAULT_PRICE.mulU88(debtDiff).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);
            ethInShortOrder = DEFAULT_PRICE.mulU88(ercLeft - debtDiff).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);
        }
        if (underMinShortErcSO) {
            // @dev This only works since all of the SRUnderMinShortErc tests use ORDER_OVER
            ethInShortOrder = DEFAULT_PRICE.mulU88(ercLeft - debtDiff).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);
        }
        uint88 receiverEth = DEFAULT_PRICE.mulU88(ercFilled);
        uint88 initialCollateral = receiverEth.mulU88(diamond.getAssetNormalizedStruct(asset).initialCR) + receiverEth;

        // @dev ercEsrowed increased by debtDiff via cancelShort() call within the liquidate function
        s.ercEscrowed = debtDiff;
        // @dev shorter's ethEscrowed should be: remaining collateral + eth locked up in short order
        s.ethEscrowed =
            (initialCollateral + collateralIncreaseAmt) - m.ethFilled - m.gasFee - m.tappFee - m.callerFee + ethInShortOrder;
        assertStruct(sender, s);

        // @dev SR's collateral increased -> liquidator as if debt was 2000
        e.ercEscrowed = 0;
        e.ethEscrowed = m.gasFee + m.callerFee;
        assertStruct(extra, e);
    }

    function test_PrimaryLiquidation_SRUnderMinShortErc_FullLiquidate() public {
        (uint88 ercFilled, uint88 ercLeft) = primaryLiquidationSetup(SR_UNDER, ORDER_OVER);

        uint88 ercDebt = getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt;

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        LiquidationStruct memory m = simulateLiquidation(r, s, 2500 ether, extra, sender, C.STARTING_ID);

        assertEq(getShorts().length, 0); // short order IS cancelled
        primaryLiquidationAsserts(SR_UNDER, ORDER_OVER, ercFilled, ercLeft, m, ercDebt);
    }

    function test_PrimaryLiquidation_SRUnderMinShortErc_PartialLiquidateRevert() public {
        // @dev Revert is guaranteed when SRUnderMinShortErc and partial liquidation, regardless of short Order
        (uint88 ercFilled,) = primaryLiquidationSetup(SR_UNDER, ORDER_OVER);

        fundLimitAskOpt(DEFAULT_PRICE, ercFilled - 1 ether, receiver);
        _setETH(2500 ether);

        vm.prank(extra);
        vm.expectRevert(Errors.CannotLeaveDustAmount.selector);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, C.STARTING_ID);
    }

    function test_PrimaryLiquidation_OrderOverMinShortErc_FullLiquidate() public {
        (uint88 ercFilled, uint88 ercLeft) = primaryLiquidationSetup(SR_OVER, ORDER_OVER);

        uint88 ercDebt = getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt;

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        LiquidationStruct memory m = simulateLiquidation(r, s, 2500 ether, extra, sender, C.STARTING_ID);

        assertEq(getShorts().length, 1); // short order is NOT cancelled
        primaryLiquidationAsserts(SR_OVER, ORDER_OVER, ercFilled, ercLeft, m, ercDebt);
    }

    function test_PrimaryLiquidation_OrderUnderMinShortErc_FullLiquidate() public {
        (uint88 ercFilled, uint88 ercLeft) = primaryLiquidationSetup(SR_OVER, ORDER_UNDER);

        uint88 ercDebt = getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt;

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        LiquidationStruct memory m = simulateLiquidation(r, s, 2500 ether, extra, sender, C.STARTING_ID);

        assertEq(getShorts().length, 0); // short order IS cancelled
        primaryLiquidationAsserts(SR_OVER, ORDER_UNDER, ercFilled, ercLeft, m, ercDebt);
    }

    function test_PrimaryLiquidation_OrderOverMinShortErc_PartialLiquidate() public {
        primaryLiquidationSetup(SR_OVER, ORDER_OVER);

        getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt;

        // Update startingShortId
        skip(15 minutes);
        setETHChainlinkOnly(2500 ether);
        diamond.updateStartingShortId(asset, shortHintArrayStorage);

        uint88 amount = DEFAULT_AMOUNT - uint88(diamond.getMinShortErc(asset)) - 1 ether;
        fundLimitAskOpt(DEFAULT_PRICE, amount, receiver);
        LiquidationStruct memory m = simulateLiquidation(r, s, 2500 ether, extra, sender, C.STARTING_ID);

        assertEq(getShorts().length, 1); // short order is NOT cancelled
        assertStruct(sender, s); // partial liquidation means no collateral returned to sender
        e.ercEscrowed = 0;
        e.ethEscrowed = m.gasFee + m.callerFee;
        assertStruct(extra, e);
    }

    function test_PrimaryLiquidation_OrderUnderMinShortErc_PartialLiquidateRevert() public {
        (uint88 ercFilled,) = primaryLiquidationSetup(SR_OVER, ORDER_UNDER);

        fundLimitAskOpt(DEFAULT_PRICE, ercFilled - 1, receiver);
        _setETH(2500 ether);

        vm.prank(extra);
        vm.expectRevert(Errors.CannotLeaveDustAmount.selector);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, C.STARTING_ID);
    }

    function test_Revert_PrimaryLiquidation_InvalidShortOrder_NotId() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 underMinShortErc = minShortErc - 100 ether;
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, underMinShortErc, receiver);
        assertEq(getShorts().length, 1);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        _setETH(2500 ether);

        vm.expectRevert(Errors.InvalidShortOrder.selector);
        // @dev the correct shortOrderId should be C.STARTING_ID
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, C.STARTING_ID + 1);
    }

    function test_Revert_PrimaryLiquidation_InvalidShortOrder_NotShorter() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 underMinShortErc = minShortErc - 100 ether;
        fundLimitShortOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE + 1 wei, underMinShortErc, receiver);
        assertEq(getShorts().length, 1);

        // @dev create SR with the same SR id
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, underMinShortErc, extra);
        assertEq(getShorts().length, 2);
        assertEq(getBids().length, 0);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        _setETH(2500 ether);
        vm.expectRevert(Errors.InvalidShortOrder.selector);
        // @dev Try (and fail) to liquidate receiver, but cancel SENDER's short order
        diamond.liquidate(asset, receiver, C.SHORT_STARTING_ID, shortHintArrayStorage, C.STARTING_ID);
    }

    //Secondary Liquidation
    // @dev cancels the short order after liquidating a partially filled short
    function setUpSecondaryLiquidatingShortUnderMin(uint88 ercAmount, SecondaryType secondaryType)
        public
        returns (uint256 totalCollateral, uint256 liquidatorCollateral)
    {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        //partially fill the last short
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, ercAmount, receiver);

        //pre liquidation checks
        assertEq(getShorts().length, 1);
        assertEq(getShortRecordCount(sender), 3);

        // @dev check balances before liquidation
        s.ercEscrowed = 0;
        s.ethEscrowed = 0;
        assertStruct(sender, s);
        e.ercEscrowed = 0;
        e.ethEscrowed = 0;
        assertStruct(extra, e);

        _setETH(750 ether); //roughly get cratio between 1.1 and 1.5

        //create array of shorts
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](getShortRecordCount(sender));

        //create batch
        uint8 id;
        uint256 cRatio;
        for (uint8 i; i < getShortRecordCount(sender); i++) {
            id = C.SHORT_STARTING_ID + i;
            cRatio = diamond.getCollateralRatio(asset, getShortRecord(sender, id));
            assertTrue(cRatio > 1.1 ether && cRatio < 1.5 ether);

            uint16 shortOrderId = diamond.getShortOrderId(asset, sender, id);
            batches[i] = MTypes.BatchLiquidation({shorter: sender, shortId: id, shortOrderId: shortOrderId});
        }

        // @dev give exact amount to liquidate (no leftover amounts)
        if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
            depositUsd(extra, DEFAULT_AMOUNT * 2 + ercAmount);
            e.ercEscrowed = DEFAULT_AMOUNT * 2 + ercAmount;
            vm.prank(extra);
            diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 2 + ercAmount, ERC_ESCROWED);
        } else if (secondaryType == SecondaryType.LiquidateWallet) {
            vm.prank(_diamond);
            token.mint(extra, DEFAULT_AMOUNT * 2 + ercAmount);
            assertEq(token.balanceOf(extra), DEFAULT_AMOUNT * 2 + ercAmount);
            vm.prank(extra);
            diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 2 + ercAmount, WALLET);
        }

        for (uint8 i; i < 3; i++) {
            id = C.SHORT_STARTING_ID + i;
            totalCollateral += getShortRecord(sender, id).collateral;
            // @dev collateral earned by liquidator
            liquidatorCollateral += getShortRecord(sender, id).ercDebt.mul(testFacet.getOraclePriceT(asset));
        }

        return (totalCollateral, liquidatorCollateral);
    }

    function test_SecondaryLiquidation_IsUnderMin_ErcEscrowed() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 ercAmount = DEFAULT_AMOUNT - minShortErc + 100 ether;

        (uint256 totalCollateral, uint256 liquidatorCollateral) =
            setUpSecondaryLiquidatingShortUnderMin(ercAmount, SecondaryType.LiquidateErcEscrowed);

        // @dev corresponding short order canceled
        assertEq(getShorts().length, 0);
        assertEq(getShortRecordCount(sender), 0);

        uint88 ethInShortOrder =
            DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT - ercAmount).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);

        // @dev shorter's ethEscrowed should be: total collateral - collateral given to liquidator + eth locked up in short order
        s.ercEscrowed = 0;
        s.ethEscrowed = totalCollateral - liquidatorCollateral + ethInShortOrder;
        assertStruct(sender, s);

        e.ercEscrowed = 0;
        e.ethEscrowed = liquidatorCollateral;
        assertStruct(extra, e);

        //check system debt
        assertEq(diamond.getAssetStruct(asset).ercDebt, 0);
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, 0);
    }

    function test_SecondaryLiquidation_NotUnderMin_ErcEscrowed() public {
        uint88 ercAmount = 3000 ether;

        (uint256 totalCollateral, uint256 liquidatorCollateral) =
            setUpSecondaryLiquidatingShortUnderMin(ercAmount, SecondaryType.LiquidateErcEscrowed);

        // @dev corresponding short order not canceled
        assertEq(getShorts().length, 1);
        assertEq(getShortRecordCount(sender), 0);

        // @dev shorter's ethEscrowed should be: remaining collateral + eth locked up in short order
        s.ercEscrowed = 0;
        s.ethEscrowed = totalCollateral - liquidatorCollateral;
        assertStruct(sender, s);

        e.ercEscrowed = 0;
        e.ethEscrowed = liquidatorCollateral;
        assertStruct(extra, e);

        //check system debt
        assertEq(diamond.getAssetStruct(asset).ercDebt, 0);
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, 0);
    }

    function test_SecondaryLiquidation_IsUnderMin_Wallet() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 ercAmount = DEFAULT_AMOUNT - minShortErc + 100 ether;

        (uint256 totalCollateral, uint256 liquidatorCollateral) =
            setUpSecondaryLiquidatingShortUnderMin(ercAmount, SecondaryType.LiquidateWallet);

        // @dev corresponding short order canceled
        assertEq(getShorts().length, 0);
        assertEq(getShortRecordCount(sender), 0);

        uint88 ethInShortOrder =
            DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT - ercAmount).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);

        // @dev shorter's ethEscrowed should be: total collateral - collateral given to liquidator + eth locked up in short order
        s.ercEscrowed = 0;
        s.ethEscrowed = totalCollateral - liquidatorCollateral + ethInShortOrder;
        assertStruct(sender, s);

        e.ercEscrowed = 0;
        e.ethEscrowed = liquidatorCollateral;
        assertStruct(extra, e);

        //check system debt
        assertEq(diamond.getAssetStruct(asset).ercDebt, 0);
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, 0);
    }

    function test_SecondaryLiquidation_NotUnderMin_Wallet() public {
        uint88 ercAmount = 3000 ether;

        (uint256 totalCollateral, uint256 liquidatorCollateral) =
            setUpSecondaryLiquidatingShortUnderMin(ercAmount, SecondaryType.LiquidateWallet);

        // @dev corresponding short order canceled
        assertEq(getShorts().length, 1);
        assertEq(getShortRecordCount(sender), 0);

        // @dev shorter's ethEscrowed should be: remaining collateral + eth locked up in short order
        s.ercEscrowed = 0;
        s.ethEscrowed = totalCollateral - liquidatorCollateral;
        assertStruct(sender, s);

        e.ercEscrowed = 0;
        e.ethEscrowed = liquidatorCollateral;
        assertStruct(extra, e);

        //check system debt
        assertEq(diamond.getAssetStruct(asset).ercDebt, 0);
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, 0);
    }

    function test_SecondaryLiquidation_SRPartialFill_SkipSR_InvalidShorterAddress() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 ercAmount = DEFAULT_AMOUNT - minShortErc + 1 ether;

        // Create random extra SR
        fundLimitShortOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT, extra);
        fundLimitBidOpt(DEFAULT_PRICE * 2, ercAmount, receiver);

        //Partially fill sender SR
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, ercAmount, receiver);

        //pre liquidation checks
        assertEq(getShorts().length, 2);
        assertEq(getShortRecordCount(sender), 1);

        _setETH(750 ether); //roughly get cratio between 1.1 and 1.5

        //create array of shorts
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](getShortRecordCount(sender));
        // Intentionally pass incorrect shorter address
        batches[0] = MTypes.BatchLiquidation({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: C.STARTING_ID});

        vm.prank(extra);
        vm.expectRevert(Errors.SecondaryLiquidationNoValidShorts.selector);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 2 + ercAmount, ERC_ESCROWED);

        // @dev partial short was skipped and not cancelled
        assertEq(getShorts().length, 2);
        assertEq(getShortRecordCount(sender), 1);
    }

    function test_SecondaryLiquidation_SRPartialFill_SkipSR_InvalidShortOrderId() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 ercAmount = minShortErc - 100 ether;

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        //partially fill the last short
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, ercAmount, receiver);

        //pre liquidation checks
        assertEq(getShorts().length, 1);
        assertEq(getShortRecordCount(sender), 3);

        _setETH(750 ether); //roughly get cratio between 1.1 and 1.5

        //create array of shorts
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](getShortRecordCount(sender));

        batches[0] = MTypes.BatchLiquidation({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});

        batches[1] = MTypes.BatchLiquidation({shorter: sender, shortId: C.SHORT_STARTING_ID + 1, shortOrderId: 0});

        // @dev the correct shortOrderId is actually 100 here bc the 1st 2 shorts get full matched
        batches[2] = MTypes.BatchLiquidation({shorter: sender, shortId: C.SHORT_STARTING_ID + 2, shortOrderId: C.STARTING_ID + 2});

        depositUsd(extra, DEFAULT_AMOUNT * 2 + ercAmount);
        e.ercEscrowed = DEFAULT_AMOUNT * 2 + ercAmount;
        vm.prank(extra);
        diamond.liquidateSecondary(asset, batches, DEFAULT_AMOUNT * 2 + ercAmount, ERC_ESCROWED);

        // @dev partial short was skipped and not cancelled
        assertEq(getShorts().length, 1);
        assertEq(getShortRecordCount(sender), 1);
    }

    //Exit Short Primary
    function test_ExitShortPrimary_SRUnderMinShortErc() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 underMinShortErc = minShortErc - 100 ether;
        uint88 receiverEth = DEFAULT_PRICE.mulU88(underMinShortErc);
        uint88 initialCollateral = receiverEth.mulU88(diamond.getAssetNormalizedStruct(asset).initialCR) + receiverEth;

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, underMinShortErc, receiver);
        assertEq(getShorts().length, 1);

        STypes.Order memory shortOrder = getShorts()[0];
        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID);

        // @dev check balances before liquidation
        s.ercEscrowed = 0;
        s.ethEscrowed = 0;
        assertStruct(sender, s);

        // @dev exit the short
        fundLimitAskOpt(DEFAULT_PRICE, minShortErc, receiver);
        uint16[] memory shortHintArray = setShortHintArray();
        vm.prank(sender);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, underMinShortErc, DEFAULT_PRICE, shortHintArray, C.STARTING_ID);

        // @dev corresponding short order canceled
        assertEq(getShorts().length, 0);

        uint88 debtDiff = minShortErc - shortRecord.ercDebt;
        uint88 remainingCollateral =
            shortOrder.price.mulU88(shortOrder.ercAmount).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);
        uint88 ethFilled = DEFAULT_PRICE.mulU80(minShortErc);

        // @dev ercEsrowed increased by debtDiff via cancelShort() call within the liquidate function
        s.ercEscrowed = debtDiff;
        // @dev ethEscrowed should be the initial collateral + the collateral that wasn't filled in short order - the eth used to buyback
        s.ethEscrowed = initialCollateral + remainingCollateral - ethFilled;
        assertStruct(sender, s);
    }

    function test_ExitShortPrimary_ShortOrderUnderMinShortErc() public {
        // @dev DEFAULT_AMOUNT currently == 5000 ether. Change this if DEFAULT_AMOUNT or minShortErc changes
        uint88 aboveMinShortErc = 3001 ether;
        uint88 receiverEth = DEFAULT_PRICE.mulU88(aboveMinShortErc);
        uint88 initialCollateral = receiverEth.mulU88(diamond.getAssetNormalizedStruct(asset).initialCR) + receiverEth;

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, aboveMinShortErc, receiver);
        assertEq(getShorts().length, 1);

        STypes.Order memory shortOrder = getShorts()[0];

        // @dev check balances before liquidation
        s.ercEscrowed = 0;
        s.ethEscrowed = 0;
        assertStruct(sender, s);

        // @dev exit the short
        fundLimitAskOpt(DEFAULT_PRICE, aboveMinShortErc, receiver);
        uint16[] memory shortHintArray = setShortHintArray();
        vm.prank(sender);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, aboveMinShortErc, DEFAULT_PRICE, shortHintArray, C.STARTING_ID);

        // @dev corresponding short order canceled
        assertEq(getShorts().length, 0);

        uint88 remainingCollateral =
            shortOrder.price.mulU88(shortOrder.ercAmount).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);
        uint88 ethFilled = DEFAULT_PRICE.mulU80(aboveMinShortErc);

        // @dev ethEscrowed should be the initial collateral + the collateral that wasn't filled in short order - the eth used to buyback
        s.ercEscrowed = 0;
        s.ethEscrowed = initialCollateral + remainingCollateral - ethFilled;
        assertStruct(sender, s);
    }

    function test_Revert_ExitShortPrimary_SRUnderMinShortErc_CannotLeaveDustAmount() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 underMinShortErc = minShortErc - 100 ether;

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, underMinShortErc, receiver);
        assertEq(getShorts().length, 1);

        // @dev check balances before liquidation
        s.ercEscrowed = 0;
        s.ethEscrowed = 0;
        assertStruct(sender, s);

        // @dev exit the short
        fundLimitAskOpt(DEFAULT_PRICE, underMinShortErc, receiver);
        uint16[] memory shortHintArray = setShortHintArray();
        vm.prank(sender);
        vm.expectRevert(Errors.CannotLeaveDustAmount.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, underMinShortErc, DEFAULT_PRICE, shortHintArray, C.STARTING_ID);
    }

    //Exit Short Secondary
    function test_ExitShortErcEscrowed_FullExit_SRUnderMinShortErc() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 underMinShortErc = minShortErc - 100 ether;
        uint88 receiverEth = DEFAULT_PRICE.mulU88(underMinShortErc);
        uint88 initialCollateral = receiverEth.mulU88(diamond.getAssetNormalizedStruct(asset).initialCR) + receiverEth;

        fundLimitShortOpt(DEFAULT_PRICE, minShortErc, sender);
        fundLimitBidOpt(DEFAULT_PRICE, underMinShortErc, receiver);
        assertEq(getShorts().length, 1);

        STypes.Order memory shortOrder = getShorts()[0];

        depositUsd(sender, underMinShortErc);
        s.ercEscrowed = underMinShortErc;
        // @dev check balances before liquidation
        s.ercEscrowed = underMinShortErc;
        s.ethEscrowed = 0;
        assertStruct(sender, s);

        // @dev exit the short
        vm.prank(sender);
        diamond.exitShortErcEscrowed(asset, C.SHORT_STARTING_ID, underMinShortErc, C.STARTING_ID);

        // @dev corresponding short order canceled
        assertEq(getShorts().length, 0);

        uint88 remainingCollateral =
            shortOrder.price.mulU88(shortOrder.ercAmount).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);

        // @dev ethEscrowed should be the initial collateral + the collateral that wasn't filled in short order
        s.ercEscrowed = 0;
        s.ethEscrowed = initialCollateral + remainingCollateral;
        assertStruct(sender, s);
    }

    function test_ExitShortErcEscrowed_FullExit_ShortOrderUnderMinShortErc() public {
        // @dev DEFAULT_AMOUNT currently == 5000 ether. Change this if DEFAULT_AMOUNT or minShortErc changes
        uint88 aboveMinShortErc = 3001 ether;
        uint88 receiverEth = DEFAULT_PRICE.mulU88(aboveMinShortErc);
        uint88 initialCollateral = receiverEth.mulU88(diamond.getAssetNormalizedStruct(asset).initialCR) + receiverEth;

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, aboveMinShortErc, receiver);
        assertEq(getShorts().length, 1);

        STypes.Order memory shortOrder = getShorts()[0];

        depositUsd(sender, aboveMinShortErc);
        s.ercEscrowed = aboveMinShortErc;
        // @dev check balances before liquidation
        s.ercEscrowed = aboveMinShortErc;
        s.ethEscrowed = 0;
        assertStruct(sender, s);

        // @dev exit the short
        vm.prank(sender);
        diamond.exitShortErcEscrowed(asset, C.SHORT_STARTING_ID, aboveMinShortErc, C.STARTING_ID);

        // @dev corresponding short order canceled
        assertEq(getShorts().length, 0);

        uint88 remainingCollateral =
            shortOrder.price.mulU88(shortOrder.ercAmount).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);

        // @dev ethEscrowed should be the initial collateral + the collateral that wasn't filled in short order
        s.ercEscrowed = 0;
        s.ethEscrowed = initialCollateral + remainingCollateral;
        assertStruct(sender, s);
    }

    function test_Revert_ExitShortErcEscrowed_PartialExit_SRUnderMinShortErc_CannotLeaveDustAmount() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 ercAmount = minShortErc - 100 ether;

        fundLimitShortOpt(DEFAULT_PRICE, minShortErc, sender);
        fundLimitBidOpt(DEFAULT_PRICE, ercAmount, receiver);
        assertEq(getShorts().length, 1);

        uint88 buybackAmount = ercAmount / 2;
        depositUsd(sender, buybackAmount);
        // @dev check balances before liquidation
        s.ercEscrowed = buybackAmount;
        s.ethEscrowed = 0;
        assertStruct(sender, s);

        // @dev exit the short
        vm.prank(sender);
        vm.expectRevert(Errors.CannotLeaveDustAmount.selector);
        diamond.exitShortErcEscrowed(asset, C.SHORT_STARTING_ID, buybackAmount, C.STARTING_ID);
    }

    function test_ExitShortWallet_FullExit_SRUnderMinShortErc() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 underMinShortErc = minShortErc - 100 ether;
        uint88 receiverEth = DEFAULT_PRICE.mulU88(underMinShortErc);
        uint88 initialCollateral = receiverEth.mulU88(diamond.getAssetNormalizedStruct(asset).initialCR) + receiverEth;

        fundLimitShortOpt(DEFAULT_PRICE, minShortErc, sender);
        fundLimitBidOpt(DEFAULT_PRICE, underMinShortErc, receiver);
        assertEq(getShorts().length, 1);

        STypes.Order memory shortOrder = getShorts()[0];

        vm.prank(_diamond);
        token.mint(sender, underMinShortErc);
        assertEq(token.balanceOf(sender), underMinShortErc);
        vm.prank(sender);
        token.increaseAllowance(_diamond, underMinShortErc);

        // @dev check balances before liquidation
        s.ercEscrowed = 0;
        s.ethEscrowed = 0;
        assertStruct(sender, s);
        assertEq(token.balanceOf(sender), underMinShortErc);

        // @dev exit the short
        vm.prank(sender);
        diamond.exitShortWallet(asset, C.SHORT_STARTING_ID, underMinShortErc, C.STARTING_ID);

        // @dev corresponding short order canceled
        assertEq(getShorts().length, 0);

        uint88 remainingCollateral =
            shortOrder.price.mulU88(shortOrder.ercAmount).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);

        // @dev ethEscrowed should be the initial collateral + the collateral that wasn't filled in short order
        s.ercEscrowed = 0;
        s.ethEscrowed = initialCollateral + remainingCollateral;
        assertStruct(sender, s);
        assertEq(token.balanceOf(sender), 0);
    }

    function test_ExitShortWallet_FullExit_ShortOrderUnderMinShortErc() public {
        // uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        // @dev DEFAULT_AMOUNT currently == 5000 ether. Change this if DEFAULT_AMOUNT or minShortErc changes
        uint88 aboveMinShortErc = 3001 ether;
        uint88 receiverEth = DEFAULT_PRICE.mulU88(aboveMinShortErc);
        uint88 initialCollateral = receiverEth.mulU88(diamond.getAssetNormalizedStruct(asset).initialCR) + receiverEth;

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, aboveMinShortErc, receiver);
        assertEq(getShorts().length, 1);

        STypes.Order memory shortOrder = getShorts()[0];

        vm.prank(_diamond);
        token.mint(sender, aboveMinShortErc);
        assertEq(token.balanceOf(sender), aboveMinShortErc);
        vm.prank(sender);
        token.increaseAllowance(_diamond, aboveMinShortErc);

        // @dev check balances before liquidation
        s.ercEscrowed = 0;
        s.ethEscrowed = 0;
        assertStruct(sender, s);
        assertEq(token.balanceOf(sender), aboveMinShortErc);

        // @dev exit the short
        vm.prank(sender);
        diamond.exitShortWallet(asset, C.SHORT_STARTING_ID, aboveMinShortErc, C.STARTING_ID);

        // @dev corresponding short order canceled
        assertEq(getShorts().length, 0);

        uint88 remainingCollateral =
            shortOrder.price.mulU88(shortOrder.ercAmount).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);

        // @dev ethEscrowed should be the initial collateral + the collateral that wasn't filled in short order
        s.ercEscrowed = 0;
        s.ethEscrowed = initialCollateral + remainingCollateral;
        assertStruct(sender, s);
        assertEq(token.balanceOf(sender), 0);
    }

    function test_Revert_ExitShortWallet_PartialExit_SRUnderMinShortErc_CannotLeaveDustAmount() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 ercAmount = minShortErc - 100 ether;

        fundLimitShortOpt(DEFAULT_PRICE, minShortErc, sender);
        fundLimitBidOpt(DEFAULT_PRICE, ercAmount, receiver);
        assertEq(getShorts().length, 1);

        uint88 buybackAmount = ercAmount / 2;

        vm.prank(_diamond);
        token.mint(sender, buybackAmount);
        assertEq(token.balanceOf(sender), buybackAmount);
        vm.prank(sender);
        token.increaseAllowance(_diamond, buybackAmount);
        // @dev check balances before liquidation
        s.ercEscrowed = 0;
        s.ethEscrowed = 0;
        assertStruct(sender, s);

        // @dev exit the short
        vm.prank(sender);
        vm.expectRevert(Errors.CannotLeaveDustAmount.selector);
        diamond.exitShortWallet(asset, C.SHORT_STARTING_ID, buybackAmount, C.STARTING_ID);
    }

    //SRs with debt under minShortErc
    function test_Revert_ExitShort_InvalidShortOrder_NotId() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 underMinShortErc = minShortErc - 100 ether;
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, underMinShortErc, receiver);
        assertEq(getShorts().length, 1);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortOrder.selector);
        // @dev the correct shortOrderId should be C.STARTING_ID
        diamond.exitShort(asset, C.SHORT_STARTING_ID, underMinShortErc, DEFAULT_PRICE, shortHintArrayStorage, C.STARTING_ID + 1);
    }

    function test_Revert_ExitShort_InvalidShortOrder_NotShorter() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 underMinShortErc = minShortErc - 100 ether;
        fundLimitShortOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE + 1 wei, underMinShortErc, receiver);
        assertEq(getShorts().length, 1);

        // @dev create SR with the same SR id
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, underMinShortErc, extra);
        assertEq(getShorts().length, 2);
        assertEq(getBids().length, 0);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        vm.prank(receiver);
        vm.expectRevert(Errors.InvalidShortOrder.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, underMinShortErc, DEFAULT_PRICE, shortHintArrayStorage, C.STARTING_ID);
    }

    //CombineShorts
    function test_CombineShorts_PartialShorts() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT.mulU88(3 ether), sender);

        STypes.ShortRecord memory short = getShortRecord(sender, C.SHORT_STARTING_ID);
        assertTrue(short.status == SR.PartialFill);
        // Create SR to combine into to close original SR
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(getShortRecordCount(sender), 2);

        assertEq(getShorts().length, 1);
        uint8[] memory shortRecords = new uint8[](2);
        shortRecords[0] = C.SHORT_STARTING_ID + 1;
        shortRecords[1] = C.SHORT_STARTING_ID;

        uint16[] memory shortOrderIds = new uint16[](2);
        shortOrderIds[0] = 0;
        shortOrderIds[1] = 101;
        vm.prank(sender);
        diamond.combineShorts(asset, shortRecords, shortOrderIds);

        assertEq(getShorts().length, 0);
        assertEq(getShortRecordCount(sender), 1);
    }

    function test_Revert_CombineShorts_InvalidShortOrder() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT.mulU88(3 ether), sender);

        STypes.ShortRecord memory short = getShortRecord(sender, C.SHORT_STARTING_ID);
        assertTrue(short.status == SR.PartialFill);

        // Create SR to combine into to close original SR
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        assertEq(getShorts().length, 1);
        uint8[] memory shortRecords = new uint8[](2);
        shortRecords[0] = C.SHORT_STARTING_ID + 1;
        shortRecords[1] = C.SHORT_STARTING_ID;

        uint16[] memory shortOrderIds = new uint16[](2);
        shortOrderIds[0] = 0;
        shortOrderIds[1] = 0;
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortOrder.selector);
        diamond.combineShorts(asset, shortRecords, shortOrderIds);
    }

    function test_Revert_CombineShorts_InvalidNumberOfShortOrderIds() public {
        fundLimitBidOpt(1 ether, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(1 ether, DEFAULT_AMOUNT.mulU88(3 ether), sender);

        STypes.ShortRecord memory short = getShortRecord(sender, C.SHORT_STARTING_ID);
        assertTrue(short.status == SR.PartialFill);

        // Create SR to combine into to close original SR
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        assertEq(getShorts().length, 1);
        uint8[] memory shortRecords = new uint8[](2);
        shortRecords[0] = C.SHORT_STARTING_ID + 1;
        shortRecords[1] = C.SHORT_STARTING_ID;

        uint16[] memory shortOrderIds = new uint16[](3);
        shortOrderIds[0] = C.STARTING_ID;
        shortOrderIds[1] = C.STARTING_ID + 1;
        shortOrderIds[2] = 0;
        vm.prank(sender);
        vm.expectRevert(Errors.InvalidNumberOfShortOrderIds.selector);
        diamond.combineShorts(asset, shortRecords, shortOrderIds);
    }

    //NFT

    function test_Revert_MintNFT_InvalidShortOrder() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, receiver);

        vm.prank(sender);
        vm.expectRevert(Errors.InvalidShortOrder.selector);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, 0);
    }

    function test_MintNFT_PartialFillSR() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, receiver);

        vm.prank(sender);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, C.STARTING_ID);
        STypes.NFT memory nft = diamond.getNFT(1);
        assertEq(nft.owner, sender);
        assertEq(nft.shortRecordId, C.SHORT_STARTING_ID);
        assertEq(nft.shortOrderId, C.STARTING_ID);
        assertEq(diamond.getTokenId(), 2);
    }

    function test_MintNFT_NotPartialFillSR() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        vm.prank(sender);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, C.STARTING_ID);
        STypes.NFT memory nft = diamond.getNFT(1);
        assertEq(nft.owner, sender);
        assertEq(nft.shortRecordId, C.SHORT_STARTING_ID);
        assertEq(nft.shortOrderId, 0);
        assertEq(diamond.getTokenId(), 2);
    }

    function test_TransferFrom_PartialFillSR() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, receiver);
        vm.prank(sender);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, C.STARTING_ID);

        s.ercEscrowed = 0;
        s.ethEscrowed = 0;
        assertStruct(sender, s);
        assertEq(getShorts().length, 1);

        // @dev transfer short NFT
        vm.prank(sender);
        diamond.transferFrom(sender, extra, 1);

        // @dev sender's short order was cancelled prior to xfer
        uint88 ercAmount = DEFAULT_AMOUNT / 2;
        uint88 ethInShortOrder =
            DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT - ercAmount).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR);

        s.ercEscrowed = 0;
        s.ethEscrowed = ethInShortOrder;
        assertStruct(sender, s);
        assertEq(getShorts().length, 0);
    }
}
