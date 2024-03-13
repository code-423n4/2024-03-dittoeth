// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {C, VAULT} from "contracts/libraries/Constants.sol";

import {GasHelper} from "test-gas/GasHelper.sol";

import {console} from "contracts/libraries/console.sol";

contract GasShortFixture is GasHelper {
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public virtual override {
        super.setUp();

        ob.depositUsd(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(sender, DEFAULT_AMOUNT.mulU88(100 ether));
    }

    modifier matchShorts(uint256 num) {
        for (uint256 i = 0; i < num; i++) {
            ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
            ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
        _;
    }
}

contract GasCombineShortTest is GasShortFixture {
    using U256 for uint256;

    function testGas_CombineShortsx2() public matchShorts(2) {
        address _asset = asset;
        vm.prank(sender);

        uint8[] memory ids = new uint8[](2);
        ids[0] = C.SHORT_STARTING_ID;
        ids[1] = C.SHORT_STARTING_ID + 1;
        uint16[] memory shortOrderIds = new uint16[](2);
        shortOrderIds[0] = 0;
        shortOrderIds[1] = 0;
        startMeasuringGas("ShortRecord-CombineShort");
        diamond.combineShorts(_asset, ids, shortOrderIds);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 1);
    }

    function testGas_CombineShortsx10Of100() public matchShorts(100) {
        address _asset = asset;
        uint8 num = 10;

        uint8[] memory ids = new uint8[](num);
        ids[0] = C.SHORT_STARTING_ID;
        ids[1] = C.SHORT_STARTING_ID + 17;
        ids[2] = C.SHORT_STARTING_ID + 23;
        ids[3] = C.SHORT_STARTING_ID + 35;
        ids[4] = C.SHORT_STARTING_ID + 36;
        ids[5] = C.SHORT_STARTING_ID + 51;
        ids[6] = C.SHORT_STARTING_ID + 52;
        ids[7] = C.SHORT_STARTING_ID + 57;
        ids[8] = C.SHORT_STARTING_ID + 66;
        ids[9] = C.SHORT_STARTING_ID + 95;

        uint16[] memory shortOrderIds = new uint16[](num);
        shortOrderIds[0] = 0;
        shortOrderIds[1] = 0;
        shortOrderIds[2] = 0;
        shortOrderIds[3] = 0;
        shortOrderIds[4] = 0;
        shortOrderIds[5] = 0;
        shortOrderIds[6] = 0;
        shortOrderIds[7] = 0;
        shortOrderIds[8] = 0;
        shortOrderIds[9] = 0;
        vm.prank(sender);
        startMeasuringGas("ShortRecord-CombineShortx10of100");
        diamond.combineShorts(_asset, ids, shortOrderIds);
        stopMeasuringGas();
        //@dev started with 100, combined 10 into 1
        assertEq(ob.getShortRecordCount(sender), 91);
    }

    function testGas_CombineShortsx100() public matchShorts(100) {
        address _asset = asset;

        uint8[] memory ids = new uint8[](100);
        uint16[] memory shortOrderIds = new uint16[](100);
        for (uint8 i = C.SHORT_STARTING_ID; i < C.SHORT_STARTING_ID + 100; i++) {
            ids[i - C.SHORT_STARTING_ID] = i;
            shortOrderIds[i - C.SHORT_STARTING_ID] = 0;
        }
        vm.prank(sender);
        startMeasuringGas("ShortRecord-CombineShortx100");
        diamond.combineShorts(_asset, ids, shortOrderIds);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 1);
    }
}

contract GasExitShortTest is GasShortFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        super.setUp();

        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        //create ask for exit/liquidation
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        // mint usd for exitShortWallet
        vm.prank(_diamond);
        dusd.mint(sender, DEFAULT_AMOUNT.mulU88(2 ether));
    }

    function testGas_ExitShortFull() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ExitShort-full");
        diamond.exitShort(_asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, shortHintArray, 0);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 1);
    }

    function testGas_ExitShortPartial() public {
        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ExitShort-partial");
        diamond.exitShort(_asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(0.5 ether), DEFAULT_PRICE, shortHintArray, 0);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 2);
        assertEq(ob.getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT.mulU88(0.5 ether));
    }

    function testGas_ExitShortWalletFull() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ExitShort-wallet-full");
        diamond.exitShortWallet(_asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, 0);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 1);
    }

    function testGas_ExitShortWalletPartial() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ExitShort-wallet-partial");
        diamond.exitShortWallet(_asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(0.5 ether), 0);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 2);
        assertEq(ob.getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT.mulU88(0.5 ether));
    }

    function testGas_ExitShortErcEscrowedFull() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ExitShort-ercEscrowed-full");
        diamond.exitShortErcEscrowed(_asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, 0);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 1);
    }

    function testGas_ExitShortErcEscrowedPartial() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ExitShort-ercEscrowed-partial");
        diamond.exitShortErcEscrowed(_asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(0.5 ether), 0);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(sender), 2);
        assertEq(ob.getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT.mulU88(0.5 ether));
    }
}

