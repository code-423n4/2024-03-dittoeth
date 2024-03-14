// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {IAsset} from "interfaces/IAsset.sol";
import {IMockAggregatorV3} from "interfaces/IMockAggregatorV3.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";
import {C, VAULT} from "contracts/libraries/Constants.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {console} from "contracts/libraries/console.sol";

contract MultiAssetOrdersTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;

    uint80 public constant DEFAULT_PRICE_CGLD = 0.5 ether;
    uint88 public constant DEFAULT_AMOUNT_CGLD = 10 ether;

    IAsset public cgld;
    address public _cgld;
    IMockAggregatorV3 public cgldAggregator;
    address public _cgldAggregator;

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);

        _cgld = deployCode("Asset.sol", abi.encode(_diamond, "Ditto Gold", "CGLD"));
        cgld = IAsset(_cgld);
        vm.label(_cgld, "CGLD");
        _cgldAggregator = deployCode("MockAggregatorV3.sol");
        cgldAggregator = IMockAggregatorV3(_cgldAggregator);
        _setCGLD(2000 ether);

        STypes.Asset memory a;
        a.vault = uint8(VAULT.ONE);
        a.oracle = _cgldAggregator;
        a.initialCR = 400; // 400 -> 4 ether
        a.liquidationCR = 300; // 300 -> 3 ether
        a.forcedBidPriceBuffer = 120; // 120 -> 1.2 ether
        a.penaltyCR = 120; // 120 -> 1.2 ether
        a.tappFeePct = 30; // 30 -> .03 ether
        a.callerFeePct = 6; // 10 -> .006 ether
        a.minBidEth = 10; // 1 -> .1 ether
        a.minAskEth = 10; // 1 -> .1 ether
        a.minShortErc = 10; // 10 -> 10 ether
        a.recoveryCR = 140; // 140 -> 1.4 ether

        diamond.createMarket({asset: _cgld, a: a});

        vm.stopPrank();
    }

    function _setCGLD(int256 _amount) public {
        cgldAggregator.setRoundData(
            92233720368547778907 wei, _amount / ORACLE_DECIMALS, block.timestamp, block.timestamp, 92233720368547778907 wei
        );
    }

    function test_MultiAssetSameTime() public {
        MTypes.OrderHint[] memory orderHintArray;

        //setup original dusd market
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        STypes.Order[] memory shorts_dusd = getShorts();
        uint80 cgld_price = DEFAULT_PRICE_CGLD;
        uint88 cgld_amount = DEFAULT_AMOUNT_CGLD;
        depositEth(sender, cgld_amount.mulU88(cgld_price).mulU88(diamond.getAssetNormalizedStruct(_cgld).initialCR));
        uint16 gldInitialCR = diamond.getAssetStruct(_cgld).initialCR;
        // @dev calling before createLimitShort to prevent conflict with vm.prank()
        orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE_CGLD, O.LimitShort, 1);
        vm.prank(sender);
        diamond.createLimitShort(
            _cgld, DEFAULT_PRICE_CGLD, DEFAULT_AMOUNT_CGLD, orderHintArray, shortHintArrayStorage, gldInitialCR
        );

        STypes.Order[] memory shorts_cgld = diamond.getShorts(_cgld);
        assertEq(shorts_dusd[0].price, DEFAULT_PRICE);
        assertEq(shorts_dusd[0].ercAmount, DEFAULT_AMOUNT);
        assertEq(shorts_cgld[0].price, DEFAULT_PRICE_CGLD);
        assertEq(shorts_cgld[0].ercAmount, DEFAULT_AMOUNT_CGLD);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(getShorts().length, 0);
        depositEth(receiver, cgld_amount.mulU88(cgld_price));
        orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE_CGLD, O.LimitBid, 1);
        vm.prank(receiver);
        diamond.createBid(_cgld, DEFAULT_PRICE_CGLD, DEFAULT_AMOUNT_CGLD, C.LIMIT_ORDER, orderHintArray, shortHintArrayStorage);
        assertEq(diamond.getShorts(_cgld).length, 0);

        STypes.ShortRecord memory shortRecordUsd = getShortRecord(sender, C.SHORT_STARTING_ID);
        assertEq(shortRecordUsd.collateral, (LibOrders.convertCR(initialCR) + 1 ether).mul(DEFAULT_AMOUNT).mul(DEFAULT_PRICE));
        assertEq(shortRecordUsd.ercDebt, DEFAULT_AMOUNT);

        STypes.ShortRecord memory shortRecordGld = diamond.getShortRecord(_cgld, sender, C.SHORT_STARTING_ID);
        assertEq(
            shortRecordGld.collateral, cgld_amount.mul(cgld_price).mul(diamond.getAssetNormalizedStruct(_cgld).initialCR + 1 ether)
        );
        assertEq(shortRecordGld.ercDebt, DEFAULT_AMOUNT_CGLD);

        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
        assertEq(diamond.getAssetUserStruct(_cgld, receiver).ercEscrowed, DEFAULT_AMOUNT_CGLD);

        assertEq(diamond.getVaultStruct(vault).dethCollateral, shortRecordUsd.collateral + shortRecordGld.collateral);
    }

    function test_MultiAssetSettings() public {
        //test dusd ob settings (see OBFixture, createMarket())
        assertEq(diamond.getAssetStruct(asset).initialCR, 500);
        assertEq(diamond.getAssetStruct(asset).liquidationCR, 400);
        assertEq(diamond.getAssetStruct(asset).forcedBidPriceBuffer, 110);
        assertEq(diamond.getAssetStruct(asset).penaltyCR, 110);
        assertEq(diamond.getAssetStruct(asset).tappFeePct, 25);
        assertEq(diamond.getAssetStruct(asset).callerFeePct, 5);
        assertEq(diamond.getAssetStruct(asset).recoveryCR, 150);

        assertEq(diamond.getAssetNormalizedStruct(asset).initialCR, 5 ether);
        assertEq(diamond.getAssetNormalizedStruct(asset).liquidationCR, 4 ether);
        assertEq(diamond.getAssetNormalizedStruct(asset).forcedBidPriceBuffer, 1.1 ether);
        assertEq(diamond.getAssetNormalizedStruct(asset).penaltyCR, 1.1 ether);
        assertEq(diamond.getAssetNormalizedStruct(asset).tappFeePct, 0.025 ether);
        assertEq(diamond.getAssetNormalizedStruct(asset).callerFeePct, 0.005 ether);
        assertEq(diamond.getAssetNormalizedStruct(asset).recoveryCR, 1.5 ether);

        assertEq(diamond.getAssetStruct(_cgld).initialCR, 400);
        assertEq(diamond.getAssetStruct(_cgld).liquidationCR, 300);
        assertEq(diamond.getAssetStruct(_cgld).forcedBidPriceBuffer, 120);
        assertEq(diamond.getAssetStruct(_cgld).penaltyCR, 120);
        assertEq(diamond.getAssetStruct(_cgld).tappFeePct, 30);
        assertEq(diamond.getAssetStruct(_cgld).callerFeePct, 6);
        assertEq(diamond.getAssetStruct(_cgld).recoveryCR, 140);

        assertEq(diamond.getAssetNormalizedStruct(_cgld).initialCR, 4 ether);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).liquidationCR, 3 ether);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).forcedBidPriceBuffer, 1.2 ether);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).penaltyCR, 1.2 ether);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).tappFeePct, 0.03 ether);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).callerFeePct, 0.006 ether);
        assertEq(diamond.getAssetNormalizedStruct(_cgld).recoveryCR, 1.4 ether);
    }

    function test_RevertYieldDifferentVaults() public {
        // Deploy new gold market in different vault
        vm.startPrank(owner);
        _cgld = deployCode("Asset.sol", abi.encode(_diamond, "Ditto Gold", "CGLD"));
        cgld = IAsset(_cgld);
        vm.label(_cgld, "CGLD");
        _cgldAggregator = deployCode("MockAggregatorV3.sol");
        cgldAggregator = IMockAggregatorV3(_cgldAggregator);
        _setCGLD(2000 ether);

        STypes.Asset memory a;
        a.vault = 2;
        a.oracle = _cgldAggregator;
        a.initialCR = 400; // 400 -> 4 ether
        a.liquidationCR = 300; // 300 -> 3 ether
        a.forcedBidPriceBuffer = 120; // 120 -> 1.2 ether
        a.penaltyCR = 120; // 120 -> 1.2 ether
        a.tappFeePct = 30; // 30 -> .03 ether
        a.callerFeePct = 6; // 10 -> .006 ether
        a.minBidEth = 10; // 1 -> .1 ether
        a.minAskEth = 10; // 1 -> .1 ether
        a.minShortErc = 2000; // 2000 -> 2000 ether
        a.recoveryCR = 140; // 140 -> 1.4 ether

        diamond.createMarket({asset: _cgld, a: a});
        vm.stopPrank();

        address[] memory assets = new address[](2);
        assets[0] = asset; // Vault 1
        assets[1] = _cgld; // Vault 2

        vm.expectRevert(Errors.DifferentVaults.selector);
        diamond.distributeYield(assets);
    }
}
