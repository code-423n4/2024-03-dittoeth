// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {STypes, SR} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {C} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {console} from "contracts/libraries/console.sol";

contract RecoveryMode is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();

        fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        // @dev Matching future capital efficiency levels
        // @dev TODO: Delete after capital efficiency introduced
        vm.startPrank(owner);
        diamond.setPenaltyCR(asset, 101);
        diamond.setSecondaryLiquidationCR(asset, 108);
        diamond.setPrimaryLiquidationCR(asset, 109);
        diamond.setInitialCR(asset, 110);
        vm.stopPrank();

        // Bring market into recovery mode
        _setETHChainlinkOnly(999 ether); // CR < 1.50
        skip(15 minutes);
        assertLt(diamond.getAssetCollateralRatio(asset), diamond.getAssetNormalizedStruct(asset).recoveryCR);
        assertGt(diamond.getAssetCollateralRatio(asset), diamond.getAssetNormalizedStruct(asset).initialCR);
    }

    function test_RecoveryMode_DecreaseCollateral() public {
        vm.startPrank(sender);
        vm.expectRevert(Errors.BelowRecoveryModeCR.selector);
        decreaseCollateral(C.SHORT_STARTING_ID, 1 wei);
    }

    function test_RecoveryMode_CreateLimitShort() public {
        depositEth(sender, DEFAULT_PRICE.mulU88(DEFAULT_AMOUNT).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR));

        initialCR = diamond.getAssetStruct(asset).initialCR;
        vm.startPrank(sender);
        vm.expectRevert(Errors.BelowRecoveryModeCR.selector);
        diamond.createLimitShort(asset, DEFAULT_PRICE, DEFAULT_AMOUNT, badOrderHintArray, shortHintArrayStorage, initialCR);
    }

    function test_RecoveryMode_PrimaryLiquidation() public {
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        uint256 fillEth = liquidate(sender, C.SHORT_STARTING_ID, extra);
        assertGt(fillEth, 0);
    }

    function test_RecoveryMode_PrimaryLiquidation_Revert() public {
        _setETHChainlinkOnly(1000 ether); // CR = 1.50
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        vm.prank(extra);
        vm.expectRevert(Errors.SufficientCollateral.selector);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
    }
}
