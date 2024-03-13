// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {STypes, MTypes, F, SR} from "contracts/libraries/DataTypes.sol";
import {C, VAULT} from "contracts/libraries/Constants.sol";
import {console} from "contracts/libraries/console.sol";

import {SecondaryType} from "test/utils/TestTypes.sol";
import {GasHelper} from "test-gas/GasHelper.sol";

contract GasLiquidationFixture is GasHelper {
    using U256 for uint256;
    using U88 for uint88;

    //Batch liquidations
    bool public constant WALLET = true;
    bool public constant ERC_ESCROWED = false;

    function setUp() public virtual override {
        super.setUp();

        ob.depositUsd(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(extra, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(extra, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(tapp, C.MIN_DEPOSIT);
        ob.depositEth(tapp, C.MIN_DEPOSIT);

        // create shorts
        for (uint8 i; i < 10; i++) {
            ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
    }

    function gasPrimaryLiquidationAsserts(address shorter, bool loseCollateral) public {
        uint256 vault = VAULT.ONE;
        STypes.ShortRecord memory short = ob.getShortRecord(shorter, C.SHORT_STARTING_ID);
        assertTrue(short.status == SR.Closed);
        assertGt(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, C.MIN_DEPOSIT);
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, 0);

        if (loseCollateral) {
            assertEq(diamond.getVaultUserStruct(vault, shorter).ethEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
        } else {
            assertGt(diamond.getVaultUserStruct(vault, shorter).ethEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
        }
    }

    function gasPrimaryLiquidationPartialAsserts(address shorter, bool loseCollateral) public {
        uint256 vault = VAULT.ONE;
        STypes.ShortRecord memory short = ob.getShortRecord(shorter, C.SHORT_STARTING_ID);
        assertGt(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, C.MIN_DEPOSIT);
        assertEq(diamond.getVaultUserStruct(vault, shorter).ethEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, 0);

        if (loseCollateral) {
            assertTrue(short.status == SR.Closed);
            short = ob.getShortRecord(tapp, C.SHORT_STARTING_ID);
            assertGt(short.collateral, 0);
        } else {
            assertTrue(short.status == SR.FullyFilled);
        }
    }

    function gasSecondaryLiquidationAsserts(
        address asset,
        address shorter,
        address caller,
        SecondaryType secondaryType,
        bool loseCollateral
    ) public {
        uint256 vault = VAULT.ONE;
        STypes.ShortRecord memory short = ob.getShortRecord(shorter, C.SHORT_STARTING_ID);
        assertTrue(short.status == SR.Closed);

        if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
            assertLt(diamond.getAssetUserStruct(asset, caller).ercEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
            assertEq(dusd.balanceOf(caller), DEFAULT_AMOUNT.mulU88(2 ether));
        } else if (secondaryType == SecondaryType.LiquidateWallet) {
            assertEq(diamond.getAssetUserStruct(asset, caller).ercEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
            assertLt(dusd.balanceOf(caller), DEFAULT_AMOUNT.mulU88(2 ether));
        }
        assertGt(diamond.getVaultUserStruct(vault, caller).ethEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));

        if (loseCollateral) {
            assertGt(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, C.MIN_DEPOSIT);
        }
    }

    function gasSecondaryLiquidationPartialAsserts(address asset, address shorter, address caller, SecondaryType secondaryType)
        public
    {
        uint256 vault = VAULT.ONE;
        STypes.ShortRecord memory short = ob.getShortRecord(shorter, C.SHORT_STARTING_ID);
        assertTrue(short.status == SR.FullyFilled);

        if (secondaryType == SecondaryType.LiquidateErcEscrowed) {
            assertLt(diamond.getAssetUserStruct(asset, caller).ercEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
            assertEq(dusd.balanceOf(caller), DEFAULT_AMOUNT / 2);
        } else if (secondaryType == SecondaryType.LiquidateWallet) {
            assertEq(diamond.getAssetUserStruct(asset, caller).ercEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
            assertLt(dusd.balanceOf(caller), DEFAULT_AMOUNT / 2);
        }
        assertGt(diamond.getVaultUserStruct(vault, caller).ethEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
    }
}

contract GasPrimaryLiquidationTest is GasLiquidationFixture {
    function setUp() public override {
        super.setUp();

        // create asks for exit/liquidation
        ob.fundLimitAskOpt(0.0004 ether, DEFAULT_AMOUNT, extra);

        //lower eth price for liquidate
        ob.setETH(2666 ether);
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
        ob.setETH(2500 ether);
    }

    function testGas_Liquidate() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-Primary");
        diamond.liquidate(_asset, _shorter, C.SHORT_STARTING_ID, shortHintArray, 0);
        stopMeasuringGas();
        gasPrimaryLiquidationAsserts({shorter: _shorter, loseCollateral: false});
    }

    function testGas_LiquidateUpdateOraclePrice() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        skip(15 minutes);
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-Primary-UpdateOraclePrice");
        diamond.liquidate(_asset, _shorter, C.SHORT_STARTING_ID, shortHintArray, 0);
        stopMeasuringGas();
        gasPrimaryLiquidationAsserts({shorter: _shorter, loseCollateral: false});
    }
}

contract GasPrimaryLiquidationPartialTest is GasLiquidationFixture {
    function setUp() public override {
        super.setUp();

        // create asks for exit/liquidation
        ob.fundLimitAskOpt(0.000375 ether, DEFAULT_AMOUNT / 2, extra);

        //lower eth price for liquidate
        ob.setETH(2666 ether);
        vm.prank(receiver);
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
    }

    function testGas_LiquidatePartial() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-Primary-Partial");
        diamond.liquidate(_asset, _shorter, C.SHORT_STARTING_ID, shortHintArray, 0);
        stopMeasuringGas();
        gasPrimaryLiquidationPartialAsserts({shorter: _shorter, loseCollateral: false});
    }
}

contract GasSecondaryLiquidationTest is GasLiquidationFixture {
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
        vm.prank(_diamond);
        dusd.mint(extra, DEFAULT_AMOUNT.mulU88(2 ether)); //for liquidateWallet
        //lower eth price for liquidate
        ob.setETH(999 ether);
    }

    function testGas_liquidateErcEscrowed() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](1);
        batches[0] = MTypes.BatchLiquidation({shorter: _shorter, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-ErcEscrowed");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT, ERC_ESCROWED);
        stopMeasuringGas();
        gasSecondaryLiquidationAsserts({
            asset: _asset,
            shorter: sender,
            caller: extra,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            loseCollateral: false
        });
    }

    function testGas_liquidateWallet() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](1);
        batches[0] = MTypes.BatchLiquidation({shorter: _shorter, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-Wallet");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT, WALLET);
        stopMeasuringGas();
        gasSecondaryLiquidationAsserts({
            asset: _asset,
            shorter: sender,
            caller: extra,
            secondaryType: SecondaryType.LiquidateWallet,
            loseCollateral: false
        });
    }
}

// contract GasSecondaryLiquidationPartialTest is GasLiquidationFixture {
//     function setUp() public override {
//         super.setUp();
//         ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
//         ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, tapp);
//         // Since the tapp already has short in position 2, combine with the newly created short 101
//         // This should never happen in practice since the tapp doesnt make shorts, just for ease of testing
//         vm.prank(tapp);
//         uint8[] memory ids = new uint8[](2);
//         ids[0] = C.SHORT_STARTING_ID;
//         ids[1] = C.SHORT_STARTING_ID + 1;

//         uint16[] memory shortOrderIds = new uint16[](2);
//         shortOrderIds[0] = 0;
//         shortOrderIds[1] = 0;
//         diamond.combineShorts(asset, ids, shortOrderIds);
//         // Lower eth price for liquidate
//         ob.setETH(750 ether);
//         // Set up liquidateWallet
//         vm.prank(_diamond);
//         dusd.mint(extra, DEFAULT_AMOUNT / 2);
//     }

//     function testGas_liquidateErcEscrowedPartial() public {
//         address _asset = asset;
//         address _shorter = tapp;
//         MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](1);
//         batches[0] = MTypes.BatchLiquidation({
//             shorter: _shorter,
//             shortId: C.SHORT_STARTING_ID,
//             shortOrderId: 0
//         });
//         vm.startPrank(extra);
//         startMeasuringGas("Liquidate-ErcEscrowed-Partial");
//         diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT / 2, ERC_ESCROWED);
//         stopMeasuringGas();
//         gasSecondaryLiquidationPartialAsserts({
//             asset: _asset,
//             shorter: _shorter,
//             caller: extra,
//             secondaryType: SecondaryType.LiquidateErcEscrowed
//         });
//     }

//     function testGas_liquidateWalletPartial() public {
//         address _asset = asset;
//         address _shorter = tapp;
//         MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](1);
//         batches[0] = MTypes.BatchLiquidation({
//             shorter: _shorter,
//             shortId: C.SHORT_STARTING_ID,
//             shortOrderId: 0
//         });
//         vm.startPrank(extra);
//         startMeasuringGas("Liquidate-Wallet-Partial");
//         diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT / 2, WALLET);
//         stopMeasuringGas();
//         gasSecondaryLiquidationPartialAsserts({
//             asset: _asset,
//             shorter: _shorter,
//             caller: extra,
//             secondaryType: SecondaryType.LiquidateWallet
//         });
//     }
// }

// contract GasSecondaryLiquidationPartialLowCratioTest is GasLiquidationFixture {
//     function setUp() public override {
//         super.setUp();
//         ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
//         ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, tapp);
//         // Since the tapp already has short in position 2, combine with the newly created short 101
//         // This should never happen in practice since the tapp doesnt make shorts, just for ease of testing
//         vm.prank(tapp);

//         uint8[] memory ids = new uint8[](2);
//         ids[0] = C.SHORT_STARTING_ID;
//         ids[1] = C.SHORT_STARTING_ID + 1;

//         uint16[] memory shortOrderIds = new uint16[](2);
//         shortOrderIds[0] = 0;
//         shortOrderIds[1] = 0;
//         diamond.combineShorts(asset, ids, shortOrderIds);
//         // Lower eth price for liquidate
//         ob.setETH(200 ether);
//         // Set up liquidateWallet
//         vm.prank(_diamond);
//         dusd.mint(extra, DEFAULT_AMOUNT / 2);
//     }

//     function testGas_liquidateErcEscrowedPartialLowCratio() public {
//         address _asset = asset;
//         address _shorter = tapp;
//         MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](1);
//         batches[0] = MTypes.BatchLiquidation({
//             shorter: _shorter,
//             shortId: C.SHORT_STARTING_ID,
//             shortOrderId: 0
//         });
//         vm.startPrank(extra);
//         startMeasuringGas("Liquidate-ErcEscrowed-Partial-LowCratio");
//         diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT / 2, ERC_ESCROWED);
//         stopMeasuringGas();
//         gasSecondaryLiquidationPartialAsserts({
//             asset: _asset,
//             shorter: _shorter,
//             caller: extra,
//             secondaryType: SecondaryType.LiquidateErcEscrowed
//         });
//     }

//     function testGas_liquidateWalletPartialLowCratio() public {
//         address _asset = asset;
//         address _shorter = tapp;
//         MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](1);
//         batches[0] = MTypes.BatchLiquidation({
//             shorter: _shorter,
//             shortId: C.SHORT_STARTING_ID,
//             shortOrderId: 0
//         });
//         vm.startPrank(extra);
//         startMeasuringGas("Liquidate-Wallet-Partial-LowCratio");
//         diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT / 2, WALLET);
//         stopMeasuringGas();
//         gasSecondaryLiquidationPartialAsserts({
//             asset: _asset,
//             shorter: _shorter,
//             caller: extra,
//             secondaryType: SecondaryType.LiquidateWallet
//         });
//     }
// }

contract GasPrimaryLiquidationTappTest is GasLiquidationFixture {
    function setUp() public override {
        super.setUp();

        // create asks for exit/liquidation
        ob.fundLimitAskOpt(0.0015 ether, DEFAULT_AMOUNT, extra);

        // mint eth for tapp
        ob.depositEth(tapp, FUNDED_TAPP);

        //lower eth price for liquidate
        ob.setETH(666.66 ether); //black swan
        vm.prank(receiver);
        skip(1); //so flaggedAt isn't zero
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
    }

    function testGas_LiquidateTapp() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-Primary-LoseCollateral");
        diamond.liquidate(_asset, _shorter, C.SHORT_STARTING_ID, shortHintArray, 0);
        stopMeasuringGas();
        gasPrimaryLiquidationAsserts({shorter: sender, loseCollateral: true});
    }
}

contract GasPrimaryLiquidationTappPartialTest is GasLiquidationFixture {
    function setUp() public override {
        super.setUp();

        // create asks for exit/liquidation
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);

        // mint eth for tapp
        ob.depositEth(tapp, FUNDED_TAPP);

        //lower eth price for liquidate
        ob.setETH(666.66 ether); //black swan
        vm.prank(receiver);
        skip(1); //so flaggedAt isn't zero
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
    }

    function testGas_LiquidateTappPartial() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-Primary-LoseCollateral-Partial");
        diamond.liquidate(_asset, _shorter, C.SHORT_STARTING_ID, shortHintArray, 0);
        stopMeasuringGas();
        gasPrimaryLiquidationPartialAsserts({shorter: sender, loseCollateral: true});
    }
}

contract GasSecondaryLiquidationTappTest is GasLiquidationFixture {
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        // mint usd for liquidateWallet
        vm.prank(_diamond);
        dusd.mint(extra, DEFAULT_AMOUNT.mulU88(2 ether));

        //lower eth price for liquidate
        ob.setETH(675 ether); //roughly get cratio between 1 and 1.1
    }

    function testGas_liquidateErcEscrowedPenaltyFee() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](1);
        batches[0] = MTypes.BatchLiquidation({shorter: _shorter, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-ErcEscrowed-TappFee");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT, ERC_ESCROWED);
        stopMeasuringGas();
        gasSecondaryLiquidationAsserts({
            asset: _asset,
            shorter: sender,
            caller: extra,
            secondaryType: SecondaryType.LiquidateErcEscrowed,
            loseCollateral: true
        });
    }

    function testGas_liquidateWalletPenaltyFee() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](1);
        batches[0] = MTypes.BatchLiquidation({shorter: _shorter, shortId: C.SHORT_STARTING_ID, shortOrderId: 0});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-Wallet-TappFee");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT, WALLET);
        stopMeasuringGas();
        gasSecondaryLiquidationAsserts({
            asset: _asset,
            shorter: sender,
            caller: extra,
            secondaryType: SecondaryType.LiquidateWallet,
            loseCollateral: true
        });
    }
}

