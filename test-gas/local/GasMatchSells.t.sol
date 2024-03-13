// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

// import {console} from "contracts/libraries/console.sol";
import {GasHelper} from "test-gas/GasHelper.sol";
import {C, VAULT} from "contracts/libraries/Constants.sol";
import {MTypes} from "contracts/libraries/DataTypes.sol";

contract GasSellFixture is GasHelper {
    using U88 for uint88;

    function setUp() public virtual override {
        super.setUp();

        testFacet.nonZeroVaultSlot0(ob.vault());
        ob.depositUsd(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(sender, DEFAULT_AMOUNT.mulU88(100 ether));
    }

    function gasAskMatchBidTestAsserts(bool isFullyMatched) public {
        uint256 vault = VAULT.ONE;
        if (isFullyMatched) {
            assertEq(ob.getAsks().length, 0);
        } else {
            assertEq(ob.getAsks().length, 1);
        }

        assertEq(ob.getBids().length, 0);
        assertGt(diamond.getVaultUserStruct(vault, sender).ethEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
        assertLt(diamond.getAssetUserStruct(asset, sender).ercEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
        assertGt(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
    }

    function gasShortMatchBidTestAsserts(bool isFullyMatched, uint256 startingShortId) public {
        uint256 vault = VAULT.ONE;
        if (isFullyMatched) {
            assertEq(ob.getShorts().length, 0);
        } else {
            assertEq(ob.getShorts().length, 1);
        }

        assertEq(ob.getBids().length, 0);
        assertLt(diamond.getVaultUserStruct(vault, sender).ethEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
        assertGt(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
        assertEq(diamond.getAssetStruct(asset).startingShortId, startingShortId);
    }
}

contract GasAskMatchSingleBidTest is GasSellFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function testGas_MatchAskToBid() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToBid");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }

    function testGas_MatchAskToBidWithLeftOverAsk() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToBidWithLeftoverAsk");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT * 2, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: false});
    }

    function testGas_MatchAskToBidWithLeftOverBid() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        uint256 vault = VAULT.ONE;
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToBidWithLeftoverBid");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT / 2, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        assertEq(ob.getBids().length, 1);
        assertEq(ob.getAsks().length, 0);
        assertGt(diamond.getVaultUserStruct(vault, sender).ethEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
        assertLt(diamond.getAssetUserStruct(asset, sender).ercEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
        assertGt(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
    }

    function testGas_MatchAskToBidWithShares() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(C.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToBidWithShares");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }

    function testGas_MatchAskToBidWithDustAskCancelled() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToBidWithDustAskCancelled");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT + 1, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }
}

contract GasAskMatchSingleBidDustTest is GasSellFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
        uint256 amount =
            DEFAULT_AMOUNT + uint256(diamond.getAssetNormalizedStruct(asset).minBidEth).mul(C.DUST_FACTOR).div(DEFAULT_PRICE);
        ob.fundLimitBidOpt(DEFAULT_PRICE, uint88(amount) - 1, receiver);
    }

    function testGas_MatchAskToBidWithDustBidCancelled() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToBidWithDustBidCancelled");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});

        // Bid is considered fully filled and reuseable
        assertEq(diamond.getBidOrder(asset, C.HEAD).prevId, 100);
        assertEq(diamond.getBidOrder(asset, C.HEAD).nextId, C.HEAD);
    }
}

contract GasShortMatchSingleBidTest is GasSellFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function testGas_MatchShortToBid() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToBid");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }

    function testGas_MatchShortToBidWithLeftOverShort() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToBidWithLeftoverShort");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT * 2, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: false, startingShortId: 101});
    }

    function testGas_MatchShortToBidWithLeftOverBid() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        uint256 vault = VAULT.ONE;
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToBidWithLeftoverBid");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT / 2, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        assertEq(ob.getBids().length, 1);
        assertEq(ob.getShorts().length, 0);
        assertLt(diamond.getVaultUserStruct(vault, sender).ethEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
        assertGt(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT.mulU88(100 ether));
        assertEq(diamond.getAssetStruct(asset).startingShortId, 1);
    }

    function testGas_MatchShortToBidWithShares() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(C.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToBidWithShares");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }

    function testGas_MatchShortToBidWithDustShortCancelled() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToBidWithDustShortCancelled");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT + 1, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }
}

contract GasShortMatchSingleBidDustTest is GasSellFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
        uint256 amount =
            DEFAULT_AMOUNT + uint256(diamond.getAssetNormalizedStruct(asset).minBidEth).mul(C.DUST_FACTOR).div(DEFAULT_PRICE);
        ob.fundLimitBidOpt(DEFAULT_PRICE, uint88(amount) - 1, receiver);
    }

    function testGas_MatchShortToBidWithDustBidCancelled() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToBidWithDustBidCancelled");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});

        // Bid is considered fully filled and reuseable
        assertEq(diamond.getBidOrder(asset, C.HEAD).prevId, 100);
        assertEq(diamond.getBidOrder(asset, C.HEAD).nextId, C.HEAD);
    }
}

