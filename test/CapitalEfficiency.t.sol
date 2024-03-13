// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {STypes, SR} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {C} from "contracts/libraries/Constants.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {console} from "contracts/libraries/console.sol";

contract CapitalEfficiency is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();

        // @dev Allow capital efficieny SR
        vm.prank(owner);
        diamond.setInitialCR(asset, 10);
        initialCR = diamond.getAssetStruct(asset).initialCR;
    }

    function test_CapitalEfficiency_CancelUpToMinShortErc() public {
        uint256 minShortErc = diamond.getMinShortErc(asset);
        uint88 underMinShortErc = uint88(minShortErc - 1);
        uint88 largeAmount = type(uint88).max;

        fundLimitShort(DEFAULT_PRICE, largeAmount, sender);
        fundLimitBid(DEFAULT_PRICE, underMinShortErc, receiver);

        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID);
        assertEq(shortRecord.ercDebt, underMinShortErc);
        assertApproxEqAbs(diamond.getCollateralRatio(asset, shortRecord), 1.1 ether, MAX_DELTA_SMALL);

        vm.prank(sender);
        cancelShort(C.STARTING_ID);

        // Ensure that a capital efficient SR when cancelled still provides minShortErc
        shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID);
        assertEq(shortRecord.ercDebt, minShortErc);
    }

    function test_CapitalEfficiency_minShortErcRequirement() public {
        uint88 minShortErc = uint88(diamond.getMinShortErc(asset));
        uint88 minShortErcMod = minShortErc.mulU88(11 ether); // (1 ether + cr.inv())
        depositEth(sender, DEFAULT_PRICE.mulU88(minShortErcMod));

        // For CR < 1, minShortErc requirement is stricter
        vm.startPrank(sender);
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, minShortErc, badOrderHintArray, shortHintArrayStorage, initialCR);

        // Fail to make short order with ercDebt just under expected requirement
        vm.expectRevert(Errors.OrderUnderMinimumSize.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, minShortErcMod - 1 wei, badOrderHintArray, shortHintArrayStorage, initialCR);

        // Sucessfully make short order with large enough ercDebt
        fundLimitShort(DEFAULT_PRICE, minShortErcMod, sender);
        assertGt(minShortErcMod, minShortErc);

        // Successfully make short order with old debt levels when CR > 1
        initialCR = 100;
        fundLimitShort(DEFAULT_PRICE, minShortErc, sender);

        // Match SR and assert CR
        fundLimitBid(DEFAULT_PRICE, minShortErcMod + minShortErc, receiver);
        // SR with minShortErcMod
        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID);
        assertEq(shortRecord.ercDebt, minShortErcMod);
        assertEq(diamond.getCollateralRatio(asset, shortRecord), 1.1 ether);
        // SR with minShortErc
        shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID + 1);
        assertEq(shortRecord.ercDebt, minShortErc);
        assertEq(diamond.getCollateralRatio(asset, shortRecord), 2.0 ether);
    }
}