contract GasLiquidationBlackSwan is GasLiquidationFixture {
    function setUp() public override {
        super.setUp();

        // create asks for exit/liquidation
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);

        //lower eth price for liquidate
        ob.setETH(666.66 ether); //black swan
        vm.prank(receiver);
        skip(1); //so flaggedAt isn't zero
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
    }

    function testGas_LiquidateBlackSwan() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        address _shorter = sender;
        vm.startPrank(receiver);
        startMeasuringGas("Liquidate-BlackSwan");
        diamond.liquidate(_asset, _shorter, C.SHORT_STARTING_ID, shortHintArray, 0);
        stopMeasuringGas();
        assertGt(diamond.getAssetStruct(asset).ercDebtRate, 0);
    }
}

contract GasSecondaryLiquidationBatch is GasLiquidationFixture {
    function setUp() public override {
        super.setUp();
        vm.prank(_diamond);
        dusd.mint(extra, DEFAULT_AMOUNT * 10); //for liquidateWallet
        assertEq(ob.getShortRecordCount(sender), 10);

        //lower eth price for liquidate
        ob.setETH(999 ether);
    }

    function testGas_liquidateWalletBatch() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](10);
        for (uint8 i; i < 10; i++) {
            uint8 id = C.SHORT_STARTING_ID + i;
            batches[i] = MTypes.BatchLiquidation({shorter: _shorter, shortId: id, shortOrderId: 0});
        }
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-Wallet-Batch");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT * 10, WALLET);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 0);
    }

    function testGas_liquidateErcEscrowedBatch() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](10);
        for (uint8 i; i < 10; i++) {
            uint8 id = C.SHORT_STARTING_ID + i;
            batches[i] = MTypes.BatchLiquidation({shorter: _shorter, shortId: id, shortOrderId: 0});
        }
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-ErcEscrowed-Batch");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT * 10, ERC_ESCROWED);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 0);
    }
}