contract GasAskMatchMultpleBidsTest is GasSellFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function testGas_MatchAskToMultipleBids() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToMultipleBids");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT * 4, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }

    function testGas_MatchAskToMultipleBidsWithShares() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(C.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToMultipleBidsWithShares");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT * 4, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }
}

contract GasShortMatchMultpleBidsTest is GasSellFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function testGas_MatchShortToMultipleBids() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToMultipleBids");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT * 4, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }

    function testGas_MatchShortToMultipleBidsWithShares() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(C.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToMultipleBidsWithShares");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT * 4, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }
}

contract GasAskMatchMultpleBidsTestx100 is GasSellFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        uint128 numBids = 100;
        for (uint256 i = 0; i < numBids; i++) {
            ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
    }

    function testGas_MatchAskToMultipleBidsx100() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToMultipleBidsx100");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT * 100, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }

    function testGas_MatchAskToMultipleBidsWithSharesx100() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(C.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToMultipleBidsWithSharesx100");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT * 100, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }
}

contract GasShortMatchMultpleBidsTestx100 is GasSellFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        uint128 numBids = 100;
        for (uint256 i = 0; i < numBids; i++) {
            ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }
    }

    function testGas_MatchShortToMultipleBidsx100() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.startPrank(sender);
        startMeasuringGas("Order-MatchShortToMultipleBidsx100");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT * 100, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }

    function testGas_MatchShortToMultipleBidsWithSharesx100() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        skip(C.MIN_DURATION + 1);
        testFacet.setOracleTimeAndPrice(asset, DEFAULT_PRICE);
        vm.startPrank(sender);
        startMeasuringGas("Order-MatchShortToMultipleBidsWithSharesx100");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT * 100, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }
}

contract GasShortMatchSingleBudUpdateOracleTest is GasSellFixture {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function testGas_MatchShortToBidUpdatingOracleViaThreshold() public {
        uint16[] memory shortHintArray = ob.setShortHintArray();
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        // @dev set oracleprice to very low so short needs to update oracle upon match
        testFacet.setOracleTimeAndPrice(asset, 0.0002 ether);
        vm.prank(sender);
        startMeasuringGas("Order-MatchShortToBidUpdatingOracleViaThreshold");
        diamond.createLimitShort(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, orderHintArray, shortHintArray, initialCR);
        stopMeasuringGas();
        gasShortMatchBidTestAsserts({isFullyMatched: true, startingShortId: 1});
    }
}

contract MatchingAskToBidAtDiscountUpdateTitheTest is GasSellFixture {
    using U256 for uint256;

    uint80 public lowerPrice = 0.0002475 ether;

    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(lowerPrice, DEFAULT_AMOUNT, receiver);
    }

    function testGas_MatchAskToBid_MatchAtDiscount() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToBid-MatchAtDiscount");
        diamond.createAsk(_asset, lowerPrice, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }
}

contract MatchingAskToBidBackAtNormalUpdateTitheTest is GasSellFixture {
    using U256 for uint256;

    uint80 public lowerPrice = 0.0002475 ether;

    function setUp() public override {
        super.setUp();
        ob.fundLimitBidOpt(lowerPrice, DEFAULT_AMOUNT, receiver);
        ob.fundLimitAskOpt(lowerPrice, DEFAULT_AMOUNT, sender);
        ob.fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function testGas_MatchAskToBid_MatchBackAtNormal() public {
        MTypes.OrderHint[] memory orderHintArray = createOrderHintArrayGas();
        address _asset = asset;
        vm.prank(sender);
        startMeasuringGas("Order-MatchAskToBid-MatchBackAtNormal");
        diamond.createAsk(_asset, DEFAULT_PRICE, DEFAULT_AMOUNT, C.LIMIT_ORDER, orderHintArray);
        stopMeasuringGas();
        gasAskMatchBidTestAsserts({isFullyMatched: true});
    }
}
