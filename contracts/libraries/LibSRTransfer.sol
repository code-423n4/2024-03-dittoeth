// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {STypes, SR} from "contracts/libraries/DataTypes.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";
import {LibBridgeRouter} from "contracts/libraries/LibBridgeRouter.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";

// import {console} from "contracts/libraries/console.sol";

library LibSRTransfer {
    function transferShortRecord(address from, address to, uint40 tokenId) internal {
        AppStorage storage s = appStorage();

        STypes.NFT storage nft = s.nftMapping[tokenId];
        address asset = s.assetMapping[nft.assetId];
        STypes.ShortRecord storage short = s.shortRecords[asset][from][nft.shortRecordId];
        if (short.status == SR.Closed) revert Errors.OriginalShortRecordCancelled();
        if (short.ercDebt == 0) revert Errors.OriginalShortRecordRedeemed();

        //@dev shortOrderId is already validated in mintNFT
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
}