contract GasSecondaryLiquidationBatchWithRates is GasLiquidationFixture {
    function setUp() public override {
        super.setUp();
        vm.prank(_diamond);
        dusd.mint(extra, DEFAULT_AMOUNT * 11); //for liquidateWallet
        assertEq(ob.getShortRecordCount(sender), 10);

        // Non-zero dethYieldRate
        deal(ob.contracts("steth"), ob.contracts("bridgeSteth"), 305 ether);
        diamond.updateYield(ob.vault());
        // Non-zero ercDebtRate
        testFacet.setErcDebtRate(asset, 0.1 ether); // 1.1x
        // Fake increasing asset ercDebt so it can be subtracted later
        ob.fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT, extra); // 0.1*10 = 1
        ob.fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, extra); // 0.1*10 = 1

        //lower eth price for liquidate
        ob.setETH(999 ether);
    }

    function testGas_liquidateWalletBatchWithRates() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](10);
        for (uint8 i; i < 10; i++) {
            uint8 id = C.SHORT_STARTING_ID + i;
            batches[i] = MTypes.BatchLiquidation({shorter: _shorter, shortId: id, shortOrderId: 0});
        }
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-Wallet-Batch-Rates");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT * 11, WALLET);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 0);
    }

    function testGas_liquidateErcEscrowedBatchWithRates() public {
        address _asset = asset;
        address _shorter = sender;
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](10);
        for (uint8 i; i < 10; i++) {
            uint8 id = C.SHORT_STARTING_ID + i;
            batches[i] = MTypes.BatchLiquidation({shorter: _shorter, shortId: id, shortOrderId: 0});
        }
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-ErcEscrowed-Batch-Rates");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT * 20, ERC_ESCROWED);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 0);
    }
}

