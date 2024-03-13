// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U80, U88} from "contracts/libraries/PRBMathHelper.sol";

import {IDiamond} from "interfaces/IDiamond.sol";

import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {STypes, MTypes, SR} from "contracts/libraries/DataTypes.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {LibSRMin} from "contracts/libraries/LibSRMin.sol";

// import {console} from "contracts/libraries/console.sol";

contract ExitShortFacet is Modifiers {
    using U256 for uint256;
    using U80 for uint80;
    using U88 for uint88;
    using LibShortRecord for STypes.ShortRecord;
    using {LibAsset.burnMsgSenderDebt} for address;

    address private immutable dusd;

    constructor(address _dusd) {
        dusd = _dusd;
    }

    /**
     * @notice Exits a short using shorter's ERC in wallet (i.e.MetaMask)
     * @dev allows for partial exit via buybackAmount
     *
     * @param asset The market that will be impacted
     * @param id Id of short
     * @param buybackAmount Erc amount to buy back
     *
     */
    function exitShortWallet(address asset, uint8 id, uint88 buybackAmount, uint16 shortOrderId)
        external
        isNotFrozen(asset)
        nonReentrant
        onlyValidShortRecord(asset, msg.sender, id)
    {
        STypes.Asset storage Asset = s.asset[asset];
        STypes.ShortRecord storage short = s.shortRecords[asset][msg.sender][id];
        SR initialStatus = short.status;

        short.updateErcDebt(asset);
        uint256 ercDebt = short.ercDebt;
        if (buybackAmount > ercDebt || buybackAmount == 0) revert Errors.InvalidBuyback();

        asset.burnMsgSenderDebt(buybackAmount);
        Asset.ercDebt -= buybackAmount;
        // refund the rest of the collateral if ercDebt is fully paid back
        if (buybackAmount == ercDebt) {
            uint88 collateral = short.collateral;
            s.vaultUser[Asset.vault][msg.sender].ethEscrowed += collateral;
            LibShortRecord.disburseCollateral(asset, msg.sender, collateral, short.dethYieldRate, short.updatedAt);
            LibShortRecord.deleteShortRecord(asset, msg.sender, id);
        } else {
            short.ercDebt -= buybackAmount;
        }

        LibSRMin.checkShortMinErc({
            asset: asset,
            initialStatus: initialStatus,
            shortOrderId: shortOrderId,
            shortRecordId: id,
            shorter: msg.sender
        });

        emit Events.ExitShortWallet(asset, msg.sender, id, buybackAmount);
    }

    /**
     * @notice Exits a short using shorter's ERC in balance (ErcEscrowed)
     * @dev allows for partial exit via buybackAmount
     *
     * @param asset The market that will be impacted
     * @param id Id of short
     * @param buybackAmount Erc amount to buy back
     *
     */
    function exitShortErcEscrowed(address asset, uint8 id, uint88 buybackAmount, uint16 shortOrderId)
        external
        isNotFrozen(asset)
        nonReentrant
        onlyValidShortRecord(asset, msg.sender, id)
    {
        STypes.Asset storage Asset = s.asset[asset];
        STypes.ShortRecord storage short = s.shortRecords[asset][msg.sender][id];
        SR initialStatus = short.status;

        short.updateErcDebt(asset);
        uint256 ercDebt = short.ercDebt;
        if (buybackAmount == 0 || buybackAmount > ercDebt) revert Errors.InvalidBuyback();

        {
            STypes.AssetUser storage AssetUser = s.assetUser[asset][msg.sender];
            if (AssetUser.ercEscrowed < buybackAmount) revert Errors.InsufficientERCEscrowed();

            AssetUser.ercEscrowed -= buybackAmount;
        }

        Asset.ercDebt -= buybackAmount;
        // refund the rest of the collateral if ercDebt is fully paid back
        if (ercDebt == buybackAmount) {
            uint88 collateral = short.collateral;
            s.vaultUser[Asset.vault][msg.sender].ethEscrowed += collateral;
            LibShortRecord.disburseCollateral(asset, msg.sender, collateral, short.dethYieldRate, short.updatedAt);

            LibShortRecord.deleteShortRecord(asset, msg.sender, id);
        } else {
            short.ercDebt -= buybackAmount;
        }

        LibSRMin.checkShortMinErc({
            asset: asset,
            initialStatus: initialStatus,
            shortOrderId: shortOrderId,
            shortRecordId: id,
            shorter: msg.sender
        });

        emit Events.ExitShortErcEscrowed(asset, msg.sender, id, buybackAmount);
    }

    /**
     * @notice Exits a short by placing bid on market
     * @dev allows for partial exit via buybackAmount
     *
     * @param asset The market that will be impacted
     * @param id Id of short
     * @param buybackAmount Erc amount to buy back
     * @param price Price at which shorter wants to place bid
     * @param shortHintArray Array of hintId for the id to start matching against shorts since you can't match a short < oracle price
     *
     */
    function exitShort(
        address asset,
        uint8 id,
        uint88 buybackAmount,
        uint80 price,
        uint16[] memory shortHintArray,
        uint16 shortOrderId
    ) external isNotFrozen(asset) nonReentrant onlyValidShortRecord(asset, msg.sender, id) {
        MTypes.ExitShort memory e;
        e.asset = asset;
        LibOrders.updateOracleAndStartingShortViaTimeBidOnly(e.asset, shortHintArray);

        STypes.Asset storage Asset = s.asset[e.asset];
        STypes.ShortRecord storage short = s.shortRecords[e.asset][msg.sender][id];

        // @dev Must prevent forcedBid from exitShort() matching with original shortOrder
        e.shortOrderIsCancelled = LibSRMin.checkCancelShortOrder({
            asset: asset,
            initialStatus: short.status,
            shortOrderId: shortOrderId,
            shortRecordId: id,
            shorter: msg.sender
        });

        short.updateErcDebt(e.asset);

        //@dev if short order was cancelled, fully exit
        e.buybackAmount = e.shortOrderIsCancelled ? short.ercDebt : buybackAmount;
        e.beforeExitCR = getCollateralRatioNonPrice(short);
        e.ercDebt = short.ercDebt;
        e.collateral = short.collateral;

        if (e.buybackAmount == 0 || e.buybackAmount > e.ercDebt) revert Errors.InvalidBuyback();

        {
            uint256 ethAmount = price.mul(e.buybackAmount);
            if (ethAmount > e.collateral) revert Errors.InsufficientCollateral();
        }

        // Temporary accounting to enable bid
        STypes.VaultUser storage VaultUser = s.vaultUser[Asset.vault][msg.sender];
        VaultUser.ethEscrowed += e.collateral;

        // Create bid with current msg.sender
        (e.ethFilled, e.ercAmountLeft) =
            IDiamond(payable(address(this))).createForcedBid(msg.sender, e.asset, price, e.buybackAmount, shortHintArray);
        if (e.ethFilled == 0) revert Errors.ExitShortPriceTooLow();
        e.ercFilled = e.buybackAmount - e.ercAmountLeft;
        Asset.ercDebt -= e.ercFilled;
        s.assetUser[e.asset][msg.sender].ercEscrowed -= e.ercFilled;

        // Refund the rest of the collateral if ercDebt is fully paid back
        if (e.ercDebt == e.ercFilled) {
            // Full Exit
            LibShortRecord.disburseCollateral(e.asset, msg.sender, e.collateral, short.dethYieldRate, short.updatedAt);
            LibShortRecord.deleteShortRecord(e.asset, msg.sender, id); // prevent re-entrancy
        } else {
            short.collateral -= e.ethFilled;
            short.ercDebt -= e.ercFilled;
            if (short.ercDebt < LibAsset.minShortErc(asset)) revert Errors.CannotLeaveDustAmount();

            //@dev Only allow partial exit if the CR is same or better than before
            if (getCollateralRatioNonPrice(short) < e.beforeExitCR) revert Errors.PostExitCRLtPreExitCR();

            //@dev collateral already subtracted in exitShort()
            VaultUser.ethEscrowed -= e.collateral - e.ethFilled;
            LibShortRecord.disburseCollateral(e.asset, msg.sender, e.ethFilled, short.dethYieldRate, short.updatedAt);
        }
        emit Events.ExitShort(asset, msg.sender, id, e.ercFilled);
    }

    function getCollateralRatioNonPrice(STypes.ShortRecord storage short) internal view returns (uint256 cRatio) {
        return short.collateral.div(short.ercDebt);
    }
}
