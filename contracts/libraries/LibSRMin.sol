// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {STypes, SR} from "contracts/libraries/DataTypes.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";

// import {console} from "contracts/libraries/console.sol";

library LibSRMin {
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
}