contract GasLiquidationBlackSwanFreezeCratioGt1 is GasLiquidationFixture {
    function setUp() public override {
        super.setUp();

        ob.setETH(700 ether); // c-ratio 1.05
    }

    function testGas_BlackSwanFreezeCratioGt1() public {
        vm.prank(owner);
        startMeasuringGas("Shutdown-CratioGt1");
        diamond.shutdownMarket(asset);
        stopMeasuringGas();
        assertTrue(diamond.getAssetStruct(asset).frozen == F.Permanent);
    }
}

contract GasLiquidationBlackSwanFreezeCratioLt1 is GasLiquidationFixture {
    function setUp() public override {
        super.setUp();

        ob.setETH(600 ether); // c-ratio 0.9
    }

    function testGas_BlackSwanFreezeCratioLt1() public {
        vm.prank(owner);
        startMeasuringGas("Shutdown-CratioLt1");
        diamond.shutdownMarket(asset);
        stopMeasuringGas();
        assertTrue(diamond.getAssetStruct(asset).frozen == F.Permanent);
    }
}

contract GasLiquidationBlackSwanFreezeRedeemErc is GasLiquidationFixture {
    function setUp() public override {
        super.setUp();

        // Doesn't matter as long as less than market shutdown threshold
        ob.setETH(700 ether); // c-ratio 1.05

        vm.prank(owner);
        diamond.shutdownMarket(asset);
        vm.startPrank(sender);
        diamond.withdrawAsset(asset, DEFAULT_AMOUNT);

        assertTrue(diamond.getAssetStruct(asset).frozen == F.Permanent);
    }

    function testGas_BlackSwanFreezeRedeemErcWallet() public {
        startMeasuringGas("RedeemErc-Wallet");
        diamond.redeemErc(asset, DEFAULT_AMOUNT, 0);
        stopMeasuringGas();
    }

    function testGas_BlackSwanFreezeRedeemErcEscrowed() public {
        startMeasuringGas("RedeemErc-Escrowed");
        diamond.redeemErc(asset, 0, DEFAULT_AMOUNT);
        stopMeasuringGas();
    }

    function testGas_BlackSwanFreezeRedeemBoth() public {
        startMeasuringGas("RedeemErc-Both");
        diamond.redeemErc(asset, DEFAULT_AMOUNT, DEFAULT_AMOUNT);
        stopMeasuringGas();
    }
}

