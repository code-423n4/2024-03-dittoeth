// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U88} from "contracts/libraries/PRBMathHelper.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {IAsset} from "interfaces/IAsset.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {console} from "contracts/libraries/console.sol";

contract RegressionTest is OBFixture {
    using U88 for uint88;

    function setUp() public override {
        super.setUp();
    }

    function test_Misc_Error_selector() public {
        // console.logBytes4(bytes4(Errors.BadShortHint.selector));
        // console.logBytes4(bytes4(getSelector("BadShortHint()")));
        assertEq(Errors.BadShortHint.selector, getSelector("BadShortHint()"));
    }

    function test_RegressionInv_MatchBackwardsButNotAllTheWay() public {
        // original
        // fundLimitShortOpt(250000000000003, 9999999999999999997, makeAddr("1"));
        // fundLimitShortOpt(250000000000002, 6985399747473758833, makeAddr("2"));
        // fundLimitBidOpt(2250000000010210, 9000000000000001778, makeAddr("3"));
        // fundLimitBidOpt(2250000000001666, 9000000000000000104, makeAddr("4"));

        // change updateSellOrdersOnMatch to handle when updating HEAD <-> HEAD
        fundLimitShortOpt(DEFAULT_PRICE + 1 wei, DEFAULT_AMOUNT, makeAddr("1")); //100
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.5 ether), makeAddr("2")); //101
        fundLimitBidOpt(DEFAULT_PRICE * 10, DEFAULT_AMOUNT.mulU88(1.1 ether), makeAddr("3"));
        assertEq(diamond.getShorts(asset).length, 1); // was 2
            // console.logShorts(asset);
    }
}