contract GasShortCollateralTest is GasShortFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function testGas_IncreaseCollateral() public matchShorts(1) {
        vm.prank(sender);
        diamond.increaseCollateral(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE));

        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ShortRecord-IncreaseCollateral");
        diamond.increaseCollateral(_asset, C.SHORT_STARTING_ID, 1 wei);
        stopMeasuringGas();
        uint256 collateral = DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE) * 7;
        assertEq(ob.getShortRecord(sender, C.SHORT_STARTING_ID).collateral, collateral + 1 wei);
    }

    function testGas_DecreaseCollateral() public matchShorts(1) {
        vm.prank(sender);
        diamond.increaseCollateral(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE));

        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ShortRecord-DecreaseCollateral");
        diamond.decreaseCollateral(_asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE));
        stopMeasuringGas();
        uint256 collateral = DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT) * 7;
        assertEq(ob.getShortRecord(sender, C.SHORT_STARTING_ID).collateral, collateral - DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE));
    }
}

contract GasShortMintNFT is GasShortFixture {
    using U256 for uint256;
    using U80 for uint80;

    uint88 public bridgeCreditReth;
    uint88 public bridgeCreditSteth;

    function setUp() public override {
        super.setUp();

        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        vm.prank(sender);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, 0);
        assertEq(diamond.getTokenId(), 2);

        ob.depositReth(sender, 1 ether); // Make bridgeCreditReth > 0

        bridgeCreditReth = diamond.getVaultUserStruct(VAULT.ONE, sender).bridgeCreditReth;
        bridgeCreditSteth = diamond.getVaultUserStruct(VAULT.ONE, sender).bridgeCreditSteth;

        //@Dev give extra a short and nft to set slot > 0
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        vm.prank(extra);
        diamond.mintNFT(asset, C.SHORT_STARTING_ID, 0);
        assertEq(diamond.getTokenId(), 3);
    }

    function testGas_MintNFT() public {
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("ShortRecord-MintNFT");
        diamond.mintNFT(_asset, C.SHORT_STARTING_ID + 1, 0);
        stopMeasuringGas();
        assertEq(diamond.getTokenId(), 4);
    }

    function testGas_TransferFromNFT() public {
        address _sender = sender;
        address _extra = extra;
        vm.prank(sender);
        startMeasuringGas("ShortRecord-TransferFromNFT");
        diamond.transferFrom(_sender, _extra, 1);
        stopMeasuringGas();
        assertLt(diamond.getVaultUserStruct(VAULT.ONE, sender).bridgeCreditReth, bridgeCreditReth);
        assertLt(diamond.getVaultUserStruct(VAULT.ONE, sender).bridgeCreditSteth, bridgeCreditSteth);
    }
}

contract GasPrimaryExitShortSRUnderMinShortErcTest is GasHelper {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
    }

    function testGas_ExitShortFull_SRUnderMinShortErc() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        ob.fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, minShortErc - 1 wei, receiver);

        //create ask for exit/liquidation
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        ob.fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        assertEq(ob.getShortRecordCount(sender), 1);
        assertEq(ob.getShorts().length, 1);

        uint16[] memory shortHintArray = createShortHintArrayGas({shortHint: ONE});
        address _asset = asset;
        address _sender = sender;
        vm.prank(_sender);
        startMeasuringGas("ExitShort-full-SRUnderMinShortErc");
        diamond.exitShort(_asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, shortHintArray, C.STARTING_ID);
        stopMeasuringGas();
        assertEq(ob.getShortRecordCount(_sender), 0);
        assertEq(ob.getShorts().length, 0);
    }
}