contract GasPrimaryLiquidationSRUnderMinShortErcTest is GasLiquidationFixture {
    function setUp() public override {
        super.setUp();
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, minShortErc - 1 wei, sender);
        assertEq(ob.getShorts().length, 1);

        // create asks for exit/liquidation
        ob.fundLimitAskOpt(0.0004 ether, DEFAULT_AMOUNT, extra);
        //lower eth price for liquidate
        ob.setETH(2666 ether);
        testFacet.setOracleTimeAndPrice(asset, testFacet.getOraclePriceT(asset));
        ob.setETH(2500 ether);
    }

    function testGas_CancelShortUnderMinShortErc() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        address _shorter = receiver;
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-Primary-UnderMinShortErc");
        diamond.liquidate(_asset, _shorter, C.SHORT_STARTING_ID, shortHintArray, C.STARTING_ID);
        stopMeasuringGas();
        gasPrimaryLiquidationAsserts({shorter: _shorter, loseCollateral: false});
    }
}

contract GasSecondaryLiquidationSRUnderMinShortErcTest is GasLiquidationFixture {
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 ercAmount = DEFAULT_AMOUNT - minShortErc + 100 ether;
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, ercAmount, sender);
        assertEq(ob.getShortRecordCount(receiver), 1);
        assertEq(ob.getShorts().length, 1);
        vm.prank(_diamond);
        dusd.mint(extra, ercAmount); //for liquidateWallet
        ob.depositUsd(extra, ercAmount); //for ercEscrowed
        //lower eth price for liquidate
        ob.setETH(999 ether);
    }

    function testGas_liquidateErcEscrowed_UnderMinShortErc() public {
        address _asset = asset;
        address _shorter = receiver;
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](1);
        batches[0] = MTypes.BatchLiquidation({shorter: _shorter, shortId: C.SHORT_STARTING_ID, shortOrderId: C.STARTING_ID});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-ErcEscrowed-UnderMinShortErc");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT, ERC_ESCROWED);
        stopMeasuringGas();
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, 0);
        assertEq(ob.getShorts().length, 0);
        assertEq(ob.getShortRecordCount(receiver), 0);
    }

    function testGas_liquidateWallet_UnderMinShortErc() public {
        address _asset = asset;
        address _shorter = receiver;
        MTypes.BatchLiquidation[] memory batches = new MTypes.BatchLiquidation[](1);
        batches[0] = MTypes.BatchLiquidation({shorter: _shorter, shortId: C.SHORT_STARTING_ID, shortOrderId: C.STARTING_ID});
        vm.startPrank(extra);
        startMeasuringGas("Liquidate-Wallet-UnderMinShortErc");
        diamond.liquidateSecondary(_asset, batches, DEFAULT_AMOUNT, WALLET);
        stopMeasuringGas();
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, 0);
        assertEq(ob.getShorts().length, 0);
        assertEq(ob.getShortRecordCount(receiver), 0);
    }
}
