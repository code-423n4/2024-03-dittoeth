// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U96, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {IDiamond} from "interfaces/IDiamond.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {STypes, MTypes, SR} from "contracts/libraries/DataTypes.sol";
import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {LibSRRecovery} from "contracts/libraries/LibSRRecovery.sol";
import {LibSRMin} from "contracts/libraries/LibSRMin.sol";
import {C} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract PrimaryLiquidationFacet is Modifiers {
    using LibShortRecord for STypes.ShortRecord;
    using U256 for uint256;
    using U96 for uint96;
    using U88 for uint88;
    using U80 for uint80;

    address private immutable dusd;

    constructor(address _dusd) {
        dusd = _dusd;
    }

    /**
     * @notice Liquidates short by forcing shorter to place bid on market
     * @dev Primary liquidation method
     * @dev Shorter will bear the cost of forcedBid on market
     *
     * @param asset The market that will be impacted
     * @param shorter Shorter getting liquidated
     * @param id Id of short getting liquidated
     * @param shortHintArray Array of hintId for the id to start matching against shorts since you can't match a short < oracle price
     *
     * @return gasFee Estimated cost of gas for the forcedBid
     * @return ethFilled Amount of eth filled in forcedBid
     */
    function liquidate(address asset, address shorter, uint8 id, uint16[] memory shortHintArray, uint16 shortOrderId)
        external
        isNotFrozen(asset)
        nonReentrant
        onlyValidShortRecord(asset, shorter, id)
        returns (uint88, uint88)
    {
        if (msg.sender == shorter) revert Errors.CannotLiquidateSelf();
        // @dev TAPP partially reimburses gas fees, capped at 10 to limit arbitrary high cost
        if (shortHintArray.length > 10) revert Errors.TooManyHints();

        // @dev Ensures SR has enough ercDebt/collateral to make caller fee worthwhile
        LibSRMin.checkCancelShortOrder({
            asset: asset,
            initialStatus: s.shortRecords[asset][shorter][id].status,
            shortOrderId: shortOrderId,
            shortRecordId: id,
            shorter: shorter
        });

        //@dev liquidate requires more up-to-date oraclePrice
        LibOrders.updateOracleAndStartingShortViaTimeBidOnly(asset, shortHintArray);

        MTypes.PrimaryLiquidation memory m = _setLiquidationStruct(asset, shorter, id, shortOrderId);

        //@dev Can liquidate as long as CR is low enough
        if (m.cRatio >= LibAsset.primaryLiquidationCR(m.asset)) {
            // If CR is too high, check for recovery mode and violation to continue liquidation
            if (!LibSRRecovery.checkRecoveryModeViolation(m.asset, m.cRatio, m.oraclePrice)) revert Errors.SufficientCollateral();
        }

        // revert if no asks, or price too high
        _checklowestSell(m);

        _performForcedBid(m, shortHintArray);

        _liquidationFeeHandler(m);

        _fullorPartialLiquidation(m);

        emit Events.Liquidate(asset, shorter, id, msg.sender, m.ercDebtMatched);

        return (m.gasFee, m.ethFilled);
    }

    //PRIVATE FUNCTIONS

    // Reverts if no eligible sells, or if lowest sell price is too high
    // @dev startingShortId is updated via updateOracleAndStartingShortViaTimeBidOnly() prior to call
    function _checklowestSell(MTypes.PrimaryLiquidation memory m) private view {
        uint16 lowestAskKey = s.asks[m.asset][C.HEAD].nextId;
        uint16 startingShortId = s.asset[m.asset].startingShortId;
        uint256 bufferPrice = m.oraclePrice.mul(m.forcedBidPriceBuffer);
        if (
            // Checks for no eligible asks
            (lowestAskKey == C.TAIL || s.asks[m.asset][lowestAskKey].price > bufferPrice)
            // Checks for no eligible shorts
            && (
                startingShortId == C.HEAD // means no short >= oracleprice
                    || s.shorts[m.asset][startingShortId].price > bufferPrice
            )
        ) {
            revert Errors.NoSells();
        }
    }

    /**
     * @notice Sets the memory struct m with initial data
     *
     * @param asset The market that will be impacted
     * @param shorter Shorter getting liquidated
     * @param id Id of short getting liquidated
     *
     * @return m Memory struct used throughout PrimaryLiquidationFacet.sol
     */
    function _setLiquidationStruct(address asset, address shorter, uint8 id, uint16 shortOrderId)
        private
        returns (MTypes.PrimaryLiquidation memory)
    {
        LibShortRecord.updateErcDebt(asset, shorter, id);
        {
            MTypes.PrimaryLiquidation memory m;
            m.asset = asset;
            m.short = s.shortRecords[asset][shorter][id];
            m.shortOrderId = shortOrderId;
            m.vault = s.asset[asset].vault;
            m.shorter = shorter;
            m.penaltyCR = LibAsset.penaltyCR(asset);
            m.oraclePrice = LibOracle.getPrice(asset);
            m.cRatio = m.short.getCollateralRatio(m.oraclePrice);
            m.forcedBidPriceBuffer = LibAsset.forcedBidPriceBuffer(asset);
            m.callerFeePct = LibAsset.callerFeePct(m.asset);
            m.tappFeePct = LibAsset.tappFeePct(m.asset);
            m.ethDebt = m.short.ercDebt.mul(m.oraclePrice).mul(m.forcedBidPriceBuffer).mul(1 ether + m.tappFeePct + m.callerFeePct); // ethDebt accounts for forcedBidPriceBuffer and potential fees
            return m;
        }
    }

    /**
     * @notice Handles the set up and execution of making a forcedBid
     * @dev Shorter will bear the cost of forcedBid on market
     * @dev Depending on shorter's cRatio, the TAPP can attempt to fund bid
     *
     * @param m Memory struct used throughout PrimaryLiquidationFacet.sol
     * @param shortHintArray Array of hintId for the id to start matching against shorts since you can't match a short < oracle price
     *
     */
    function _performForcedBid(MTypes.PrimaryLiquidation memory m, uint16[] memory shortHintArray) private {
        uint256 startGas = gasleft();
        uint88 ercAmountLeft;

        //@dev Provide higher price to better ensure it can fully fill the liquidation
        uint80 _bidPrice = m.oraclePrice.mulU80(m.forcedBidPriceBuffer);

        // Shorter loses leftover collateral to TAPP when unable to maintain CR above the minimum
        m.loseCollateral = m.cRatio <= m.penaltyCR;

        //@dev Increase ethEscrowed by shorter's full collateral for forced bid
        STypes.VaultUser storage TAPP = s.vaultUser[m.vault][address(this)];
        TAPP.ethEscrowed += m.short.collateral;

        // Check ability of TAPP plus short collateral to pay back ethDebt
        if (TAPP.ethEscrowed < m.ethDebt) {
            STypes.Asset storage Asset = s.asset[m.asset];
            uint96 ercDebtPrev = m.short.ercDebt;
            if (Asset.ercDebt <= ercDebtPrev) {
                // Occurs when only one shortRecord in the asset (market)
                revert Errors.CannotSocializeDebt();
            }
            m.loseCollateral = true;
            // @dev Max ethDebt can only be the ethEscrowed in the TAPP
            m.ethDebt = TAPP.ethEscrowed;
            // Reduce ercDebt proportional to ethDebt
            m.short.ercDebt = uint88(m.ethDebt.div(_bidPrice.mul(1 ether + m.callerFeePct + m.tappFeePct))); // @dev(safe-cast)
            uint96 ercDebtSocialized = ercDebtPrev - m.short.ercDebt;
            // Update ercDebtRate to socialize loss (increase debt) to other shorts
            Asset.ercDebtRate += ercDebtSocialized.divU64(Asset.ercDebt - ercDebtPrev);
        }

        // @dev Liquidation contract will be the caller. Virtual accounting done later for shorter or TAPP
        (m.ethFilled, ercAmountLeft) =
            IDiamond(payable(address(this))).createForcedBid(address(this), m.asset, _bidPrice, m.short.ercDebt, shortHintArray);

        m.ercDebtMatched = m.short.ercDebt - ercAmountLeft;

        //@dev virtually burning the repurchased debt
        s.assetUser[m.asset][address(this)].ercEscrowed -= m.ercDebtMatched;
        s.asset[m.asset].ercDebt -= m.ercDebtMatched;

        uint256 gasUsed = startGas - gasleft();
        //@dev manually setting basefee to 1,000,000 in foundry.toml;
        //@dev By basing gasFee off of baseFee instead of priority, adversaries are prevent from draining the TAPP
        m.gasFee = uint88(gasUsed * block.basefee); // @dev(safe-cast)
    }

    /**
     * @notice Handles the distribution of liquidationFee
     * @dev liquidationFee is taken into consideration when determining black swan
     *
     * @param m Memory struct used throughout PrimaryLiquidationFacet.sol
     *
     */
    function _liquidationFeeHandler(MTypes.PrimaryLiquidation memory m) private {
        STypes.VaultUser storage VaultUser = s.vaultUser[m.vault][msg.sender];
        STypes.VaultUser storage TAPP = s.vaultUser[m.vault][address(this)];
        // distribute fees to TAPP and caller
        uint88 tappFee = m.ethFilled.mulU88(m.tappFeePct);
        uint88 callerFee = m.ethFilled.mulU88(m.callerFeePct) + m.gasFee;

        m.totalFee += tappFee + callerFee;
        //@dev TAPP already received the gasFee for being the forcedBid caller. tappFee nets out.
        if (TAPP.ethEscrowed >= callerFee) {
            TAPP.ethEscrowed -= callerFee;
            VaultUser.ethEscrowed += callerFee;
        } else {
            // Give caller (portion of?) tappFee instead of gasFee
            VaultUser.ethEscrowed += callerFee - m.gasFee + tappFee;
            m.totalFee -= m.gasFee;
            TAPP.ethEscrowed -= m.totalFee;
        }
    }

    function min88(uint256 a, uint88 b) private pure returns (uint88) {
        if (a > type(uint88).max) revert Errors.InvalidAmount();
        return a < b ? uint88(a) : b;
    }

    /**
     * @notice Handles accounting in event of full or partial liquidations
     *
     * @param m Memory struct used throughout PrimaryLiquidationFacet.sol
     *
     */
    function _fullorPartialLiquidation(MTypes.PrimaryLiquidation memory m) private {
        STypes.VaultUser storage TAPP = s.vaultUser[m.vault][address(this)];
        uint88 decreaseCol = min88(m.totalFee + m.ethFilled, m.short.collateral);

        if (m.short.ercDebt == m.ercDebtMatched) {
            // Full liquidation
            LibShortRecord.disburseCollateral(m.asset, m.shorter, m.short.collateral, m.short.dethYieldRate, m.short.updatedAt);
            LibShortRecord.deleteShortRecord(m.asset, m.shorter, m.short.id);
            if (!m.loseCollateral) {
                m.short.collateral -= decreaseCol;
                s.vaultUser[m.vault][m.shorter].ethEscrowed += m.short.collateral;
                TAPP.ethEscrowed -= m.short.collateral;
            }
        } else {
            // Partial liquidation
            m.short.ercDebt -= m.ercDebtMatched;
            m.short.collateral -= decreaseCol;
            s.shortRecords[m.asset][m.shorter][m.short.id] = m.short;

            TAPP.ethEscrowed -= m.short.collateral;
            LibShortRecord.disburseCollateral(m.asset, m.shorter, decreaseCol, m.short.dethYieldRate, m.short.updatedAt);

            // TAPP absorbs leftover short, unless it already owns the short
            if (m.loseCollateral && m.shorter != address(this)) {
                // Delete partially liquidated short
                LibShortRecord.deleteShortRecord(m.asset, m.shorter, m.short.id);
                // Absorb leftovers into TAPP short
                LibShortRecord.fillShortRecord(
                    m.asset,
                    address(this),
                    C.SHORT_STARTING_ID,
                    SR.FullyFilled,
                    m.short.collateral,
                    m.short.ercDebt,
                    s.asset[m.asset].ercDebtRate,
                    m.short.dethYieldRate
                );
            }
        }

        if (m.shorter != address(this)) {
            // Only relevant for non-TAPP SR
            LibSRMin.checkShortMinErc({
                asset: m.asset,
                initialStatus: m.short.status,
                shortOrderId: m.shortOrderId,
                shortRecordId: m.short.id,
                shorter: m.shorter
            });
        }
    }
}
