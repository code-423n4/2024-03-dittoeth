// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U88, U256} from "contracts/libraries/PRBMathHelper.sol";

import {STypes, SR} from "contracts/libraries/DataTypes.sol";
import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";
import {C} from "contracts/libraries/Constants.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {LibBridgeRouter} from "contracts/libraries/LibBridgeRouter.sol";

// import {console} from "contracts/libraries/console.sol";

// extra ShortRecord helpers, similar to LibShortRecord
library LibSRUtil {
    using U88 for uint88;
    using U256 for uint256;

    function disburseCollateral(address asset, address shorter, uint88 collateral, uint256 dethYieldRate, uint32 updatedAt)
        internal
    {
        AppStorage storage s = appStorage();

        STypes.Asset storage Asset = s.asset[asset];
        uint256 vault = Asset.vault;
        STypes.Vault storage Vault = s.vault[vault];

        Vault.dethCollateral -= collateral;
        Asset.dethCollateral -= collateral;
        // Distribute yield
        uint88 yield = collateral.mulU88(Vault.dethYieldRate - dethYieldRate);
        if (yield > 0) {
            /*
            @dev If somebody exits a short, gets liquidated, decreases their collateral before YIELD_DELAY_SECONDS duration is up,
            they lose their yield to the TAPP
            */
            bool isNotRecentlyModified = LibOrders.getOffsetTime() - updatedAt > C.YIELD_DELAY_SECONDS;
            if (isNotRecentlyModified) {
                s.vaultUser[vault][shorter].ethEscrowed += yield;
            } else {
                s.vaultUser[vault][address(this)].ethEscrowed += yield;
            }
        }
    }

    function checkCancelShortOrder(address asset, SR initialStatus, uint16 shortOrderId, uint8 shortRecordId, address shorter)
        internal
        returns (bool isCancelled)
    {
        AppStorage storage s = appStorage();
        if (initialStatus == SR.PartialFill) {
            STypes.Order storage shortOrder = s.shorts[asset][shortOrderId];
            STypes.ShortRecord storage shortRecord = s.shortRecords[asset][shorter][shortRecordId];
            if (shortOrder.shortRecordId != shortRecordId || shortOrder.addr != shorter) revert Errors.InvalidShortOrder();

            if (shorter == msg.sender) {
                // If call comes from exitShort() or combineShorts() then always cancel
                LibOrders.cancelShort(asset, shortOrderId);
                assert(shortRecord.status != SR.PartialFill);
                return true;
            } else if (shortRecord.ercDebt < LibAsset.minShortErc(asset)) {
                // If call comes from liquidate() and SR ercDebt under minShortErc
                LibOrders.cancelShort(asset, shortOrderId);
                return true;
            }
        }
    }

    function checkShortMinErc(address asset, SR initialStatus, uint16 shortOrderId, uint8 shortRecordId, address shorter)
        internal
        returns (bool isCancelled)
    {
        AppStorage storage s = appStorage();

        STypes.ShortRecord storage shortRecord = s.shortRecords[asset][shorter][shortRecordId];
        uint256 minShortErc = LibAsset.minShortErc(asset);

        if (initialStatus == SR.PartialFill) {
            // Verify shortOrder
            STypes.Order storage shortOrder = s.shorts[asset][shortOrderId];
            if (shortOrder.shortRecordId != shortRecordId || shortOrder.addr != shorter) revert Errors.InvalidShortOrder();

            if (shortRecord.status == SR.Closed) {
                // Check remaining shortOrder
                if (shortOrder.ercAmount < minShortErc) {
                    // @dev The resulting SR will not have PartialFill status after cancel
                    LibOrders.cancelShort(asset, shortOrderId);
                    isCancelled = true;
                }
            } else {
                // Check remaining shortOrder and remaining shortRecord
                if (shortOrder.ercAmount + shortRecord.ercDebt < minShortErc) revert Errors.CannotLeaveDustAmount();
            }
        } else if (shortRecord.status != SR.Closed && shortRecord.ercDebt < minShortErc) {
            revert Errors.CannotLeaveDustAmount();
        }
    }

    function checkRecoveryModeViolation(address asset, uint256 shortRecordCR, uint256 oraclePrice)
        internal
        view
        returns (bool recoveryViolation)
    {
        AppStorage storage s = appStorage();

        uint256 recoveryCR = LibAsset.recoveryCR(asset);
        if (shortRecordCR < recoveryCR) {
            // Only check asset CR if low enough
            STypes.Asset storage Asset = s.asset[asset];
            if (Asset.ercDebt > 0) {
                // If Asset.ercDebt == 0 then assetCR is NA
                uint256 assetCR = Asset.dethCollateral.div(oraclePrice.mul(Asset.ercDebt));
                if (assetCR < recoveryCR) {
                    // Market is in recovery mode and shortRecord CR too low
                    return true;
                }
            }
        }
    }

    function transferShortRecord(address from, address to, uint40 tokenId) internal {
        AppStorage storage s = appStorage();

        STypes.NFT storage nft = s.nftMapping[tokenId];
        address asset = s.assetMapping[nft.assetId];
        STypes.ShortRecord storage short = s.shortRecords[asset][from][nft.shortRecordId];
        if (short.status == SR.Closed) revert Errors.OriginalShortRecordCancelled();
        if (short.ercDebt == 0) revert Errors.OriginalShortRecordRedeemed();

        // @dev shortOrderId is already validated in mintNFT
        if (short.status == SR.PartialFill) {
            LibOrders.cancelShort(asset, nft.shortOrderId);
        }

        short.tokenId = 0;
        LibShortRecord.deleteShortRecord(asset, from, nft.shortRecordId);
        LibBridgeRouter.transferBridgeCredit(asset, from, to, short.collateral);

        uint8 id = LibShortRecord.createShortRecord(
            asset, to, SR.FullyFilled, short.collateral, short.ercDebt, short.ercDebtRate, short.dethYieldRate, tokenId
        );

        nft.owner = to;
        nft.shortRecordId = id;
        nft.shortOrderId = 0;
    }

    function updateErcDebt(STypes.ShortRecord storage short, address asset) internal {
        AppStorage storage s = appStorage();

        // Distribute ercDebt
        uint64 ercDebtRate = s.asset[asset].ercDebtRate;
        uint88 ercDebt = short.ercDebt.mulU88(ercDebtRate - short.ercDebtRate);

        if (ercDebt > 0) {
            short.ercDebt += ercDebt;
            short.ercDebtRate = ercDebtRate;
        }
    }
}
