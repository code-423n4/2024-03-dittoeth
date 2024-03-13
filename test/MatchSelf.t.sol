// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {C} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {STypes, MTypes, O, SR} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {console} from "contracts/libraries/console.sol";

contract SellOrdersTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    uint256 public DEFAULT_COLLATERAL;

    function setUp() public override {
        super.setUp();
        DEFAULT_COLLATERAL =
            DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR + 1 ether);
    }

    function test_MatchAskWithBidSelf() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        // Normal assertions to compare against self-match
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        s.ethEscrowed = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT);
        assertStruct(sender, s);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        // Ensure expected behavior
        e.ercEscrowed = r.ercEscrowed;
        e.ethEscrowed = s.ethEscrowed;
        assertStruct(extra, e);
    }

    function test_MatchBidWithAskSelf() public {
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        // Normal assertions to compare against self-match
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        s.ethEscrowed = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT);
        assertStruct(sender, s);

        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        // Ensure expected behavior
        e.ercEscrowed = r.ercEscrowed;
        e.ethEscrowed = s.ethEscrowed;
        assertStruct(extra, e);
    }

    function test_MatchShortWithBidSelf() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        // Normal assertions to compare against self-match
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        uint256 collateral = DEFAULT_COLLATERAL;
        assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral);
        assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).collateral, collateral);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        // Ensure expected behavior
        e.ercEscrowed = r.ercEscrowed;
        assertStruct(extra, e);
        assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral * 2);
        assertEq(getShortRecord(extra, C.SHORT_STARTING_ID).collateral, collateral);
    }

    function test_MatchBidWithShortSelf() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        // Normal assertions to compare against self-match
        r.ercEscrowed = DEFAULT_AMOUNT;
        assertStruct(receiver, r);
        uint256 collateral = DEFAULT_COLLATERAL;
        assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral);
        assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).collateral, collateral);

        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        // Ensure expected behavior
        e.ercEscrowed = r.ercEscrowed;
        assertStruct(extra, e);
        assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral * 2);
        assertEq(getShortRecord(extra, C.SHORT_STARTING_ID).collateral, collateral);
    }

    /// NEED THESE TESTS IF ALLOW EXITING PARTIALFILL SHORTRECORD ///

    // Partially (half) exit then fully exit FullyFilled shortRecord with ASK order from self
    // function test_ExitShortWithAskSelf() public {
    //     fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
    //     fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);

    //     uint256 collateral = DEFAULT_COLLATERAL;
    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral);
    //     assertEq(
    //         getShortRecord(extra, C.SHORT_STARTING_ID).collateral, collateral
    //     );
    //     e.ercEscrowed = DEFAULT_AMOUNT;
    //     e.ethEscrowed = 0;
    //     assertStruct(extra, e);

    //     // Exit HALF of the shortRecord
    //     vm.prank(extra);
    //     createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
    //     exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, DEFAULT_PRICE, extra);

    //     collateral -= DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT / 2);
    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral);
    //     assertEq(
    //         getShortRecord(extra, C.SHORT_STARTING_ID).collateral, collateral
    //     );
    //     e.ercEscrowed = DEFAULT_AMOUNT / 2;
    //     e.ethEscrowed = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT / 2); // From the ask
    //     assertStruct(extra, e);

    //     // Exit FULL
    //     vm.prank(extra);
    //     createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
    //     exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, DEFAULT_PRICE, extra);

    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, 0);
    //     assertTrue(getShortRecord(extra, C.SHORT_STARTING_ID).status == SR.Closed);
    //     e.ercEscrowed = 0;
    //     e.ethEscrowed = DEFAULT_COLLATERAL; // Initial col returned + col from ask
    //     assertStruct(extra, e);
    // }

    // // Partially (half) exit then fully exit FullyFilled shortRecord with SHORT order from self
    // function test_ExitShortWithShortSelf() public {
    //     fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
    //     fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);

    //     uint256 collateral = DEFAULT_COLLATERAL;
    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral);
    //     assertEq(
    //         getShortRecord(extra, C.SHORT_STARTING_ID).collateral, collateral
    //     );
    //     e.ercEscrowed = DEFAULT_AMOUNT;
    //     e.ethEscrowed = 0;
    //     assertStruct(extra, e);

    //     // Exit HALF of the shortRecord
    //     fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);
    //     exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, DEFAULT_PRICE, extra);

    //     uint256 collateral2 = collateral / 2;
    //     uint256 collateral1 = collateral - DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT / 2);
    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral1 + collateral2);
    //     assertEq(
    //         getShortRecord(extra, C.SHORT_STARTING_ID).collateral, collateral1
    //     );
    //     assertEq(
    //         getShortRecord(extra, C.SHORT_STARTING_ID + 1).collateral, collateral2
    //     );
    //     assertStruct(extra, e); // no change

    //     // Exit FULL
    //     fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);
    //     exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, DEFAULT_PRICE, extra);

    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral);
    //     assertTrue(getShortRecord(extra, C.SHORT_STARTING_ID).status == SR.Closed);
    //     e.ethEscrowed = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mulU88(
    //         diamond.getAssetNormalizedStruct(asset).initialCR
    //     );
    //     assertStruct(extra, e);
    // }

    // // Partially (half) exit then fully exit PartialFill shortRecord with ASK order from self
    // function test_PartialFillShortExitShortWithAskSelf() public {
    //     fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
    //     fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);

    //     uint256 collateral = DEFAULT_COLLATERAL / 2;
    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral);
    //     assertEq(
    //         getShortRecord(extra, C.SHORT_STARTING_ID).collateral, collateral
    //     );
    //     e.ercEscrowed = DEFAULT_AMOUNT / 2;
    //     e.ethEscrowed = 0;
    //     assertStruct(extra, e);

    //     // Exit HALF of the shortRecord
    //     vm.prank(extra);
    //     createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 4); // Half of a half
    //     exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 4, DEFAULT_PRICE, extra);

    //     collateral -= DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT / 4);
    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral);
    //     assertEq(
    //         getShortRecord(extra, C.SHORT_STARTING_ID).collateral, collateral
    //     );
    //     e.ercEscrowed = DEFAULT_AMOUNT / 4;
    //     e.ethEscrowed = DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT / 4); // From the ask
    //     assertStruct(extra, e);

    //     // Exit FULL
    //     vm.prank(extra);
    //     createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 4);
    //     exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 4, DEFAULT_PRICE, extra);

    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, 0);
    //     assertTrue(getShortRecord(extra, C.SHORT_STARTING_ID).status == SR.Closed);
    //     e.ercEscrowed = 0;
    //     e.ethEscrowed = DEFAULT_COLLATERAL / 2; // Initial col returned + col from ask
    //     assertStruct(extra, e);
    // }

    // // Partially (half) exit then fully exit PartialFill shortRecord with different SHORT order from self
    // function test_PartialFillShortExitShortWithDifferentShortSelf() public {
    //     // Use higher price so the next short order will get used to fill exitShort
    //     fundLimitShortOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT, extra);
    //     fundLimitBidOpt(DEFAULT_PRICE + 1, DEFAULT_AMOUNT / 2, extra);
    //     // Get rid of extra wei to make assertions easier
    //     vm.prank(extra);
    //     decreaseCollateral(C.SHORT_STARTING_ID, 12000);

    //     uint256 collateral = DEFAULT_COLLATERAL / 2;
    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral);
    //     assertEq(
    //         getShortRecord(extra, C.SHORT_STARTING_ID).collateral, collateral
    //     );
    //     e.ercEscrowed = DEFAULT_AMOUNT / 2;
    //     e.ethEscrowed = 12000;
    //     assertStruct(extra, e);

    //     // Exit HALF of the shortRecord
    //     fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);
    //     exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 4, DEFAULT_PRICE, extra);

    //     uint256 collateral2 = collateral / 2;
    //     uint256 collateral1 = collateral - DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT / 4);
    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral1 + collateral2);
    //     assertEq(
    //         getShortRecord(extra, C.SHORT_STARTING_ID).collateral, collateral1
    //     );
    //     assertEq(
    //         getShortRecord(extra, C.SHORT_STARTING_ID + 1).collateral, collateral2
    //     );
    //     assertStruct(extra, e); // no change

    //     // Exit FULL
    //     exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 4, DEFAULT_PRICE, extra);

    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral);
    //     assertTrue(getShortRecord(extra, C.SHORT_STARTING_ID).status == SR.Closed);
    //     e.ethEscrowed += DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT / 2).mulU88(
    //         diamond.getAssetNormalizedStruct(asset).initialCR
    //     );
    //     assertStruct(extra, e);
    // }

    // // Partially (half) exit PartialFill shortRecord with original partially filled SHORT order
    // function test_PartialFillShortPartialExitShortWithSameShortOrderSelf() public {
    //     fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
    //     fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);

    //     uint256 collateral = DEFAULT_COLLATERAL / 2;
    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral);
    //     assertEq(
    //         getShortRecord(extra, C.SHORT_STARTING_ID).collateral, collateral
    //     );
    //     e.ercEscrowed = DEFAULT_AMOUNT / 2;
    //     e.ethEscrowed = 0;
    //     assertStruct(extra, e);

    //     // Exit HALF of the shortRecord
    //     exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 4, DEFAULT_PRICE, extra);

    //     collateral += collateral / 2; // filling of original short order
    //     collateral -= DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT / 4); // exited buyback amount
    //     assertEq(diamond.getVaultStruct(vault).dethCollateral, collateral);
    //     assertEq(
    //         getShortRecord(extra, C.SHORT_STARTING_ID).collateral, collateral
    //     );
    //     assertStruct(extra, e); // no change
    // }
}
