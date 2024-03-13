// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U104, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {STypes, MTypes, SR} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {C} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {LibBytes} from "contracts/libraries/LibBytes.sol";

import {console} from "contracts/libraries/console.sol";

import {SSTORE2} from "solmate/utils/SSTORE2.sol";

contract RedemptionTest is OBFixture {
    using U256 for uint256;
    using U104 for uint104;
    using U88 for uint88;
    using U80 for uint80;

    uint88 DEF_REDEMPTION_AMOUNT = DEFAULT_AMOUNT * 3;
    uint88 partialRedemptionAmount = DEFAULT_AMOUNT * 2 + 2000 ether;
    uint88 INITIAL_ETH_AMOUNT = 100 ether;
    bool IS_PARTIAL = true;
    bool IS_FULL = false;

    function setUp() public override {
        super.setUp();

        //@dev give potential redeemer some ethEscrowed for the fee
        depositEth(receiver, INITIAL_ETH_AMOUNT);
        depositEth(extra, INITIAL_ETH_AMOUNT);
    }

    function makeShorts(bool singleShorter) public {
        if (singleShorter) {
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            fundLimitBidOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, sender);
            fundLimitBidOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, sender);
        } else {
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            fundLimitBidOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, extra);
            fundLimitBidOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, receiver);
            fundLimitShortOpt(DEFAULT_PRICE + 2, DEFAULT_AMOUNT, extra2);
        }
    }

    function makeProposalInputs(bool singleShorter) public view returns (MTypes.ProposalInput[] memory proposalInputs) {
        proposalInputs = new MTypes.ProposalInput[](3);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
        if (singleShorter) {
            proposalInputs[1] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 1, shortOrderId: 0});
            proposalInputs[2] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 2, shortOrderId: 0});
        } else {
            proposalInputs[1] = MTypes.ProposalInput({shorter: extra, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
            proposalInputs[2] = MTypes.ProposalInput({shorter: extra2, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
        }
    }

    function checkEscrowed(address redeemer, uint88 ercEscrowed) public {
        assertEq(diamond.getAssetUserStruct(asset, redeemer).ercEscrowed, ercEscrowed);
    }

    function getSlate(address redeemer) public view returns (MTypes.ProposalData[] memory) {
        address sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        uint8 slateLength = diamond.getAssetUserStruct(asset, redeemer).slateLength;
        return LibBytes.readProposalData(sstore2Pointer, slateLength);
    }

    function checkRedemptionSSTORE(
        address redeemer,
        MTypes.ProposalInput[] memory proposalInputs,
        bool isPartialFirst,
        bool isPartialLast
    ) public {
        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);

        for (uint8 i = 0; i < proposalInputs.length; i++) {
            assertEq(decodedProposalData[i].shorter, proposalInputs[i].shorter);
            assertEq(decodedProposalData[i].shortId, proposalInputs[i].shortId);

            STypes.ShortRecord memory currentShort =
                diamond.getShortRecord(asset, proposalInputs[i].shorter, proposalInputs[i].shortId);

            if (i == 0 && isPartialFirst) {
                assertGt(currentShort.ercDebt, 0);
            } else if (i < proposalInputs.length - 1) {
                assertGt(decodedProposalData[i].ercDebtRedeemed, 0);
                assertEq(currentShort.ercDebt, 0);
                assertLe(decodedProposalData[i].CR, decodedProposalData[i + 1].CR);
            } else {
                uint256 lastIndex = proposalInputs.length - 1;
                if (isPartialLast) {
                    assertGt(decodedProposalData[lastIndex].ercDebtRedeemed, 0);
                    assertGt(currentShort.ercDebt, 0);
                } else {
                    assertGt(decodedProposalData[lastIndex].ercDebtRedeemed, 0);
                    assertEq(currentShort.ercDebt, 0);
                }
            }
        }
    }

    //Revert
    function test_revert_TooManyProposals() public {
        uint16 len = 256;
        assertEq(len - 1, type(uint8).max);
        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](len);

        for (uint8 i = 0; i < len - 2; i++) {
            proposalInputs[i] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + i, shortOrderId: 0});
        }
        //add in last two
        proposalInputs[len - 2] = MTypes.ProposalInput({shorter: extra, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});

        proposalInputs[len - 1] = MTypes.ProposalInput({shorter: extra, shortId: C.SHORT_STARTING_ID + 1, shortOrderId: 0});
        address redeemer = receiver;
        vm.prank(redeemer);
        vm.expectRevert(Errors.TooManyProposals.selector);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT, MAX_REDEMPTION_FEE);
    }

    function test_revert_RedemptionUnderMinShortErc() public {
        uint88 underMinShortErc = uint88(diamond.getMinShortErc(asset)) - 1;
        makeShorts({singleShorter: true});
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});
        address redeemer = receiver;
        _setETH(1000 ether);
        vm.prank(redeemer);
        vm.expectRevert(Errors.RedemptionUnderMinShortErc.selector);
        diamond.proposeRedemption(asset, proposalInputs, underMinShortErc, MAX_REDEMPTION_FEE);
    }

    function test_Revert_RedemptionUnderMinShortErc_ErcDebtZero() public {
        address redeemer = receiver;

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        _setETH(1000 ether);
        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](1);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});

        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT, MAX_REDEMPTION_FEE);

        depositUsd(extra, DEFAULT_AMOUNT);
        vm.prank(extra);
        vm.expectRevert(Errors.RedemptionUnderMinShortErc.selector);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT, MAX_REDEMPTION_FEE);
    }

    function test_Revert_RedemptionUnderMinShortErc_ShortIsClosed() public {
        address redeemer = receiver;

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);

        _setETH(1000 ether);
        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](1);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});

        vm.prank(redeemer);
        vm.expectRevert(Errors.RedemptionUnderMinShortErc.selector);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT, MAX_REDEMPTION_FEE);
    }

    function test_Revert_RedemptionUnderMinShortErc_ShorterIsRedeemer() public {
        address redeemer = sender;

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        _setETH(1000 ether);
        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](1);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});

        vm.prank(redeemer);
        vm.expectRevert(Errors.RedemptionUnderMinShortErc.selector);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT, MAX_REDEMPTION_FEE);
    }

    function test_Revert_RedemptionUnderMinShortErc_ErcDebtLowAfterProposal() public {
        address redeemer = receiver;

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        _setETH(1000 ether);
        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](1);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});

        uint88 amount = DEFAULT_AMOUNT - uint88(diamond.getMinShortErc(asset)) + 1;

        vm.prank(redeemer);
        vm.expectRevert(Errors.RedemptionUnderMinShortErc.selector);
        diamond.proposeRedemption(asset, proposalInputs, amount, MAX_REDEMPTION_FEE);
    }

    function test_revert_InsufficientERCEscrowed() public {
        makeShorts({singleShorter: true});
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});
        address redeemer = extra;
        _setETH(1000 ether);
        vm.prank(redeemer);
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);
    }

    function test_revert_ExistingProposedRedemptions() public {
        makeShorts({singleShorter: true});
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});
        address redeemer = receiver;
        _setETH(1000 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        //@dev try to flag again before getting rid of existing flags
        depositUsdAndPrank(redeemer, DEF_REDEMPTION_AMOUNT);
        vm.expectRevert(Errors.ExistingProposedRedemptions.selector);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);
    }

    function test_revert_RedemptionFee_InsufficientETHEscrowed() public {
        makeShorts({singleShorter: true});
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        _setETH(1000 ether);
        depositUsdAndPrank(extra2, DEFAULT_AMOUNT * 3);
        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);
    }

    // function test_revert_ProposalInputsNotSortedAfterPartial() public {
    //     test_proposeRedemption_SingleShorter_Partial();
    //     // Increase CR of C.SHORT_STARTING_ID + 2
    //     MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](1);
    //     proposalInputs[0] = MTypes.ProposalInput({
    //         shorter: sender,
    //         shortId: C.SHORT_STARTING_ID + 2,
    //         CR: 0,
    //         ercDebtRedeemed: 0,
    //         colRedeemed: 0
    //     });
    //     address redeemer = extra2;
    //     uint88 amount = DEFAULT_AMOUNT / 2;
    //     depositUsd(redeemer, amount);
    //     vm.prank(redeemer);
    //     diamond.proposeRedemption(asset, proposalInputs, amount, MAX_REDEMPTION_FEE);

    //     // Make one more SR for sender
    //     _setETH(4000 ether);
    //     fundLimitBidOpt(DEFAULT_PRICE + 3, DEFAULT_AMOUNT, receiver);
    //     fundLimitShortOpt(DEFAULT_PRICE + 3, DEFAULT_AMOUNT, sender);
    //     _setETH(1000 ether);

    //     proposalInputs = new MTypes.ProposalInput[](2);
    //     proposalInputs[0] = MTypes.ProposalInput({
    //         shorter: sender,
    //         shortId: C.SHORT_STARTING_ID + 2,
    //         CR: 0,
    //         ercDebtRedeemed: 0,
    //         colRedeemed: 0
    //     });

    //     proposalInputs[1] = MTypes.ProposalInput({
    //         shorter: sender,
    //         shortId: C.SHORT_STARTING_ID + 3,
    //         CR: 0,
    //         ercDebtRedeemed: 0,
    //         colRedeemed: 0
    //     });

    //     redeemer = extra;
    //     amount = DEF_REDEMPTION_AMOUNT - partialRedemptionAmount + DEFAULT_AMOUNT / 2;
    //     depositUsd(redeemer, amount);

    //     vm.prank(redeemer);
    //     vm.expectRevert(Errors.ProposalInputsNotSorted.selector);
    //     diamond.proposeRedemption(asset, proposalInputs, amount, MAX_REDEMPTION_FEE);
    // }

    //Non revert
    function getColRedeemed(address asset, address redeemer) public view returns (uint88 colRedeemed) {
        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);

        for (uint256 i = 0; i < decodedProposalData.length; i++) {
            colRedeemed += decodedProposalData[i].ercDebtRedeemed.mulU88(diamond.getOraclePriceT(asset));
        }
    }

    //Global Collateral and debt
    function test_proposeRedemption_GlobalVars() public {
        uint88 totalPrice = (DEFAULT_PRICE * 3 + 3) * 2;
        uint88 redemptionCollateral = DEF_REDEMPTION_AMOUNT.mulU88(totalPrice);
        address redeemer = receiver;

        makeShorts({singleShorter: true});
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});
        assertEq(diamond.getAssetStruct(asset).ercDebt, DEF_REDEMPTION_AMOUNT);
        assertEq(diamond.getAssetStruct(asset).dethCollateral, redemptionCollateral);
        assertEq(diamond.getVaultStruct(vault).dethCollateral, redemptionCollateral);

        _setETH(1000 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        //@dev calculated based on oracle price
        uint88 colRedeemed = getColRedeemed(asset, redeemer);

        assertEq(diamond.getAssetStruct(asset).ercDebt, 0);
        assertEq(diamond.getAssetStruct(asset).dethCollateral, redemptionCollateral - colRedeemed);
        assertEq(diamond.getVaultStruct(vault).dethCollateral, redemptionCollateral - colRedeemed);
    }
    //Skipping SRs

    function test_skipRedemptions_AlreadyFullyRedeemed() public {
        makeShorts({singleShorter: true});

        //Fully propose/redeem C.SHORT_STARTING_ID + 1
        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](1);

        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 1, shortOrderId: 0});

        address redeemer = receiver;
        STypes.ShortRecord memory shortRecord = getShortRecord(proposalInputs[0].shorter, proposalInputs[0].shortId);

        _setETH(1000 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, shortRecord.ercDebt, MAX_REDEMPTION_FEE);
        address sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        assertTrue(sstore2Pointer != address(0));
        shortRecord = getShortRecord(proposalInputs[0].shorter, proposalInputs[0].shortId);
        assertEq(shortRecord.ercDebt, 0);

        //Make new proposal and include a fully proposed input
        proposalInputs = makeProposalInputs({singleShorter: true});

        redeemer = extra;
        depositUsdAndPrank(redeemer, DEF_REDEMPTION_AMOUNT);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);
        sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        assertFalse(sstore2Pointer == address(0));
        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);

        //@dev skip C.SHORT_STARTING_ID + 1
        assertEq(decodedProposalData.length, 2);
        assertEq(decodedProposalData[0].shortId, C.SHORT_STARTING_ID);
        assertEq(decodedProposalData[1].shortId, C.SHORT_STARTING_ID + 2);
    }

    function test_skipRedemptions_AlreadyFullyRedeemed_SkipAll() public {
        makeShorts({singleShorter: true});

        //Fully propose/redeem all shorts
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        address redeemer = receiver;

        _setETH(1000 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);
        address sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        assertTrue(sstore2Pointer != address(0));

        STypes.ShortRecord memory shortRecord;
        for (uint256 i = 0; i < proposalInputs.length; i++) {
            shortRecord = getShortRecord(proposalInputs[i].shorter, proposalInputs[i].shortId);

            assertEq(shortRecord.ercDebt, 0);
        }

        //Make new proposal and include the fully proposed inputs
        redeemer = extra;
        depositUsdAndPrank(redeemer, DEF_REDEMPTION_AMOUNT);
        vm.expectRevert(Errors.RedemptionUnderMinShortErc.selector);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);
    }

    function test_skipRedemptions_CannotRedeemYourself() public {
        makeShorts({singleShorter: true});

        //Fully propose/redeem C.SHORT_STARTING_ID + 1
        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](1);

        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 1, shortOrderId: 0});

        address redeemer = sender;
        STypes.ShortRecord memory shortRecord = getShortRecord(proposalInputs[0].shorter, proposalInputs[0].shortId);

        _setETH(1000 ether);
        depositUsdAndPrank(redeemer, DEF_REDEMPTION_AMOUNT);
        vm.expectRevert(Errors.RedemptionUnderMinShortErc.selector);
        diamond.proposeRedemption(asset, proposalInputs, shortRecord.ercDebt, MAX_REDEMPTION_FEE);
    }

    function test_SkipRedemptions_ProposalInputsNotSorted() public {
        makeShorts({singleShorter: true});
        assertEq(getShortRecordCount(sender), 3);

        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](3);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
        proposalInputs[1] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 2, shortOrderId: 0});
        proposalInputs[2] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 1, shortOrderId: 0});
        address redeemer = receiver;
        _setETH(1000 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);
        //@dev skipped 1 out of 3
        assertEq(decodedProposalData.length, 2);
    }

    function test_SkipRedemptions_AboveMaxRedemptionCR_skipAll() public {
        makeShorts({singleShorter: true});
        assertEq(getShortRecordCount(sender), 3);
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});
        address redeemer = receiver;

        vm.prank(redeemer);
        vm.expectRevert(Errors.RedemptionUnderMinShortErc.selector);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);
    }

    function test_SkipRedemptions_AboveMaxRedemptionCR_SkipSome() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT + 1, receiver);
        fundLimitShortOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT + 1, sender);
        //@dev will skip this one
        fundLimitBidOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT + 2, receiver);
        fundLimitShortOpt(DEFAULT_PRICE * 2, DEFAULT_AMOUNT + 2, sender);
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        _setETH(1000 ether);
        address redeemer = receiver;

        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);
        //@dev skipped 1 out of 3
        assertEq(decodedProposalData.length, 2);
        checkEscrowed({redeemer: redeemer, ercEscrowed: DEFAULT_AMOUNT + 2});
    }

    function test_SkipRedemptions_ProposalAmountRemainderTooSmall_SkipLast() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        //@dev will skip this one
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT + 1, sender);
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        _setETH(1000 ether);
        address redeemer = receiver;

        uint88 amount = DEFAULT_AMOUNT * 2 + 1;
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, amount, MAX_REDEMPTION_FEE);

        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);
        //@dev skipped 1 out of 3
        assertEq(decodedProposalData.length, 2);
        checkEscrowed({redeemer: redeemer, ercEscrowed: DEFAULT_AMOUNT + 1});
    }

    //proposeRedemption - general

    function test_proposeRedemption_shortOrderCancelled() public {
        // Fill shortRecord with > minShortErc, remaining shortOrder < minShortErc
        uint88 underMinShortErc = uint88(diamond.getMinShortErc(asset)) - 1;
        uint88 fillAmount = DEFAULT_AMOUNT - underMinShortErc;
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, fillAmount, receiver);
        assertEq(diamond.getShortOrder(asset, C.STARTING_ID).ercAmount, underMinShortErc);
        assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt, fillAmount);

        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](1);
        address redeemer = receiver;
        _setETH(1000 ether);

        // Invalid shortOrderId
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
        vm.prank(redeemer);
        vm.expectRevert(Errors.InvalidShortOrder.selector);
        diamond.proposeRedemption(asset, proposalInputs, fillAmount, MAX_REDEMPTION_FEE);
        // Valid shortOrderId
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: C.STARTING_ID});
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, fillAmount, MAX_REDEMPTION_FEE);

        // Verify cancelled shortOrder
        assertEq(diamond.getShortOrder(asset, C.HEAD).prevId, C.STARTING_ID);
    }

    function test_proposeRedemption_SingleShorter() public {
        makeShorts({singleShorter: true});
        assertEq(getShortRecordCount(sender), 3);

        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        address redeemer = receiver;

        checkEscrowed({redeemer: redeemer, ercEscrowed: DEF_REDEMPTION_AMOUNT});

        _setETH(1000 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        checkRedemptionSSTORE(redeemer, proposalInputs, IS_FULL, IS_FULL);

        //@dev locks up ercEscrowed to use for later redemption
        checkEscrowed({redeemer: redeemer, ercEscrowed: 0});
    }

    function test_proposeRedemption_SingleShorter_Partial() public {
        makeShorts({singleShorter: true});
        assertEq(getShortRecordCount(sender), 3);

        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        address redeemer = receiver;

        checkEscrowed({redeemer: redeemer, ercEscrowed: DEF_REDEMPTION_AMOUNT});

        _setETH(1000 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, partialRedemptionAmount, MAX_REDEMPTION_FEE);

        checkRedemptionSSTORE(redeemer, proposalInputs, IS_FULL, IS_PARTIAL);

        //@dev locks up ercEscrowed to use for later redemption
        checkEscrowed({redeemer: redeemer, ercEscrowed: DEF_REDEMPTION_AMOUNT - partialRedemptionAmount});
    }

    function test_proposeRedemption_SingleShorter_PartialThenFull() public {
        test_proposeRedemption_SingleShorter_Partial();

        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](1);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 2, shortOrderId: 0});

        address redeemer = extra;
        uint88 amount = DEF_REDEMPTION_AMOUNT - partialRedemptionAmount;
        depositUsd(redeemer, amount);

        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, amount, MAX_REDEMPTION_FEE);

        checkRedemptionSSTORE(redeemer, proposalInputs, IS_FULL, IS_FULL);

        checkEscrowed({redeemer: redeemer, ercEscrowed: 0});
    }

    function test_proposeRedemption_SingleShorter_PartialThenPartial() public {
        test_proposeRedemption_SingleShorter_Partial();

        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](1);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 2, shortOrderId: 0});

        address redeemer = extra;
        uint88 amount = uint88(diamond.getMinShortErc(asset));
        depositUsd(redeemer, amount);

        // @dev Artificially increase debt in sender SR to ensure it meets minShortErc reqs
        assertEq(diamond.getShortRecords(asset, sender)[0].ercDebt, 3000 ether);
        diamond.setErcDebtRate(asset, 1 ether); // Doubles from 3k ether to 6k ether of ercDebt

        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, amount, MAX_REDEMPTION_FEE);
        assertEq(diamond.getShortRecords(asset, sender)[0].ercDebt, 4000 ether); // 6000 - 2000

        checkRedemptionSSTORE(redeemer, proposalInputs, IS_PARTIAL, IS_PARTIAL);

        checkEscrowed({redeemer: redeemer, ercEscrowed: 0});
    }

    //TODO: This test doesn't make sense to me. It looks like it was partially redeemed and then partially redeemed again. Where was the full redemption?
    // function test_proposeRedemption_SingleShorter_PartialThenFullThenPartial() public {
    //     test_proposeRedemption_SingleShorter_Partial();
    //     // Make one more SR for sender
    //     _setETH(4000 ether);
    //     fundLimitBidOpt(DEFAULT_PRICE * 5 / 4, DEFAULT_AMOUNT, receiver); // @dev price to get correct sorting
    //     fundLimitShortOpt(DEFAULT_PRICE * 5 / 4, DEFAULT_AMOUNT, sender);
    //     _setETH(1000 ether);

    //     MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](2);
    //     proposalInputs[0] = MTypes.ProposalInput({
    //         shorter: sender,
    //         shortId: C.SHORT_STARTING_ID + 2,
    //         CR: 0,
    //         ercDebtRedeemed: 0,
    //         colRedeemed: 0
    //     });

    //     proposalInputs[1] = MTypes.ProposalInput({
    //         shorter: sender,
    //         shortId: C.SHORT_STARTING_ID + 3,
    //         CR: 0,
    //         ercDebtRedeemed: 0,
    //         colRedeemed: 0
    //     });

    //     address redeemer = extra;
    //     uint88 amount = DEF_REDEMPTION_AMOUNT - partialRedemptionAmount + DEFAULT_AMOUNT / 2;
    //     depositUsd(redeemer, amount);

    //     vm.prank(redeemer);
    //     diamond.proposeRedemption(asset, proposalInputs, amount, MAX_REDEMPTION_FEE);

    //     checkRedemptionSSTORE(redeemer, proposalInputs, IS_PARTIAL, IS_PARTIAL);

    //     checkEscrowed({redeemer: redeemer, ercEscrowed: 0});
    // }

    // function test_proposeRedemption_SingleShorter_PartialThenFullThenFull() public {
    //     test_proposeRedemption_SingleShorter_Partial();
    //     // Make one more SR for sender
    //     _setETH(4000 ether);
    //     fundLimitBidOpt(DEFAULT_PRICE * 5 / 4, DEFAULT_AMOUNT, receiver); // @dev price to get correct sorting
    //     fundLimitShortOpt(DEFAULT_PRICE * 5 / 4, DEFAULT_AMOUNT, sender);
    //     _setETH(1000 ether);

    //     MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](2);
    //     proposalInputs[0] = MTypes.ProposalInput({
    //         shorter: sender,
    //         shortId: C.SHORT_STARTING_ID + 2,
    //         CR: 0,
    //         ercDebtRedeemed: 0,
    //         colRedeemed: 0
    //     });

    //     proposalInputs[1] = MTypes.ProposalInput({
    //         shorter: sender,
    //         shortId: C.SHORT_STARTING_ID + 3,
    //         CR: 0,
    //         ercDebtRedeemed: 0,
    //         colRedeemed: 0
    //     });

    //     address redeemer = extra;
    //     uint88 amount = DEF_REDEMPTION_AMOUNT - partialRedemptionAmount + DEFAULT_AMOUNT;
    //     depositUsd(redeemer, amount);

    //     vm.prank(redeemer);
    //     diamond.proposeRedemption(asset, proposalInputs, amount, MAX_REDEMPTION_FEE);

    //     checkRedemptionSSTORE(redeemer, proposalInputs, IS_PARTIAL, IS_FULL);

    //     checkEscrowed({redeemer: redeemer, ercEscrowed: 0});
    // }

    function test_proposeRedemption_MultipleShorters() public {
        makeShorts({singleShorter: false});
        assertEq(getShortRecordCount(sender), 1);
        assertEq(getShortRecordCount(extra), 1);
        assertEq(getShortRecordCount(extra2), 1);

        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: false});

        address redeemer = receiver;

        checkEscrowed({redeemer: redeemer, ercEscrowed: DEF_REDEMPTION_AMOUNT});

        _setETH(1000 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        checkRedemptionSSTORE(redeemer, proposalInputs, IS_FULL, IS_FULL);

        //@dev locks up ercEscrowed to use for later redemption
        checkEscrowed({redeemer: redeemer, ercEscrowed: 0});
    }

    function test_proposeRedemption_MultipleShorters_Partial() public {
        makeShorts({singleShorter: false});
        assertEq(getShortRecordCount(sender), 1);
        assertEq(getShortRecordCount(extra), 1);
        assertEq(getShortRecordCount(extra2), 1);

        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: false});

        address redeemer = receiver;

        checkEscrowed({redeemer: redeemer, ercEscrowed: DEF_REDEMPTION_AMOUNT});

        _setETH(1000 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, partialRedemptionAmount, MAX_REDEMPTION_FEE);

        checkRedemptionSSTORE(redeemer, proposalInputs, IS_FULL, IS_PARTIAL);

        //@dev locks up ercEscrowed to use for later redemption
        checkEscrowed({redeemer: redeemer, ercEscrowed: DEF_REDEMPTION_AMOUNT - partialRedemptionAmount});
    }

    //proposeRedemption - timeToDispute

    //@dev 1.1 ether < CR <= 1.2 ether
    function test_proposeRedemption_TimeToDispute_1() public {
        makeShorts({singleShorter: true});
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        address redeemer = receiver;
        uint32 timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;

        _setETH(750 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);
        uint64 highestCR = decodedProposalData[decodedProposalData.length - 1].CR;
        assertGt(highestCR, 1.1 ether);
        assertLe(highestCR, 1.2 ether);
        timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        assertEq(timeToDispute, 301 seconds); //@dev time already skipped 1 second in set up
        assertGt(timeToDispute, 0 hours);
        assertLe(timeToDispute, 0.33 hours);

        //try to claim
        vm.startPrank(redeemer);

        skip(299 seconds);
        vm.expectRevert(Errors.TimeToDisputeHasNotElapsed.selector);
        diamond.claimRedemption(asset);
        skip(1 seconds);
        diamond.claimRedemption(asset);
    }

    //@dev 1.2 ether < CR <= 1.3 ether
    function test_proposeRedemption_TimeToDispute_2() public {
        makeShorts({singleShorter: true});
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        address redeemer = receiver;
        uint32 timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;

        _setETH(800 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);
        uint64 highestCR = decodedProposalData[decodedProposalData.length - 1].CR;
        assertGt(highestCR, 1.2 ether);
        assertLe(highestCR, 1.3 ether);
        timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        assertEq(timeToDispute, 1201 seconds); //@dev time already skipped 1 second in set up
        assertGt(timeToDispute, 0.33 hours);
        assertLe(timeToDispute, 0.75 hours);

        //try to claim
        vm.startPrank(redeemer);
        skip(1199 seconds);
        vm.expectRevert(Errors.TimeToDisputeHasNotElapsed.selector);
        diamond.claimRedemption(asset);
        skip(1 seconds);
        diamond.claimRedemption(asset);
    }

    //@dev 1.3 ether < CR <= 1.5 ether
    function test_proposeRedemption_TimeToDispute_3() public {
        makeShorts({singleShorter: true});
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        address redeemer = receiver;
        uint32 timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;

        _setETH(900 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);
        uint64 highestCR = decodedProposalData[decodedProposalData.length - 1].CR;
        assertGt(highestCR, 1.3 ether);
        assertLe(highestCR, 1.5 ether);
        timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        assertEq(timeToDispute, 3376 seconds); //@dev time already skipped 1 second in set up
        assertGt(timeToDispute, 0.75 hours);
        assertLe(timeToDispute, 1.5 hours);

        //try to claim
        vm.startPrank(redeemer);
        skip(3374 seconds);
        vm.expectRevert(Errors.TimeToDisputeHasNotElapsed.selector);
        diamond.claimRedemption(asset);
        skip(1 seconds);
        diamond.claimRedemption(asset);
    }

    //@dev 1.5 ether < CR <= 1.7 ether
    function test_proposeRedemption_TimeToDispute_4() public {
        makeShorts({singleShorter: true});
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        address redeemer = receiver;
        uint32 timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;

        _setETH(1100 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);
        uint64 highestCR = decodedProposalData[decodedProposalData.length - 1].CR;
        assertGt(highestCR, 1.5 ether);
        assertLe(highestCR, 1.7 ether);
        timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        assertEq(timeToDispute, 9451 seconds); //@dev time already skipped 1 second in set up
        assertGt(timeToDispute, 1.5 hours);
        assertLe(timeToDispute, 3 hours);

        //try to claim
        vm.startPrank(redeemer);
        skip(9449 seconds);
        vm.expectRevert(Errors.TimeToDisputeHasNotElapsed.selector);
        diamond.claimRedemption(asset);
        skip(1 seconds);
        diamond.claimRedemption(asset);
    }

    //@dev 1.7 ether < CR <= 2 ether
    function test_proposeRedemption_TimeToDispute_5() public {
        makeShorts({singleShorter: true});
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        address redeemer = receiver;
        uint32 timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;

        _setETH(1300 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);
        uint64 highestCR = decodedProposalData[decodedProposalData.length - 1].CR;
        assertGt(highestCR, 1.7 ether);
        assertLe(highestCR, 2 ether);
        timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        assertEq(timeToDispute, 19801 seconds); //@dev time already skipped 1 second in set up
        assertGt(timeToDispute, 3 hours);
        assertLe(timeToDispute, 6 hours);

        //try to claim
        vm.startPrank(redeemer);
        skip(19799 seconds);
        vm.expectRevert(Errors.TimeToDisputeHasNotElapsed.selector);
        diamond.claimRedemption(asset);
        skip(1 seconds);
        diamond.claimRedemption(asset);
    }

    //@dev CR under 1.1x can be immediately claimed on
    function test_proposeRedemption_TimeToDispute_LowCR() public {
        makeShorts({singleShorter: true});
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        address redeemer = receiver;
        uint32 timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;

        _setETH(200 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);
        uint64 highestCR = decodedProposalData[decodedProposalData.length - 1].CR;
        assertLe(highestCR, 1.1 ether);
        timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        assertEq(timeToDispute, 0);

        //@dev immediately claim
        vm.startPrank(redeemer);
        diamond.claimRedemption(asset);
    }

    //Move to another file
    //SSTORE2
    function test_WriteRead() public {
        bytes memory testBytes = abi.encode("this is a test");
        address pointer = SSTORE2.write(testBytes);
        assertEq(SSTORE2.read(pointer), testBytes);
    }

    function test_WriteReadStruct() public {
        MTypes.ProposalInput memory proposalInput =
            MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});

        bytes memory testBytes = abi.encode(proposalInput);

        address pointer = SSTORE2.write(testBytes);

        assertEq(SSTORE2.read(pointer), testBytes);
    }

    function test_WriteReadStructArrayDecode() public {
        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](3);

        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});

        proposalInputs[1] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 1, shortOrderId: 0});
        proposalInputs[2] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 2, shortOrderId: 0});

        bytes memory testBytes = abi.encode(proposalInputs);

        address sstore2Pointer = SSTORE2.write(testBytes);
        MTypes.ProposalInput[] memory decodedProposalInputs = abi.decode(SSTORE2.read(sstore2Pointer), (MTypes.ProposalInput[]));
        assertEq(SSTORE2.read(sstore2Pointer), testBytes);

        for (uint8 i = 0; i < proposalInputs.length; i++) {
            assertEq(decodedProposalInputs[i].shorter, proposalInputs[i].shorter);
            assertEq(decodedProposalInputs[i].shortId, proposalInputs[i].shortId);
        }
    }

    function test_ReadStartEndBytes() public {
        uint256[] memory testArray = new uint256[](3);
        testArray[0] = 732 ether;
        testArray[1] = 4 ether;
        testArray[2] = 5 ether;

        bytes memory testBytes = abi.encode(testArray);
        address pointer = SSTORE2.write(testBytes);
        // uint256 bytez = 256 / 8;
        // uint256 decodedData = abi.decode(SSTORE2.read(pointer, 0, bytez), (uint256));
        // uint256[] memory decodedData =
        //     abi.decode(SSTORE2.read(pointer, 0, bytez * 2), (uint256[]));
        // console.logBytes(SSTORE2.read(pointer, 0, bytez));
        console.logBytes(SSTORE2.read(pointer));
    }

    function test_CannotUpdateSRThatHasNoErcDebt() public {
        //full redeem
        test_proposeRedemption_SingleShorter();
        address shorter = sender;

        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, shorter);
        assertEq(shortRecords.length, 3);
        for (uint256 i = 0; i < shortRecords.length; i++) {
            assertEq(shortRecords[i].ercDebt, 0);
        }

        //@dev Preparing things for the tests ahead
        uint16[] memory shortHintArray = setShortHintArray();
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](1);
        batches[0] = MTypes.BatchLiquidation({shorter: shorter, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});

        //@dev Revert tests
        vm.expectRevert(Errors.InvalidShortId.selector);
        exitShortWallet(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, shorter);

        vm.expectRevert(Errors.InvalidShortId.selector);
        exitShortErcEscrowed(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, shorter);

        vm.prank(shorter);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.exitShort(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, shortHintArray, 0);

        depositEthAndPrank(sender, DEFAULT_AMOUNT);
        vm.expectRevert(Errors.InvalidShortId.selector);
        increaseCollateral(C.SHORT_STARTING_ID, 1 wei);

        vm.prank(shorter);
        vm.expectRevert(Errors.InvalidShortId.selector);
        decreaseCollateral(C.SHORT_STARTING_ID, 1 wei);

        vm.prank(shorter);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, 0);

        vm.prank(receiver);
        vm.expectRevert(Errors.InvalidShortId.selector);
        diamond.liquidate(asset, shorter, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);

        vm.prank(shorter);
        vm.expectRevert(Errors.InvalidShortId.selector);
        combineShorts({id1: C.SHORT_STARTING_ID, id2: C.SHORT_STARTING_ID + 1});

        //@dev increase debt > 0 to mint
        vm.startPrank(shorter);
        diamond.setErcDebt(asset, shorter, C.SHORT_STARTING_ID, 2000 ether);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, 0);
        diamond.setErcDebt(asset, shorter, C.SHORT_STARTING_ID, 0);
        vm.expectRevert(Errors.OriginalShortRecordRedeemed.selector);
        diamond.transferFrom(shorter, extra, 1);
        vm.stopPrank();
    }

    function test_proposeRedemption_Event() public {
        makeShorts({singleShorter: true});
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        address redeemer = receiver;

        _setETH(1000 ether);
        vm.expectEmit(_diamond);
        vm.prank(redeemer);
        emit Events.ProposeRedemption(asset, redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);
    }
    ///////////////////////////////////////////////////////////////////////////
    //Dispute Redemptions

    function makeProposalInputsForDispute(uint8 shortId1, uint8 shortId2)
        public
        view
        returns (MTypes.ProposalInput[] memory proposalInputs)
    {
        proposalInputs = new MTypes.ProposalInput[](2);

        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: shortId1, shortOrderId: 0});
        //@dev dispute this redemption
        proposalInputs[1] = MTypes.ProposalInput({shorter: sender, shortId: shortId2, shortOrderId: 0});
    }

    function setETHAndProposeShorts(address redeemer, MTypes.ProposalInput[] memory proposalInputs, uint88 redemptionAmount)
        public
    {
        _setETH(1000 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, redemptionAmount, MAX_REDEMPTION_FEE);
    }

    //@dev used to test the 1 hr buffer period
    function changeUpdateAtAndSkipTime(uint8 shortId) public {
        vm.prank(sender);
        decreaseCollateral(shortId, 1 wei);
        skip(1 hours);
    }

    function computePenalty(
        uint104 redemptionAmount,
        MTypes.ProposalData memory highestCRInput,
        STypes.ShortRecord memory correctSR
    ) public view returns (uint104 penaltyAmt) {
        uint256 callerFeePct = diamond.getAssetNormalizedStruct(asset).callerFeePct;
        uint256 correctCR = diamond.getCollateralRatio(asset, correctSR);
        uint256 penaltyPct = min(max(callerFeePct, (highestCRInput.CR - correctCR).div(highestCRInput.CR)), 0.33 ether);
        penaltyAmt = redemptionAmount.mulU104(penaltyPct);
    }

    function test_Revert_CannotDisputeYourself() public {
        address redeemer = receiver;
        makeShorts({singleShorter: true});

        address disputer = receiver;

        vm.prank(disputer);
        vm.expectRevert(Errors.CannotDisputeYourself.selector);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 1,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID
        });
    }

    function test_Revert_InvalidRedemption_NoProposal() public {
        address redeemer = receiver;
        makeShorts({singleShorter: true});

        address disputer = extra;

        vm.prank(disputer);
        vm.expectRevert(Errors.InvalidRedemption.selector);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 1,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID
        });
    }

    function test_Revert_InvalidRedemption_ClosedSR() public {
        makeShorts({singleShorter: true});
        address redeemer = receiver;
        address disputer = extra;
        uint88 _redemptionAmounts = DEFAULT_AMOUNT * 2;

        MTypes.ProposalInput[] memory proposalInputs =
            makeProposalInputsForDispute({shortId1: C.SHORT_STARTING_ID, shortId2: C.SHORT_STARTING_ID + 1});

        setETHAndProposeShorts({redeemer: redeemer, proposalInputs: proposalInputs, redemptionAmount: _redemptionAmounts});

        // Close C.SHORT_STARTING_ID + 2
        depositUsd(sender, DEFAULT_AMOUNT);
        vm.prank(sender);
        diamond.exitShortErcEscrowed(asset, C.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT, 0);
        assertSR(getShortRecord(sender, C.SHORT_STARTING_ID + 2).status, SR.Closed);

        vm.prank(disputer);
        vm.expectRevert(Errors.InvalidRedemption.selector);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 1,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID + 2
        });
    }

    function test_Revert_TimeToDisputeHasElapsed() public {
        uint88 _redemptionAmounts = DEFAULT_AMOUNT + DEFAULT_AMOUNT + 2;
        makeShorts({singleShorter: true});

        MTypes.ProposalInput[] memory proposalInputs =
            makeProposalInputsForDispute({shortId1: C.SHORT_STARTING_ID, shortId2: C.SHORT_STARTING_ID + 2});

        address redeemer = receiver;

        setETHAndProposeShorts({redeemer: redeemer, proposalInputs: proposalInputs, redemptionAmount: _redemptionAmounts});

        address disputer = extra;

        diamond.setErcDebt({asset: asset, shorter: sender, id: C.SHORT_STARTING_ID, value: 1 wei});
        uint32 timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        skip(timeToDispute);

        vm.prank(disputer);
        vm.expectRevert(Errors.TimeToDisputeHasElapsed.selector);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 1,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID + 2
        });
    }

    function test_Revert_InvalidRedemption_UnderMinShortErc() public {
        makeShorts({singleShorter: true});
        address redeemer = receiver;
        address disputer = extra;
        uint88 _redemptionAmounts = DEFAULT_AMOUNT * 2;

        MTypes.ProposalInput[] memory proposalInputs =
            makeProposalInputsForDispute({shortId1: C.SHORT_STARTING_ID, shortId2: C.SHORT_STARTING_ID + 1});

        // Create SR with coll < minShortErc
        uint88 underMinShortErc = uint88(diamond.getMinShortErc(asset)) - 1;
        fundLimitBidOpt(DEFAULT_PRICE + 3, underMinShortErc, receiver);
        fundLimitShortOpt(DEFAULT_PRICE + 3, DEFAULT_AMOUNT, sender);
        assertEq(getShortRecord(sender, C.SHORT_STARTING_ID + 3).ercDebt, underMinShortErc);

        setETHAndProposeShorts({redeemer: redeemer, proposalInputs: proposalInputs, redemptionAmount: _redemptionAmounts});

        vm.prank(disputer);
        vm.expectRevert(Errors.InvalidRedemption.selector);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 1,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID + 3
        });
    }

    function test_Revert_InvalidRedemption_ProposerOwnSR() public {
        makeShorts({singleShorter: true});
        address redeemer = receiver;
        address disputer = extra;
        uint88 _redemptionAmounts = DEFAULT_AMOUNT * 2;

        MTypes.ProposalInput[] memory proposalInputs =
            makeProposalInputsForDispute({shortId1: C.SHORT_STARTING_ID, shortId2: C.SHORT_STARTING_ID + 1});

        // Create SR from proposer
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(getShortRecord(receiver, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT);

        setETHAndProposeShorts({redeemer: redeemer, proposalInputs: proposalInputs, redemptionAmount: _redemptionAmounts});

        vm.prank(disputer);
        vm.expectRevert(Errors.InvalidRedemption.selector);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 1,
            disputeShorter: receiver,
            disputeShortId: C.SHORT_STARTING_ID
        });
    }

    function test_Revert_CannotDisputeWithRedeemerProposal_FirstProposal() public {
        uint88 _redemptionAmounts = DEFAULT_AMOUNT + DEFAULT_AMOUNT + 2;
        makeShorts({singleShorter: true});

        MTypes.ProposalInput[] memory proposalInputs =
            makeProposalInputsForDispute({shortId1: C.SHORT_STARTING_ID, shortId2: C.SHORT_STARTING_ID + 2});

        address redeemer = receiver;

        setETHAndProposeShorts({redeemer: redeemer, proposalInputs: proposalInputs, redemptionAmount: _redemptionAmounts});

        address disputer = extra;

        diamond.setErcDebt({asset: asset, shorter: sender, id: C.SHORT_STARTING_ID, value: 1 wei});

        vm.prank(disputer);
        vm.expectRevert(Errors.CannotDisputeWithRedeemerProposal.selector);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 1,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID
        });
    }

    function test_Revert_CannotDisputeWithRedeemerProposal_MiddleProposal() public {
        uint88 _redemptionAmounts = DEFAULT_AMOUNT * 3;
        makeShorts({singleShorter: true});

        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](3);

        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
        proposalInputs[1] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 1, shortOrderId: 0});
        proposalInputs[2] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 2, shortOrderId: 0});

        address redeemer = receiver;

        setETHAndProposeShorts({redeemer: redeemer, proposalInputs: proposalInputs, redemptionAmount: _redemptionAmounts});

        address disputer = extra;

        diamond.setErcDebt({asset: asset, shorter: sender, id: C.SHORT_STARTING_ID + 1, value: 1 wei});

        vm.prank(disputer);
        vm.expectRevert(Errors.CannotDisputeWithRedeemerProposal.selector);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 2,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID + 1
        });
    }

    function test_Revert_CannotDisputeWithRedeemerProposal_LastProposal() public {
        uint88 _redemptionAmounts = DEFAULT_AMOUNT + DEFAULT_AMOUNT + 2;
        makeShorts({singleShorter: true});

        MTypes.ProposalInput[] memory proposalInputs =
            makeProposalInputsForDispute({shortId1: C.SHORT_STARTING_ID, shortId2: C.SHORT_STARTING_ID + 2});

        address redeemer = receiver;

        setETHAndProposeShorts({redeemer: redeemer, proposalInputs: proposalInputs, redemptionAmount: _redemptionAmounts});

        address disputer = extra;

        diamond.setErcDebt({asset: asset, shorter: sender, id: C.SHORT_STARTING_ID + 2, value: 1 wei});

        vm.prank(disputer);
        vm.expectRevert(Errors.CannotDisputeWithRedeemerProposal.selector);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 1,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID + 2
        });
    }

    function test_Revert_InvalidRedemptionDispute_DisputeCRGtIncorrectCR() public {
        uint88 _redemptionAmounts = DEFAULT_AMOUNT + DEFAULT_AMOUNT + 2;
        makeShorts({singleShorter: true});

        MTypes.ProposalInput[] memory proposalInputs =
            makeProposalInputsForDispute({shortId1: C.SHORT_STARTING_ID, shortId2: C.SHORT_STARTING_ID + 1});

        address redeemer = receiver;

        changeUpdateAtAndSkipTime({shortId: C.SHORT_STARTING_ID + 1});

        setETHAndProposeShorts({redeemer: redeemer, proposalInputs: proposalInputs, redemptionAmount: _redemptionAmounts});

        address disputer = extra;
        vm.prank(disputer);
        //@dev CR for C.SHORT_STARTING_ID + 2 is not lower than CR for C.SHORT_STARTING_ID + 1
        vm.expectRevert(Errors.InvalidRedemptionDispute.selector);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 1,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID + 2
        });
    }

    function test_Revert_InvalidRedemptionDispute_UpdatedAtGtProposedAt() public {
        uint88 _redemptionAmounts = DEFAULT_AMOUNT + DEFAULT_AMOUNT + 2;
        makeShorts({singleShorter: true});

        MTypes.ProposalInput[] memory proposalInputs =
            makeProposalInputsForDispute({shortId1: C.SHORT_STARTING_ID, shortId2: C.SHORT_STARTING_ID + 2});

        address redeemer = receiver;

        setETHAndProposeShorts({redeemer: redeemer, proposalInputs: proposalInputs, redemptionAmount: _redemptionAmounts});

        address disputer = extra;
        vm.prank(disputer);
        //@dev the 1 hr buffer period has not elapsed yet
        vm.expectRevert(Errors.InvalidRedemptionDispute.selector);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 1,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID + 1
        });
    }

    function test_Revert_InvalidRedemptionDispute_UpdatedAtGtProposedAt_minShortErc() public {
        uint88 _redemptionAmounts = DEFAULT_AMOUNT * 3;
        makeShorts({singleShorter: true});

        // C.SHORT_STARTING_ID + 3
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        fundLimitBidOpt(DEFAULT_PRICE, minShortErc / 2, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, minShortErc, sender);
        assertEq(getShortRecord(sender, C.SHORT_STARTING_ID + 3).ercDebt, minShortErc / 2);

        // C.SHORT_STARTING_ID + 3 is skipped because not enough ercDebt
        skip(1 hours);
        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](3);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
        proposalInputs[1] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 2, shortOrderId: 0});
        proposalInputs[2] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 3, shortOrderId: 0});
        address redeemer = receiver;
        setETHAndProposeShorts({redeemer: redeemer, proposalInputs: proposalInputs, redemptionAmount: _redemptionAmounts});

        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);
        assertEq(decodedProposalData.length, 2);
        assertEq(decodedProposalData[0].shortId, C.SHORT_STARTING_ID);
        assertEq(decodedProposalData[1].shortId, C.SHORT_STARTING_ID + 2);

        // C.SHORT_STARTING_ID + 3 now valid for proposals
        _setETH(4000 ether);
        fundLimitBidOpt(DEFAULT_PRICE, minShortErc / 2, receiver);
        assertEq(getShortRecord(sender, C.SHORT_STARTING_ID + 3).ercDebt, minShortErc);
        _setETH(1000 ether);

        address disputer = extra;
        // Reverts because the updatedAt time is too recent
        vm.prank(disputer);
        vm.expectRevert(Errors.InvalidRedemptionDispute.selector);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 1,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID + 3
        });

        // Does not revert
        vm.prank(disputer);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 1,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID + 1
        });
    }

    function test_DisputeRedemption() public {
        uint88 _redemptionAmounts = DEFAULT_AMOUNT * 2;
        uint88 initialErcEscrowed = DEFAULT_AMOUNT;
        makeShorts({singleShorter: true});

        MTypes.ProposalInput[] memory proposalInputs =
            makeProposalInputsForDispute({shortId1: C.SHORT_STARTING_ID, shortId2: C.SHORT_STARTING_ID + 2});

        address redeemer = receiver;

        checkEscrowed({redeemer: redeemer, ercEscrowed: DEF_REDEMPTION_AMOUNT});

        changeUpdateAtAndSkipTime({shortId: C.SHORT_STARTING_ID + 2});

        setETHAndProposeShorts({redeemer: redeemer, proposalInputs: proposalInputs, redemptionAmount: _redemptionAmounts});

        checkRedemptionSSTORE(redeemer, proposalInputs, IS_FULL, IS_FULL);

        //pre-dispute check
        STypes.ShortRecord memory incorrectSR = diamond.getShortRecord(asset, sender, C.SHORT_STARTING_ID + 2);
        address sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        // assertTrue(sstore2Pointer != address(0));
        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);

        assertEq(decodedProposalData.length, 2);
        uint104 incorrectRedemptionAmount = DEFAULT_AMOUNT; //RedemptionAmount for C.SHORT_STARTING_ID + 2
        assertEq(decodedProposalData[0].shortId, C.SHORT_STARTING_ID);
        assertEq(decodedProposalData[1].shortId, C.SHORT_STARTING_ID + 2);
        assertEq(diamond.getAssetUserStruct(asset, redeemer).slateLength, 2);

        address disputer = extra;
        vm.prank(disputer);

        //@dev 96616666666666666670 = INITIAL_ETH_AMOUNT - redemption fee
        r.ethEscrowed = 96616666666666666670;
        r.ercEscrowed = initialErcEscrowed;
        assertStruct(redeemer, r);

        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 1,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID + 1
        });

        //post dispute check
        incorrectSR = diamond.getShortRecord(asset, sender, C.SHORT_STARTING_ID + 2);
        // penalty is updated
        STypes.ShortRecord memory correctSR = diamond.getShortRecord(asset, sender, C.SHORT_STARTING_ID + 1);
        uint104 penaltyAmt = computePenalty({
            redemptionAmount: incorrectRedemptionAmount,
            highestCRInput: decodedProposalData[decodedProposalData.length - 1],
            correctSR: correctSR
        });

        //@dev refund redeemer their redemptionAmount after penalty applied
        r.ercEscrowed = initialErcEscrowed + (incorrectRedemptionAmount - penaltyAmt);
        assertStruct(redeemer, r);

        sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        //@dev most important checks in the test
        assertFalse(sstore2Pointer == address(0));
        assertEq(diamond.getAssetUserStruct(asset, redeemer).slateLength, 1);
    }

    function test_DisputeRedemption_AllRedemptionsWereIncorrect() public {
        uint88 _redemptionAmounts = DEFAULT_AMOUNT * 2;
        uint88 initialErcEscrowed = DEFAULT_AMOUNT;

        makeShorts({singleShorter: true});

        MTypes.ProposalInput[] memory proposalInputs =
            makeProposalInputsForDispute({shortId1: C.SHORT_STARTING_ID + 1, shortId2: C.SHORT_STARTING_ID + 2});

        address redeemer = receiver;

        checkEscrowed({redeemer: redeemer, ercEscrowed: DEF_REDEMPTION_AMOUNT});

        changeUpdateAtAndSkipTime({shortId: C.SHORT_STARTING_ID + 1});

        setETHAndProposeShorts({redeemer: redeemer, proposalInputs: proposalInputs, redemptionAmount: _redemptionAmounts});

        checkRedemptionSSTORE(redeemer, proposalInputs, IS_FULL, IS_FULL);

        //pre-dispute check
        STypes.ShortRecord memory incorrectSR = diamond.getShortRecord(asset, sender, C.SHORT_STARTING_ID + 1);
        address sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        assertTrue(sstore2Pointer != address(0));
        MTypes.ProposalData[] memory decodedProposalData = getSlate(redeemer);

        assertEq(decodedProposalData.length, 2);
        assertGt(diamond.getAssetUserStruct(asset, redeemer).timeProposed, 0);
        assertEq(diamond.getAssetUserStruct(asset, redeemer).slateLength, 2);
        //@dev 96616666666666666670 = INITIAL_ETH_AMOUNT - redemption fee
        r.ethEscrowed = 96616666666666666670;
        r.ercEscrowed = initialErcEscrowed;
        assertStruct(redeemer, r);

        address disputer = extra;
        vm.expectEmit(_diamond);
        vm.prank(disputer);
        emit Events.DisputeRedemptionAll(asset, redeemer);
        diamond.disputeRedemption({
            asset: asset,
            redeemer: redeemer,
            incorrectIndex: 0,
            disputeShorter: sender,
            disputeShortId: C.SHORT_STARTING_ID
        });

        //post dispute check
        incorrectSR = diamond.getShortRecord(asset, sender, C.SHORT_STARTING_ID + 2);
        //penalty is updated
        STypes.ShortRecord memory correctSR = diamond.getShortRecord(asset, sender, C.SHORT_STARTING_ID);
        uint104 penaltyAmt = computePenalty({
            redemptionAmount: _redemptionAmounts,
            highestCRInput: decodedProposalData[decodedProposalData.length - 1],
            correctSR: correctSR
        });

        //@dev refund redeemer their redemptionAmount after penalty applied
        r.ercEscrowed = initialErcEscrowed + (_redemptionAmounts - penaltyAmt);
        assertStruct(redeemer, r);

        //SStorePointer is updated
        //@dev checking SStorePointer is address(0) is MAIN check of this test
        sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        assertEq(sstore2Pointer, address(0));
        assertEq(diamond.getAssetUserStruct(asset, redeemer).slateLength, 2);
    }

    //Redeeming the SR

    //revert
    function test_Revert_ClaimRedemption_InvalidRedemption() public {
        address redeemer = receiver;

        vm.prank(redeemer);
        vm.expectRevert(Errors.InvalidRedemption.selector);
        diamond.claimRedemption(asset);
    }

    function test_Revert_TimeToDisputeHasNotElapsed() public {
        test_proposeRedemption_SingleShorter();

        address redeemer = receiver;

        vm.prank(redeemer);
        vm.expectRevert(Errors.TimeToDisputeHasNotElapsed.selector);
        diamond.claimRedemption(asset);
    }

    //non-revert
    function getColRedeemedAndShorterRefund(MTypes.ProposalData[] memory proposalData)
        public
        view
        returns (uint88 totalColRedeemed, uint88 shorterRefund)
    {
        MTypes.ProposalData memory proposal;
        STypes.ShortRecord memory shortRecord;

        for (uint256 i = 0; i < proposalData.length; i++) {
            proposal = proposalData[i];
            shortRecord = getShortRecord(proposal.shorter, proposal.shortId);
            if (shortRecord.ercDebt == 0 && shortRecord.status == SR.FullyFilled) {
                totalColRedeemed += proposal.colRedeemed;
                shorterRefund += shortRecord.collateral;
            }
        }
    }

    function test_claimRedemption_AllShortsDeleted() public {
        test_proposeRedemption_SingleShorter();

        address redeemer = receiver;
        address shorter = sender;
        address sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        uint8 slateLength = diamond.getAssetUserStruct(asset, redeemer).slateLength;

        MTypes.ProposalData[] memory decodedProposalData = LibBytes.readProposalData(sstore2Pointer, slateLength);

        (, uint88 shorterRefund) = getColRedeemedAndShorterRefund(decodedProposalData);
        uint32 timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        skip(timeToDispute);
        //check redeemer asset user before redemption
        assertGt(diamond.getAssetUserStruct(asset, redeemer).timeToDispute, 0);
        assertFalse(diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer == address(0));
        assertGt(diamond.getAssetUserStruct(asset, redeemer).oraclePrice, 0);
        vm.expectEmit(_diamond);
        vm.prank(redeemer);
        emit Events.ClaimRedemption(asset, redeemer);
        diamond.claimRedemption(asset);

        //check redeemer asset user after redemption;
        assertEq(diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer, address(0));

        //check redeemer and shorter ethEscrowed
        // INITIAL_ETH_AMOUNT + totalColRedeemed - redemptionFee = 107424999999999999997
        r.ethEscrowed = 107424999999999999997;
        r.ercEscrowed = 0;
        assertStruct(redeemer, r);

        s.ethEscrowed = shorterRefund;
        s.ercEscrowed = 0;
        assertStruct(shorter, s);

        // check SR's are deleted
        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, shorter);
        assertEq(shortRecords.length, 0);
    }

    function test_claimRedemption_SomeShortsDeleted() public {
        address redeemer = receiver;
        address shorter = sender;
        uint88 leftoverErc = 2000 ether;
        makeShorts({singleShorter: true});

        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});

        _setETH(1000 ether);
        vm.prank(redeemer);
        //@dev partially propose the last proposal
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT - leftoverErc, MAX_REDEMPTION_FEE);

        address sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        uint8 slateLength = diamond.getAssetUserStruct(asset, redeemer).slateLength;

        MTypes.ProposalData[] memory decodedProposalData = LibBytes.readProposalData(sstore2Pointer, slateLength);

        (, uint88 shorterRefund) = getColRedeemedAndShorterRefund(decodedProposalData);
        uint32 timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        skip(timeToDispute);
        //check redeemer asset user before redemption
        assertGt(diamond.getAssetUserStruct(asset, redeemer).timeToDispute, 0);
        assertFalse(diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer == address(0));
        assertGt(diamond.getAssetUserStruct(asset, redeemer).oraclePrice, 0);

        vm.prank(redeemer);
        diamond.claimRedemption(asset);

        //check redeemer asset user after redemption;
        assertEq(diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer, address(0));

        //check redeemer and shorter ethEscrowed
        // INITIAL_ETH_AMOUNT + totalColRedeemed - redemptionFee = 107301666666666666668
        r.ethEscrowed = 107301666666666666668;
        r.ercEscrowed = leftoverErc;
        assertStruct(redeemer, r);

        s.ethEscrowed = shorterRefund;
        s.ercEscrowed = 0;
        assertStruct(shorter, s);

        //All SR's are deleted except for the last one bc of partial

        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, shorter);
        assertEq(shortRecords.length, 1);
        assertEq(shortRecords[0].ercDebt, leftoverErc);
        //exit the remaining short
        _setETH(4000 ether);
        fundLimitAskOpt(DEFAULT_PRICE, leftoverErc, extra);
        exitShort(C.SHORT_STARTING_ID + 2, leftoverErc, DEFAULT_PRICE, shorter);
        shortRecords = diamond.getShortRecords(asset, shorter);
        assertEq(shortRecords.length, 0);
    }

    //claimRemainingCollateral
    function test_revert_claimRemainingCollateral_InvalidRedemption() public {
        vm.expectRevert(Errors.InvalidRedemption.selector);
        diamond.claimRemainingCollateral(asset, receiver, 0, 0);
    }

    function test_revert_claimRemainingCollateral_CanOnlyClaimYourShort() public {
        test_proposeRedemption_SingleShorter();
        skip(1 days);
        vm.expectRevert(Errors.CanOnlyClaimYourShort.selector);
        diamond.claimRemainingCollateral(asset, receiver, 0, 0);
    }

    function test_revert_claimRemainingCollateral_TimeToDisputeHasNotElapsed() public {
        test_proposeRedemption_SingleShorter();
        address redeemer = receiver;
        address shorter = sender;
        vm.prank(shorter);
        vm.expectRevert(Errors.TimeToDisputeHasNotElapsed.selector);
        diamond.claimRemainingCollateral(asset, redeemer, 0, C.SHORT_STARTING_ID);
    }

    function test_claimRemainingCollateral() public {
        test_proposeRedemption_SingleShorter();

        address redeemer = receiver;
        address shorter = sender;
        address sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        uint8 slateLength = diamond.getAssetUserStruct(asset, redeemer).slateLength;

        MTypes.ProposalData[] memory decodedProposalData = LibBytes.readProposalData(sstore2Pointer, slateLength);

        (, uint88 shorterRefund) = getColRedeemedAndShorterRefund(decodedProposalData);

        uint32 timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        skip(timeToDispute);
        //check redeemer asset user before redemption
        assertFalse(diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer == address(0));

        //check redeemer ethEscrowed prior to claim
        r.ethEscrowed = 92425000000000000000; //the actual value of this number is irrelevant for this test
        r.ercEscrowed = 0;
        assertStruct(redeemer, r);

        vm.startPrank(shorter);
        diamond.claimRemainingCollateral(asset, redeemer, 0, C.SHORT_STARTING_ID);
        diamond.claimRemainingCollateral(asset, redeemer, 1, C.SHORT_STARTING_ID + 1);
        diamond.claimRemainingCollateral(asset, redeemer, 2, C.SHORT_STARTING_ID + 2);
        vm.stopPrank();

        //check redeemer asset user after redemption;
        assertFalse(diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer == address(0));

        //check redeemer and shorter ethEscrowed
        //The redeemer didn't claim yet, thus no change in ethEscrowed
        assertStruct(redeemer, r);

        s.ethEscrowed = shorterRefund;
        s.ercEscrowed = 0;
        assertStruct(shorter, s);

        // check SR's are deleted
        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, shorter);
        assertEq(shortRecords.length, 0);
    }

    //Redemption Fee
    function getTotalRedeemed(address redeemer) public view returns (uint88 totalColRedeemed, uint88 totalErcDebtRedeemed) {
        address sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        uint8 slateLength = diamond.getAssetUserStruct(asset, redeemer).slateLength;
        MTypes.ProposalData[] memory decodedProposalData = LibBytes.readProposalData(sstore2Pointer, slateLength);

        for (uint256 i = 0; i < decodedProposalData.length; i++) {
            totalColRedeemed += decodedProposalData[i].colRedeemed;
            totalErcDebtRedeemed += decodedProposalData[i].ercDebtRedeemed;
        }
    }

    function test_Revert_RedemptionFeeTooHigh() public {
        makeShorts({singleShorter: true});
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs({singleShorter: true});
        address redeemer = receiver;
        _setETH(1000 ether);
        vm.prank(redeemer);
        vm.expectRevert(Errors.RedemptionFeeTooHigh.selector);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, 1 wei);
    }

    //@dev this test is directional
    function test_RedemptionFee() public {
        address shorter = sender;
        address redeemer = receiver;
        assertEq(diamond.getAssetStruct(asset).ercDebt, 0);
        for (uint256 i = 0; i < 200; i++) {
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, redeemer);
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, shorter);
        }
        //@dev 1,000,000 dUSD
        assertEq(diamond.getAssetStruct(asset).ercDebt, DEFAULT_AMOUNT * 200);

        assertEq(diamond.getAssetStruct(asset).baseRate, 0);

        //Proposal 1
        _setETH(4000 ether); //prevent oracle from breaking
        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](3);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
        proposalInputs[1] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 1, shortOrderId: 0});
        proposalInputs[2] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 2, shortOrderId: 0});
        _setETH(1000 ether);
        skip(21600 seconds); //6 hrs
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        uint32 timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        skip(timeToDispute);
        (uint88 totalColRedeemed, uint88 totalErcDebtRedeemed) = getTotalRedeemed(redeemer);
        vm.prank(redeemer);
        diamond.claimRedemption(asset);
        assertApproxEqAbs(totalColRedeemed, 15 ether, MAX_DELTA_SMALL);
        assertApproxEqAbs(diamond.getAssetStruct(asset).baseRate, 0.0075 ether, MAX_DELTA_SMALL);

        console.log("-----------------");
        console.log("-----------------");
        //Proposal 2 - huge increase
        _setETH(4000 ether); //prevent oracle from breaking
        proposalInputs = new MTypes.ProposalInput[](10);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 3, shortOrderId: 0});
        proposalInputs[1] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 4, shortOrderId: 0});
        proposalInputs[2] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 5, shortOrderId: 0});
        proposalInputs[3] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 6, shortOrderId: 0});
        proposalInputs[4] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 7, shortOrderId: 0});
        proposalInputs[5] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 8, shortOrderId: 0});
        proposalInputs[6] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 9, shortOrderId: 0});
        proposalInputs[7] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 10, shortOrderId: 0});
        proposalInputs[8] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 11, shortOrderId: 0});
        proposalInputs[9] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 12, shortOrderId: 0});
        _setETH(1000 ether);
        skip(21600 seconds); //6 hrs
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT * 10, MAX_REDEMPTION_FEE);

        timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        skip(timeToDispute);
        (totalColRedeemed, totalErcDebtRedeemed) = getTotalRedeemed(redeemer);
        vm.prank(redeemer);
        diamond.claimRedemption(asset);
        assertApproxEqAbs(totalColRedeemed, 50 ether, 10 wei);
        assertApproxEqAbs(diamond.getAssetStruct(asset).baseRate, 0.028819420647548691 ether, MAX_DELTA_SMALL);

        console.log("-----------------");
        console.log("-----------------");

        //Proposal 3 - huge decrease
        _setETH(4000 ether); //prevent oracle from breaking
        proposalInputs = new MTypes.ProposalInput[](1);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 13, shortOrderId: 0});

        _setETH(1000 ether);
        skip(21600 seconds); //6 hrs
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT, MAX_REDEMPTION_FEE);

        timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        skip(timeToDispute);
        (totalColRedeemed, totalErcDebtRedeemed) = getTotalRedeemed(redeemer);
        vm.prank(redeemer);
        diamond.claimRedemption(asset);
        assertApproxEqAbs(totalColRedeemed, 4.999999999999999999 ether, MAX_DELTA_SMALL);
        assertApproxEqAbs(diamond.getAssetStruct(asset).baseRate, 0.008732139254791959 ether, MAX_DELTA_SMALL);

        console.log("-----------------");
        console.log("-----------------");

        //Proposal 4 - decrease fee close to zero
        _setETH(4000 ether); //prevent oracle from breaking
        proposalInputs = new MTypes.ProposalInput[](1);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 14, shortOrderId: 0});
        _setETH(1000 ether);
        skip(7 days);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT, MAX_REDEMPTION_FEE);

        timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        skip(timeToDispute);
        (totalColRedeemed, totalErcDebtRedeemed) = getTotalRedeemed(redeemer);
        vm.prank(redeemer);
        diamond.claimRedemption(asset);
        assertApproxEqAbs(totalColRedeemed, 4.999999999999999999 ether, MAX_DELTA_SMALL);
        //@dev close to zero
        assertApproxEqAbs(diamond.getAssetStruct(asset).baseRate, 0.002688205351340749 ether, MAX_DELTA_SMALL);
    }

    function test_RedemptionFee_12HrHalfLife() public {
        address shorter = sender;
        address redeemer = receiver;
        assertEq(diamond.getAssetStruct(asset).ercDebt, 0);
        for (uint256 i = 0; i < 200; i++) {
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, redeemer);
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, shorter);
        }

        //Proposal 1
        _setETH(4000 ether); //prevent oracle from breaking
        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](3);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
        proposalInputs[1] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 1, shortOrderId: 0});
        proposalInputs[2] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 2, shortOrderId: 0});
        _setETH(1000 ether);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);
        uint32 timeToDispute = diamond.getAssetUserStruct(asset, redeemer).timeToDispute;
        skip(timeToDispute);
        vm.prank(redeemer);
        diamond.claimRedemption(asset);
        uint256 initialBaseRate = 0.0075 ether;
        assertApproxEqAbs(diamond.getAssetStruct(asset).baseRate, initialBaseRate, MAX_DELTA_SMALL);

        //Make 2nd proposal 12 hours later
        _setETH(4000 ether); //prevent oracle from breaking
        proposalInputs = new MTypes.ProposalInput[](1);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 3, shortOrderId: 0});
        _setETH(1000 ether);
        skip(12 hours - timeToDispute); //12 total hrs since last proposal
        //propose a small amount (1 ether is the lowest value for minShortErc)
        vm.prank(owner);
        diamond.setMinShortErcT(asset, 0);
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, 1 wei, MAX_REDEMPTION_FEE);

        //@dev after 12 hrs, baseRate is roughly halved
        assertApproxEqAbs(diamond.getAssetStruct(asset).baseRate, 0.003750000000417061 ether, MAX_DELTA_SMALL);
        assertApproxEqAbs(initialBaseRate, 0.003750000000417061 ether, 0.5 ether);
    }

    function test_RedemptionFee_0SecondsPassedButLargeNextProposal() public {
        address shorter = sender;
        address redeemer = receiver;
        assertEq(diamond.getAssetStruct(asset).ercDebt, 0);
        for (uint256 i = 0; i < 200; i++) {
            fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, redeemer);
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, shorter);
        }

        //Proposal 1
        _setETH(4000 ether); //prevent oracle from breaking
        MTypes.ProposalInput[] memory proposalInputs = new MTypes.ProposalInput[](3);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
        proposalInputs[1] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 1, shortOrderId: 0});
        proposalInputs[2] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 2, shortOrderId: 0});
        _setETH(1000 ether);
        skip(21600 seconds); //6 hrs
        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEF_REDEMPTION_AMOUNT, MAX_REDEMPTION_FEE);

        uint256 baseRateInitial = diamond.getAssetStruct(asset).baseRate;
        assertApproxEqAbs(baseRateInitial, 0.0075 ether, MAX_DELTA_SMALL);

        //Make HUGE 2nd proposal immediately
        _setETH(4000 ether); //prevent oracle from breaking
        proposalInputs = new MTypes.ProposalInput[](10);
        proposalInputs[0] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 3, shortOrderId: 0});
        proposalInputs[1] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 4, shortOrderId: 0});
        proposalInputs[2] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 5, shortOrderId: 0});
        proposalInputs[3] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 6, shortOrderId: 0});
        proposalInputs[4] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 7, shortOrderId: 0});
        proposalInputs[5] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 8, shortOrderId: 0});
        proposalInputs[6] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 9, shortOrderId: 0});
        proposalInputs[7] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 10, shortOrderId: 0});
        proposalInputs[8] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 11, shortOrderId: 0});
        proposalInputs[9] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + 12, shortOrderId: 0});
        _setETH(1000 ether);
        depositUsdAndPrank(extra, DEFAULT_AMOUNT * 10); // Use different redeemer
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT * 10, MAX_REDEMPTION_FEE);

        //@dev ercRedeemed/ercDebtTotal where 3 was removed in the first redemption
        uint256 baseRateAdd = uint256(10 ether).div(200 ether - 3 ether).div(C.BETA);
        uint256 baseRateFinal = baseRateInitial + baseRateAdd;
        assertEq(diamond.getAssetStruct(asset).baseRate, baseRateFinal);
    }
}
