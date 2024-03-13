// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Asset} from "contracts/tokens/Asset.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {MTypes, STypes, F} from "contracts/libraries/DataTypes.sol";
import {VAULT} from "contracts/libraries/Constants.sol";
// import {console} from "contracts/libraries/console.sol";

contract OwnerTest is OBFixture {
    function setUp() public override {
        super.setUp();
    }

    function test_OwnerRevert() public {
        vm.prank(sender);
        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.transferOwnership(extra);
    }

    function test_OwnerCandidateRevert() public {
        vm.prank(owner);
        diamond.transferOwnership(extra);
        vm.prank(sender);
        vm.expectRevert(Errors.NotOwnerCandidate.selector);
        diamond.claimOwnership();
    }

    function test_OwnerCandidate() public {
        assertEq(diamond.owner(), owner);
        assertEq(diamond.ownerCandidate(), address(0));

        vm.prank(owner);
        diamond.transferOwnership(extra);

        assertEq(diamond.owner(), owner);
        assertEq(diamond.ownerCandidate(), extra);

        vm.prank(extra);
        diamond.claimOwnership();

        assertEq(diamond.owner(), extra);
        assertEq(diamond.ownerCandidate(), address(0));
    }

    function test_TransferAdminship() public {
        vm.prank(owner);
        diamond.transferAdminship(extra);
        assertEq(diamond.owner(), owner);
        assertEq(diamond.admin(), extra);
        vm.prank(extra);
        diamond.transferAdminship(sender);
        assertEq(diamond.admin(), sender);
    }

    function test_OnlyAdminOrOwner() public {
        test_TransferAdminship();
        vm.prank(owner);
        diamond.transferAdminship(extra);
        assertEq(diamond.admin(), extra);
    }

    function test_Revert_OnlyAdmin() public {
        vm.prank(owner);
        diamond.transferAdminship(extra);
        assertEq(diamond.owner(), owner);
        assertEq(diamond.admin(), extra);
        vm.prank(sender);
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.transferAdminship(sender);
    }

    //Unit tests for setters
    //REVERT//
    function test_setTithe() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setTithe(VAULT.ONE, 2);
    }

    function test_Revert_setDittoMatchedRate() public {
        vm.startPrank(owner);
        vm.expectRevert("above 100");
        diamond.setDittoMatchedRate(VAULT.ONE, 101);
    }

    function test_Revert_setDittoShorterRate() public {
        vm.startPrank(owner);
        vm.expectRevert("above 100");
        diamond.setDittoShorterRate(VAULT.ONE, 101);
    }

    function test_Revert_SetInitialCR() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setInitialCR(asset, 100);

        vm.startPrank(owner);
        vm.expectRevert("above max CR");
        diamond.setInitialCR(asset, 1500);
    }

    function test_Revert_SetprimaryLiquidationCR() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setPrimaryLiquidationCR(asset, 100);

        vm.startPrank(owner);
        vm.expectRevert("below secondary liquidation");
        diamond.setPrimaryLiquidationCR(asset, 100 - 1);
        vm.expectRevert("above 5.0");
        diamond.setPrimaryLiquidationCR(asset, 500 + 1);
    }

    function test_Revert_SetsecondaryLiquidationCR() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setSecondaryLiquidationCR(asset, 100);

        vm.startPrank(owner);
        vm.expectRevert("below 1.0");
        diamond.setSecondaryLiquidationCR(asset, 100 - 1);
        vm.expectRevert("above 5.0");
        diamond.setSecondaryLiquidationCR(asset, 500 + 1);
        diamond.setInitialCR(asset, 800);
        vm.expectRevert("above 5.0");
        diamond.setSecondaryLiquidationCR(asset, 500 + 1);
    }

    function test_Revert_SetforcedBidPriceBuffer() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setForcedBidPriceBuffer(asset, 100);

        vm.startPrank(owner);
        vm.expectRevert("below 1.0");
        diamond.setForcedBidPriceBuffer(asset, 100 - 1);
        vm.expectRevert("above 2.0");
        diamond.setForcedBidPriceBuffer(asset, 200 + 1);
    }

    function test_Revert_SetpenaltyCR() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setPenaltyCR(asset, 100);

        vm.startPrank(owner);
        vm.expectRevert("below 1.0");
        diamond.setPenaltyCR(asset, 100 - 1);
        vm.expectRevert("above 1.2");
        diamond.setPenaltyCR(asset, 120 + 1);
    }

    function test_Revert_SetRecoveryCR() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setRecoveryCR(asset, 100);

        vm.startPrank(owner);
        vm.expectRevert("below 1.0");
        diamond.setRecoveryCR(asset, 100 - 1);
        vm.expectRevert("above 2.0");
        diamond.setRecoveryCR(asset, 200 + 1);
    }

    function test_Revert_SetDittoTargetCR() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setDittoTargetCR(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("below 1.0");
        diamond.setDittoTargetCR(asset, 10 - 1);
    }

    function test_Revert_SetTappFeePct() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setTappFeePct(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("Can't be zero");
        diamond.setTappFeePct(asset, 0);
        vm.expectRevert("above 250");
        diamond.setTappFeePct(asset, 250 + 1);
    }

    function test_Revert_SetCallerFeePct() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setCallerFeePct(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("Can't be zero");
        diamond.setCallerFeePct(asset, 0);
        vm.expectRevert("above 250");
        diamond.setCallerFeePct(asset, 250 + 1);
    }

    function test_Revert_SetMinBidEth() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setMinBidEth(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("Can't be zero");
        diamond.setMinBidEth(asset, 0);
    }

    function test_Revert_SetMinAskEth() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setMinAskEth(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("Can't be zero");
        diamond.setMinAskEth(asset, 0);
    }

    function test_Revert_SetMinShortErc() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setMinShortErc(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("Can't be zero");
        diamond.setMinShortErc(asset, 0);
    }

    function test_Revert_createBridge() public {
        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.createBridge(makeAddr("1"), VAULT.ONE, 1501);

        vm.startPrank(owner);
        diamond.createBridge(makeAddr("1"), VAULT.ONE, 200);
        vm.expectRevert(Errors.BridgeAlreadyCreated.selector);
        diamond.createBridge(makeAddr("1"), VAULT.ONE, 200);
        vm.expectRevert(Errors.InvalidVault.selector);
        diamond.createBridge(makeAddr("1"), 0, 200);

        vm.expectRevert("above 2.00%");
        diamond.createBridge(makeAddr("2"), VAULT.ONE, 201);
    }

    function test_Revert_WithdrawalFee() public {
        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        diamond.setWithdrawalFee(asset, 10);

        vm.startPrank(owner);
        vm.expectRevert("above 2.00%");
        diamond.setWithdrawalFee(_bridgeSteth, 201);
    }

    //NON-REVERT//
    function test_setDittoMatchedRate() public {
        vm.prank(owner);
        diamond.setDittoMatchedRate(VAULT.ONE, 2);

        assertEq(diamond.getVaultStruct(vault).dittoMatchedRate, 2);
    }

    function test_setDittoShorterRate() public {
        vm.prank(owner);
        diamond.setDittoShorterRate(VAULT.ONE, 2);

        assertEq(diamond.getVaultStruct(vault).dittoShorterRate, 2);
    }

    function test_SetInitialCR() public {
        assertEq(diamond.getAssetStruct(asset).initialCR, 500);
        vm.prank(owner);
        diamond.setInitialCR(asset, 450);
        assertEq(diamond.getAssetStruct(asset).initialCR, 450);
    }

    function test_SetprimaryLiquidationCR() public {
        assertEq(diamond.getAssetStruct(asset).primaryLiquidationCR, 400);
        vm.prank(owner);
        diamond.setPrimaryLiquidationCR(asset, 200);
        assertEq(diamond.getAssetStruct(asset).primaryLiquidationCR, 200);
    }

    function test_SetsecondaryLiquidationCR() public {
        assertEq(diamond.getAssetStruct(asset).secondaryLiquidationCR, 150);
        vm.prank(owner);
        diamond.setSecondaryLiquidationCR(asset, 200);
        assertEq(diamond.getAssetStruct(asset).secondaryLiquidationCR, 200);
    }

    function test_SetforcedBidPriceBuffer() public {
        assertEq(diamond.getAssetStruct(asset).forcedBidPriceBuffer, 110);
        vm.prank(owner);
        diamond.setForcedBidPriceBuffer(asset, 200);
        assertEq(diamond.getAssetStruct(asset).forcedBidPriceBuffer, 200);
    }

    function test_SetpenaltyCR() public {
        assertEq(diamond.getAssetStruct(asset).penaltyCR, 110);
        vm.prank(owner);
        diamond.setPenaltyCR(asset, 115);
        assertEq(diamond.getAssetStruct(asset).penaltyCR, 115);
    }

    function test_SetRecoveryCR() public {
        assertEq(diamond.getAssetStruct(asset).recoveryCR, 150);
        vm.prank(owner);
        diamond.setRecoveryCR(asset, 140);
        assertEq(diamond.getAssetStruct(asset).recoveryCR, 140);
    }

    function test_SetDittoTargetCR() public {
        assertEq(diamond.getAssetStruct(asset).dittoTargetCR, 60);
        vm.prank(owner);
        diamond.setDittoTargetCR(asset, 20);
        assertEq(diamond.getAssetStruct(asset).dittoTargetCR, 20);
    }

    function test_SetTappFeePct() public {
        assertEq(diamond.getAssetStruct(asset).tappFeePct, 25);
        vm.prank(owner);
        diamond.setTappFeePct(asset, 200);
        assertEq(diamond.getAssetStruct(asset).tappFeePct, 200);
    }

    function test_SetCallerFeePct() public {
        assertEq(diamond.getAssetStruct(asset).callerFeePct, 5);
        vm.prank(owner);
        diamond.setCallerFeePct(asset, 200);
        assertEq(diamond.getAssetStruct(asset).callerFeePct, 200);
    }

    function test_SetMinBidEth() public {
        assertEq(diamond.getAssetStruct(asset).minBidEth, 1);
        vm.prank(owner);
        diamond.setMinBidEth(asset, 2);
        assertEq(diamond.getAssetStruct(asset).minBidEth, 2);
    }

    function test_SetMinAskEth() public {
        assertEq(diamond.getAssetStruct(asset).minAskEth, 1);
        vm.prank(owner);
        diamond.setMinAskEth(asset, 2);
        assertEq(diamond.getAssetStruct(asset).minAskEth, 2);
    }

    function test_SetMinShortErc() public {
        assertEq(diamond.getAssetStruct(asset).minShortErc, 2000);
        vm.prank(owner);
        diamond.setMinShortErc(asset, 3000);
        assertEq(diamond.getAssetStruct(asset).minShortErc, 3000);
    }

    function test_CreateBridge() public {
        uint256 length = diamond.getBridges(VAULT.ONE).length;
        address newBridge = randomAddr;
        vm.prank(owner);
        diamond.createBridge(newBridge, VAULT.ONE, 0);
        assertEq(diamond.getBridges(VAULT.ONE).length, length + 1);
        assertEq(diamond.getBridges(VAULT.ONE)[length], newBridge);
        assertEq(diamond.getBridgeVault(newBridge), VAULT.ONE);
        assertEq(diamond.getBridgeNormalizedStruct(newBridge).withdrawalFee, 0);
    }

    function test_WithdrawalFee() public {
        vm.startPrank(owner);
        diamond.setWithdrawalFee(_bridgeSteth, 200);
        assertEq(diamond.getBridgeNormalizedStruct(_bridgeSteth).withdrawalFee, 0.02 ether);
    }

    function test_Revert_NotOwnerCreateMarket() public {
        STypes.Asset memory a;

        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.createMarket(asset, a);
    }

    function test_CreateMarket() public {
        STypes.Asset memory a;
        a.vault = uint8(VAULT.ONE);
        a.oracle = _ethAggregator;
        a.initialCR = 400;
        a.primaryLiquidationCR = 300;
        a.secondaryLiquidationCR = 200;
        a.forcedBidPriceBuffer = 120;
        a.penaltyCR = 110;
        a.tappFeePct = 25;
        a.callerFeePct = 5;
        a.minBidEth = 10;
        a.minAskEth = 10;
        a.minShortErc = 2000;
        a.recoveryCR = 150;
        a.dittoTargetCR = 20;
        Asset temp = new Asset(_diamond, "Temp", "TEMP");

        assertEq(diamond.getAssets().length, 1);
        assertEq(diamond.getAssetNormalizedStruct(asset).assetId, 0);
        assertEq(diamond.getAssetsMapping(0), _dusd);
        vm.prank(owner);
        diamond.createMarket({asset: address(temp), a: a});
        assertEq(diamond.getAssets().length, 2);
        assertEq(diamond.getAssetNormalizedStruct(address(temp)).assetId, 1);
        assertEq(diamond.getAssetsMapping(1), address(temp));
    }

    function test_Revert_CreateDuplicateMarket() public {
        STypes.Asset memory a;

        vm.prank(owner);
        vm.expectRevert(Errors.MarketAlreadyCreated.selector);

        diamond.createMarket(asset, a);
    }

    function test_Revert_CreateVaultAlreadyExists() public {
        MTypes.CreateVaultParams memory vaultParams;

        vm.prank(owner);
        vm.expectRevert(Errors.VaultAlreadyCreated.selector);
        diamond.createVault(_deth, VAULT.ONE, vaultParams);
    }

    function test_Revert_NotContractOwner() public {
        MTypes.CreateVaultParams memory vaultParams;
        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.createVault(_deth, VAULT.ONE, vaultParams);
    }

    function test_DittoMintToTreasury() public {
        assertEq(ditto.balanceOf(owner), 70_000_000 ether);
    }
}
