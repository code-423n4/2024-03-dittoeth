// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U80, U88} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {STypes, MTypes, SR} from "contracts/libraries/DataTypes.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {LibSRUtil} from "contracts/libraries/LibSRUtil.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {C} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract ShortRecordFacet is Modifiers {
    using LibSRUtil for STypes.ShortRecord;
    using LibShortRecord for STypes.ShortRecord;
    using U256 for uint256;
    using U80 for uint80;
    using U88 for uint88;

    address private immutable dusd;

    constructor(address _dusd) {
        dusd = _dusd;
    }

    /**
     * @notice Increases collateral of an active short
     *
     * @param asset The market that will be impacted
     * @param id Id of short
     * @param amount Eth amount to increase collateral by
     *
     */
    function increaseCollateral(address asset, uint8 id, uint88 amount)
        external
        isNotFrozen(asset)
        nonReentrant
        onlyValidShortRecord(asset, msg.sender, id)
    {
        STypes.Asset storage Asset = s.asset[asset];
        uint256 vault = Asset.vault;
        STypes.Vault storage Vault = s.vault[vault];
        STypes.VaultUser storage VaultUser = s.vaultUser[vault][msg.sender];
        if (VaultUser.ethEscrowed < amount) revert Errors.InsufficientETHEscrowed();

        STypes.ShortRecord storage short = s.shortRecords[asset][msg.sender][id];
        short.updateErcDebt(asset);
        uint256 yield = short.collateral.mul(short.dethYieldRate);
        short.collateral += amount;

        uint256 cRatio = short.getCollateralRatioSpotPrice(asset);
        if (cRatio >= C.CRATIO_MAX) revert Errors.CollateralHigherThanMax();

        // Prevent flash loan
        short.updatedAt = LibOrders.getOffsetTime();

        yield += amount.mul(Vault.dethYieldRate);
        short.dethYieldRate = yield.divU80(short.collateral);

        VaultUser.ethEscrowed -= amount;
        Vault.dethCollateral += amount;
        Asset.dethCollateral += amount;
        emit Events.IncreaseCollateral(asset, msg.sender, id, amount);
    }

    /**
     * @notice Decrease collateral of an active short
     * @dev Cannot decrease below initialCR
     *
     * @param asset The market that will be impacted
     * @param id Id of short
     * @param amount Eth amount to decrease collateral by
     *
     */
    function decreaseCollateral(address asset, uint8 id, uint88 amount)
        external
        isNotFrozen(asset)
        nonReentrant
        onlyValidShortRecord(asset, msg.sender, id)
    {
        STypes.ShortRecord storage short = s.shortRecords[asset][msg.sender][id];
        short.updateErcDebt(asset);
        if (amount > short.collateral) revert Errors.InsufficientCollateral();

        short.collateral -= amount;

        uint256 oraclePrice = LibOracle.getSavedOrSpotOraclePrice(asset);
        uint256 cRatio = short.getCollateralRatio(oraclePrice);
        if (cRatio < LibAsset.initialCR(asset)) revert Errors.CRLowerThanMin();

        if (LibSRUtil.checkRecoveryModeViolation(asset, cRatio, oraclePrice)) revert Errors.BelowRecoveryModeCR();

        uint256 vault = s.asset[asset].vault;
        s.vaultUser[vault][msg.sender].ethEscrowed += amount;

        LibSRUtil.disburseCollateral(asset, msg.sender, amount, short.dethYieldRate, short.updatedAt);
        emit Events.DecreaseCollateral(asset, msg.sender, id, amount);
    }

    /**
     * @notice Combine active shorts into one short
     *
     * @param asset The market that will be impacted
     * @param ids Array of short ids to be combined
     *
     */
    function combineShorts(address asset, uint8[] memory ids, uint16[] memory shortOrderIds)
        external
        isNotFrozen(asset)
        nonReentrant
        onlyValidShortRecord(asset, msg.sender, ids[0])
    {
        if (shortOrderIds.length != ids.length) revert Errors.InvalidNumberOfShortOrderIds();

        if (ids.length < 2) revert Errors.InsufficientNumberOfShorts();
        // First short in the array
        STypes.ShortRecord storage firstShort = s.shortRecords[asset][msg.sender][ids[0]];
        // @dev Load initial short elements in struct to avoid stack too deep
        MTypes.CombineShorts memory c;
        c.asset = asset;
        c.shortUpdatedAt = firstShort.updatedAt;

        for (uint256 i = ids.length - 1; i > 0; i--) {
            uint8 _id = ids[i];
            STypes.ShortRecord storage currentShort = _onlyValidShortRecord(c.asset, msg.sender, _id);

            SR currentStatus = currentShort.status;

            // @dev Take latest time when combining shorts (prevent flash loan)
            if (currentShort.updatedAt > c.shortUpdatedAt) {
                c.shortUpdatedAt = currentShort.updatedAt;
            }

            {
                uint88 currentShortCollateral = currentShort.collateral;
                uint88 currentShortErcDebt = currentShort.ercDebt;
                c.collateral += currentShortCollateral;
                c.ercDebt += currentShortErcDebt;
                c.yield += currentShortCollateral.mul(currentShort.dethYieldRate);
                c.ercDebtSocialized += currentShortErcDebt.mul(currentShort.ercDebtRate);
            }

            if (currentShort.tokenId != 0) {
                // @dev First short should have NFT to prevent need for re-mint
                if (firstShort.tokenId == 0) revert Errors.FirstShortMustBeNFT();
            }

            // Cancel this short and combine with short in ids[0]
            LibShortRecord.deleteShortRecord(c.asset, msg.sender, _id);

            // @dev partialFill shorts must be cancelled in combineShorts regardless of SR/short Order debt levels
            LibSRUtil.checkCancelShortOrder(c.asset, currentStatus, shortOrderIds[i], ids[i], msg.sender);
        }

        // Ensure the base shortRecord was not included in the array twice and therefore deleted
        if (firstShort.status == SR.Closed) revert Errors.FirstShortDeleted();

        // Merge all short records into the short at position id[0]
        firstShort.merge(c.ercDebt, c.ercDebtSocialized, c.collateral, c.yield, c.shortUpdatedAt);

        // Realize debt accounting before checking for flags
        firstShort.updateErcDebt(c.asset);

        emit Events.CombineShorts(c.asset, msg.sender, ids);
    }
}
