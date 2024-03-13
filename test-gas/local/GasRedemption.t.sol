// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {STypes, MTypes} from "contracts/libraries/DataTypes.sol";
import {C} from "contracts/libraries/Constants.sol";
import {LibBytes} from "contracts/libraries/LibBytes.sol";
import {console} from "contracts/libraries/console.sol";

import {GasHelper} from "test-gas/GasHelper.sol";

contract GasRedemptionFixture is GasHelper {
    using U256 for uint256;
    using U88 for uint88;

    uint88 public INITIAL_ETH_AMOUNT = 100000 ether;

    function setUp() public virtual override {
        super.setUp();
        skip(1 days);
        ob.setETH(4000 ether);

        // create shorts
        for (uint8 i; i < 100; i++) {
            ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
        // @dev give potential redeemer some ethEscrowed for the fee
        ob.depositEth(receiver, INITIAL_ETH_AMOUNT);
        diamond.setBaseRate(asset, uint64(1 ether));
        diamond.setLastRedemptionTime(asset, uint32(diamond.getOffsetTime()));
    }

    function makeProposalInputs(uint8 numInputs) public view returns (MTypes.ProposalInput[] memory proposalInputs) {
        proposalInputs = new MTypes.ProposalInput[](numInputs);

        for (uint8 i = 0; i < numInputs; i++) {
            proposalInputs[i] = MTypes.ProposalInput({shorter: sender, shortId: C.SHORT_STARTING_ID + i, shortOrderId: 0});
        }
    }

    function gasRedemptionBeforeProposalAssert(address redeemer, address shorter) public {
        STypes.ShortRecord memory shortRecord = ob.getShortRecord(shorter, C.SHORT_STARTING_ID);

        assertGt(shortRecord.collateral, 0);
        assertGt(shortRecord.ercDebt, 0);
        assertEq(diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer, address(0));
    }

    function gasRedemptionProposalAssert(address redeemer, address shorter, uint8 numRedemptions) public {
        STypes.ShortRecord memory shortRecord;
        address sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        uint8 slateLength = diamond.getAssetUserStruct(asset, redeemer).slateLength;
        MTypes.ProposalData[] memory decodedProposalData = LibBytes.readProposalData(sstore2Pointer, slateLength);

        for (uint8 i = 0; i < numRedemptions; i++) {
            shortRecord = ob.getShortRecord(shorter, C.SHORT_STARTING_ID + i);
            assertGt(decodedProposalData[i].colRedeemed, 0);
            assertGt(decodedProposalData[i].ercDebtRedeemed, 0);
        }
        assertFalse(diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer == address(0));
    }

    function gasRedemptionBeforeDisputeAssert(address redeemer, uint8 numRedemptions) public {
        address sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        uint8 slateLength = diamond.getAssetUserStruct(asset, redeemer).slateLength;
        MTypes.ProposalData[] memory decodedProposalData = LibBytes.readProposalData(sstore2Pointer, slateLength);

        assertGt(decodedProposalData[0].ercDebtRedeemed, 0);
        assertGt(decodedProposalData[0].colRedeemed, 0);
        assertGt(decodedProposalData[decodedProposalData.length - 1].ercDebtRedeemed, 0);
        assertGt(decodedProposalData[decodedProposalData.length - 1].colRedeemed, 0);
        assertEq(decodedProposalData.length, numRedemptions);
    }

    function gasRedemptionDisputeAssert(address redeemer, bool isAllIncorrect, uint8 initialLength) public {
        address sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        uint8 slateLength = diamond.getAssetUserStruct(asset, redeemer).slateLength;
        if (isAllIncorrect) {
            assertEq(sstore2Pointer, address(0));
        } else {
            MTypes.ProposalData[] memory decodedProposalData = LibBytes.readProposalData(sstore2Pointer, slateLength);
            assertLt(decodedProposalData.length, initialLength);
        }
    }

    function gasRedemptionAfterRedeemingAssert(address redeemer) public {
        address sstore2Pointer = diamond.getAssetUserStruct(asset, redeemer).SSTORE2Pointer;
        assertEq(sstore2Pointer, address(0));
    }
}

contract GasProposalTest is GasRedemptionFixture {
    function setUp() public override {
        super.setUp();
        //lower eth price for redemption
        ob.setETH(1000 ether);
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
    }

    function test_GasProposingOneSR() public {
        address _asset = asset;
        address _redeemer = receiver;
        address _shorter = sender;
        uint8 _numRedemptions = 1;

        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs(1);
        gasRedemptionBeforeProposalAssert({redeemer: _redeemer, shorter: _shorter});

        vm.startPrank(_redeemer);
        startMeasuringGas("Redemption-ProposingOneSR");
        diamond.proposeRedemption(_asset, proposalInputs, DEFAULT_AMOUNT * _numRedemptions, MAX_REDEMPTION_FEE);
        stopMeasuringGas();

        gasRedemptionProposalAssert({redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});
    }

    function test_GasProposingThreeSR() public {
        address _asset = asset;
        address _redeemer = receiver;
        address _shorter = sender;
        uint8 _numRedemptions = 3;

        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs(3);
        gasRedemptionBeforeProposalAssert({redeemer: _redeemer, shorter: _shorter});

        vm.startPrank(_redeemer);
        startMeasuringGas("Redemption-ProposingThreeSR");
        diamond.proposeRedemption(_asset, proposalInputs, DEFAULT_AMOUNT * _numRedemptions, MAX_REDEMPTION_FEE);
        stopMeasuringGas();

        gasRedemptionProposalAssert({redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});
    }

    function test_GasProposingTenSR() public {
        address _asset = asset;
        address _redeemer = receiver;
        address _shorter = sender;
        uint8 _numRedemptions = 10;

        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs(10);
        gasRedemptionBeforeProposalAssert({redeemer: _redeemer, shorter: _shorter});

        vm.startPrank(_redeemer);
        startMeasuringGas("Redemption-ProposingTenSR");
        diamond.proposeRedemption(_asset, proposalInputs, DEFAULT_AMOUNT * _numRedemptions, MAX_REDEMPTION_FEE);
        stopMeasuringGas();

        gasRedemptionProposalAssert({redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});
    }

    function test_GasProposing100SR() public {
        address _asset = asset;
        address _redeemer = receiver;
        address _shorter = sender;
        uint8 _numRedemptions = 100;

        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs(100);
        gasRedemptionBeforeProposalAssert({redeemer: _redeemer, shorter: _shorter});

        vm.startPrank(_redeemer);
        startMeasuringGas("Redemption-Proposing100SR");
        diamond.proposeRedemption(_asset, proposalInputs, DEFAULT_AMOUNT * _numRedemptions, MAX_REDEMPTION_FEE);
        stopMeasuringGas();

        gasRedemptionProposalAssert({redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});
    }
}

contract GasDisputeTest is GasRedemptionFixture {
    function setUp() public override {
        super.setUp();

        //Make a SR with lower CR
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        // @dev skip time to account for the 1 hr buffer period
        vm.prank(sender);
        diamond.decreaseCollateral(asset, C.SHORT_STARTING_ID + 100, 1 wei);
        skip(1 hours);

        //lower eth price for redemption
        ob.setETH(1000 ether);
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
    }

    function preDisputeProposal(address asset, address redeemer, address shorter, uint8 numRedemptions) public {
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs(numRedemptions);
        gasRedemptionBeforeProposalAssert({redeemer: redeemer, shorter: shorter});

        vm.prank(redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT * numRedemptions, MAX_REDEMPTION_FEE);

        gasRedemptionProposalAssert({redeemer: redeemer, shorter: shorter, numRedemptions: numRedemptions});

        gasRedemptionBeforeDisputeAssert({redeemer: redeemer, numRedemptions: numRedemptions});
    }

    function test_GasDisputeOneSR() public {
        address _asset = asset;
        address _redeemer = receiver;
        address _shorter = sender;
        address _disputer = extra;
        uint8 _numRedemptions = 1;

        preDisputeProposal({asset: _asset, redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});

        vm.prank(_disputer);
        startMeasuringGas("Redemption-DisputeOneSR");
        diamond.disputeRedemption({
            asset: _asset,
            redeemer: _redeemer,
            incorrectIndex: 0,
            disputeShorter: _shorter,
            disputeShortId: C.SHORT_STARTING_ID + 100
        });
        stopMeasuringGas();
        gasRedemptionDisputeAssert({redeemer: _redeemer, isAllIncorrect: true, initialLength: _numRedemptions});
    }

    function test_GasDisputeThreeSR_AllIncorrect() public {
        address _asset = asset;
        address _redeemer = receiver;
        address _shorter = sender;
        address _disputer = extra;
        uint8 _numRedemptions = 3;

        preDisputeProposal({asset: _asset, redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});

        vm.prank(_disputer);
        startMeasuringGas("Redemption-DisputeThreeSR-AllIncorrect");
        diamond.disputeRedemption({
            asset: _asset,
            redeemer: _redeemer,
            incorrectIndex: 0,
            disputeShorter: _shorter,
            disputeShortId: C.SHORT_STARTING_ID + 100
        });
        stopMeasuringGas();
        gasRedemptionDisputeAssert({redeemer: _redeemer, isAllIncorrect: true, initialLength: _numRedemptions});
    }

    function test_GasDisputeThreeSR_LastIncorrect() public {
        address _asset = asset;
        address _redeemer = receiver;
        address _shorter = sender;
        address _disputer = extra;
        uint8 _numRedemptions = 3;

        preDisputeProposal({asset: _asset, redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});

        vm.prank(_disputer);
        startMeasuringGas("Redemption-DisputeThreeSR-LastIncorrect");
        diamond.disputeRedemption({
            asset: _asset,
            redeemer: _redeemer,
            incorrectIndex: 2,
            disputeShorter: _shorter,
            disputeShortId: C.SHORT_STARTING_ID + 100
        });
        stopMeasuringGas();
        gasRedemptionDisputeAssert({redeemer: _redeemer, isAllIncorrect: false, initialLength: _numRedemptions});
    }

    function test_GasDisputeTenSR_AllIncorrect() public {
        address _asset = asset;
        address _redeemer = receiver;
        address _shorter = sender;
        address _disputer = extra;
        uint8 _numRedemptions = 10;

        preDisputeProposal({asset: _asset, redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});

        vm.prank(_disputer);
        startMeasuringGas("Redemption-DisputeTenSR_AllIncorrect");
        diamond.disputeRedemption({
            asset: _asset,
            redeemer: _redeemer,
            incorrectIndex: 0,
            disputeShorter: _shorter,
            disputeShortId: C.SHORT_STARTING_ID + 100
        });
        stopMeasuringGas();
        gasRedemptionDisputeAssert({redeemer: _redeemer, isAllIncorrect: true, initialLength: _numRedemptions});
    }

    function test_GasDisputeTenSR_LastIncorrect() public {
        address _asset = asset;
        address _redeemer = receiver;
        address _shorter = sender;
        address _disputer = extra;
        uint8 _numRedemptions = 10;

        preDisputeProposal({asset: _asset, redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});

        vm.prank(_disputer);
        startMeasuringGas("Redemption-DisputeTenSR_LastIncorrect");
        diamond.disputeRedemption({
            asset: _asset,
            redeemer: _redeemer,
            incorrectIndex: 9,
            disputeShorter: _shorter,
            disputeShortId: C.SHORT_STARTING_ID + 100
        });
        stopMeasuringGas();
        gasRedemptionDisputeAssert({redeemer: _redeemer, isAllIncorrect: false, initialLength: _numRedemptions});
    }

    function test_GasDispute100SR_AllIncorrect() public {
        address _asset = asset;
        address _redeemer = receiver;
        address _shorter = sender;
        address _disputer = extra;
        uint8 _numRedemptions = 100;

        preDisputeProposal({asset: _asset, redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});

        vm.prank(_disputer);
        startMeasuringGas("Redemption-Dispute100SR-AllIncorrect");
        diamond.disputeRedemption({
            asset: _asset,
            redeemer: _redeemer,
            incorrectIndex: 0,
            disputeShorter: _shorter,
            disputeShortId: C.SHORT_STARTING_ID + 100
        });
        stopMeasuringGas();
        gasRedemptionDisputeAssert({redeemer: _redeemer, isAllIncorrect: true, initialLength: _numRedemptions});
    }

    function test_GasDispute100SR_LastIncorrect() public {
        address _asset = asset;
        address _redeemer = receiver;
        address _shorter = sender;
        address _disputer = extra;
        uint8 _numRedemptions = 100;

        preDisputeProposal({asset: _asset, redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});

        vm.prank(_disputer);
        startMeasuringGas("Redemption-Dispute100SR-LastIncorrect");
        diamond.disputeRedemption({
            asset: _asset,
            redeemer: _redeemer,
            incorrectIndex: 99,
            disputeShorter: _shorter,
            disputeShortId: C.SHORT_STARTING_ID + 100
        });
        stopMeasuringGas();
        gasRedemptionDisputeAssert({redeemer: _redeemer, isAllIncorrect: false, initialLength: _numRedemptions});
    }
}

contract GasClaimOneRedemptionTest is GasRedemptionFixture {
    function setUp() public override {
        super.setUp();
        address _redeemer = receiver;
        address _shorter = sender;
        uint8 _numRedemptions = 1;

        //lower eth price for redemption
        ob.setETH(1000 ether);
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs(_numRedemptions);
        gasRedemptionBeforeProposalAssert({redeemer: _redeemer, shorter: _shorter});
        vm.prank(_redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT * _numRedemptions, MAX_REDEMPTION_FEE);

        // @dev skip lots of time to permit redemption
        skip(1 days);

        gasRedemptionProposalAssert({redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});
    }

    function test_GasClaimOneSR() public {
        address _asset = asset;
        address _redeemer = receiver;

        vm.startPrank(_redeemer);
        startMeasuringGas("Redemption-ClaimOneRedemption");
        diamond.claimRedemption(_asset);
        stopMeasuringGas();

        gasRedemptionAfterRedeemingAssert(_redeemer);
    }
}

contract GasClaimThreeRedemptionTest is GasRedemptionFixture {
    function setUp() public override {
        super.setUp();
        address _redeemer = receiver;
        address _shorter = sender;
        uint8 _numRedemptions = 3;

        //lower eth price for redemption
        ob.setETH(1000 ether);
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs(_numRedemptions);
        gasRedemptionBeforeProposalAssert({redeemer: _redeemer, shorter: _shorter});
        vm.prank(_redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT * _numRedemptions, MAX_REDEMPTION_FEE);

        // @dev skip lots of time to permit redemption
        skip(1 days);

        gasRedemptionProposalAssert({redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});
    }

    function test_GasClaimThreeSR() public {
        address _asset = asset;
        address _redeemer = receiver;

        vm.startPrank(_redeemer);
        startMeasuringGas("Redemption-ClaimThreeRedemptions");
        diamond.claimRedemption(_asset);
        stopMeasuringGas();

        gasRedemptionAfterRedeemingAssert(_redeemer);
    }
}

contract GasClaimTenRedemptionTest is GasRedemptionFixture {
    function setUp() public override {
        super.setUp();
        address _redeemer = receiver;
        address _shorter = sender;
        uint8 _numRedemptions = 10;

        //lower eth price for redemption
        ob.setETH(1000 ether);
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs(_numRedemptions);
        gasRedemptionBeforeProposalAssert({redeemer: _redeemer, shorter: _shorter});
        vm.prank(_redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT * _numRedemptions, MAX_REDEMPTION_FEE);

        // @dev skip lots of time to permit redemption
        skip(1 days);

        gasRedemptionProposalAssert({redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});
    }

    function test_GasClaimTenSR() public {
        address _asset = asset;
        address _redeemer = receiver;

        vm.startPrank(_redeemer);
        startMeasuringGas("Redemption-ClaimTenRedemptions");
        diamond.claimRedemption(_asset);
        stopMeasuringGas();

        gasRedemptionAfterRedeemingAssert(_redeemer);
    }
}

contract GasClaim100RedemptionTest is GasRedemptionFixture {
    function setUp() public override {
        super.setUp();
        address _redeemer = receiver;
        address _shorter = sender;
        uint8 _numRedemptions = 100;

        //lower eth price for redemption
        ob.setETH(1000 ether);
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs(_numRedemptions);
        gasRedemptionBeforeProposalAssert({redeemer: _redeemer, shorter: _shorter});
        vm.prank(_redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT * _numRedemptions, MAX_REDEMPTION_FEE);

        // @dev skip lots of time to permit redemption
        skip(1 days);

        gasRedemptionProposalAssert({redeemer: _redeemer, shorter: _shorter, numRedemptions: _numRedemptions});
    }

    function test_GasClaim100SR() public {
        address _asset = asset;
        address _redeemer = receiver;

        vm.startPrank(_redeemer);
        startMeasuringGas("Redemption-Claim100Redemptions");
        diamond.claimRedemption(_asset);
        stopMeasuringGas();

        gasRedemptionAfterRedeemingAssert(_redeemer);
    }
}

contract GasClaimRemainingCollateralTest is GasRedemptionFixture {
    function setUp() public override {
        super.setUp();
        address _redeemer = receiver;
        address _shorter = sender;

        //lower eth price for redemption
        ob.setETH(1000 ether);
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
        MTypes.ProposalInput[] memory proposalInputs = makeProposalInputs(1);
        gasRedemptionBeforeProposalAssert({redeemer: _redeemer, shorter: _shorter});
        vm.prank(_redeemer);
        diamond.proposeRedemption(asset, proposalInputs, DEFAULT_AMOUNT, MAX_REDEMPTION_FEE);

        // @dev skip lots of time to permit redemption
        skip(1 days);
        gasRedemptionProposalAssert({redeemer: _redeemer, shorter: _shorter, numRedemptions: 1});

        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, _shorter);
        assertEq(shortRecords.length, 100);
    }

    function test_GasClaimRemainingCollateralOneSR() public {
        address _redeemer = receiver;
        address _asset = asset;
        address _shorter = sender;

        vm.startPrank(_shorter);
        startMeasuringGas("Redemption-ClaimRemainingCollateral-OneSR");
        diamond.claimRemainingCollateral(_asset, _redeemer, 0, C.SHORT_STARTING_ID);
        stopMeasuringGas();

        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, _shorter);
        assertEq(shortRecords.length, 99);
    }
}
