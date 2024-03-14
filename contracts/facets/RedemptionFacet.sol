// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U104, U88, U80, U64, U32} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {STypes, MTypes, SR} from "contracts/libraries/DataTypes.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {LibSRUtil} from "contracts/libraries/LibSRUtil.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibBytes} from "contracts/libraries/LibBytes.sol";
import {C} from "contracts/libraries/Constants.sol";

import {SSTORE2} from "solmate/utils/SSTORE2.sol";
import {console} from "contracts/libraries/console.sol";

contract RedemptionFacet is Modifiers {
    using LibSRUtil for STypes.ShortRecord;
    using LibShortRecord for STypes.ShortRecord;
    using U256 for uint256;
    using U104 for uint104;
    using U88 for uint88;
    using U80 for uint80;
    using U64 for uint64;
    using U32 for uint32;

    function validRedemptionSR(STypes.ShortRecord storage shortRecord, address proposer, address shorter, uint256 minShortErc)
        internal
        view
        returns (bool)
    {
        // @dev Matches check in onlyValidShortRecord but with a more restrictive ercDebt condition
        // @dev Proposer can't redeem on self
        if (shortRecord.status == SR.Closed || shortRecord.ercDebt < minShortErc || proposer == shorter) {
            return false;
        } else {
            return true;
        }
    }

    /**
     * @notice Submit an array of SR as candidates for redemption, subject to dispute period
     * @dev Collateral and debt are immediately removed from the SR candidates
     * @dev Redemption Fee increases as more redemptions are proposed
     *
     * @param asset The market that will be impacted
     * @param proposalInput Array of data pertaining to the SR candidates
     * @param redemptionAmount Total amount of ercDebt requested to be redeemed
     * @param maxRedemptionFee Maximum fee that redeemer is willing to pay
     *
     */
    function proposeRedemption(
        address asset,
        MTypes.ProposalInput[] calldata proposalInput,
        uint88 redemptionAmount,
        uint88 maxRedemptionFee
    ) external isNotFrozen(asset) nonReentrant {
        if (proposalInput.length > type(uint8).max) revert Errors.TooManyProposals();
        MTypes.ProposeRedemption memory p;
        p.asset = asset;
        STypes.AssetUser storage redeemerAssetUser = s.assetUser[p.asset][msg.sender];
        uint256 minShortErc = LibAsset.minShortErc(p.asset);

        if (redemptionAmount < minShortErc) revert Errors.RedemptionUnderMinShortErc();

        if (redeemerAssetUser.ercEscrowed < redemptionAmount) revert Errors.InsufficientERCEscrowed();

        // @dev redeemerAssetUser.SSTORE2Pointer gets reset to address(0) after actual redemption
        if (redeemerAssetUser.SSTORE2Pointer != address(0)) revert Errors.ExistingProposedRedemptions();

        p.oraclePrice = LibOracle.getPrice(p.asset);

        bytes memory slate;
        for (uint8 i = 0; i < proposalInput.length; i++) {
            p.shorter = proposalInput[i].shorter;
            p.shortId = proposalInput[i].shortId;
            p.shortOrderId = proposalInput[i].shortOrderId;
            // @dev Setting this above _onlyValidShortRecord to allow skipping
            STypes.ShortRecord storage currentSR = s.shortRecords[p.asset][p.shorter][p.shortId];

            /// Evaluate proposed shortRecord

            if (!validRedemptionSR(currentSR, msg.sender, p.shorter, minShortErc)) continue;

            currentSR.updateErcDebt(p.asset);
            p.currentCR = currentSR.getCollateralRatio(p.oraclePrice);

            // @dev Skip if proposal is not sorted correctly or if above redemption threshold
            if (p.previousCR > p.currentCR || p.currentCR >= C.MAX_REDEMPTION_CR) continue;

            // @dev totalAmountProposed tracks the actual amount that can be redeemed. totalAmountProposed <= redemptionAmount
            if (p.totalAmountProposed + currentSR.ercDebt <= redemptionAmount) {
                p.amountProposed = currentSR.ercDebt;
            } else {
                p.amountProposed = redemptionAmount - p.totalAmountProposed;
                // @dev Exit when proposal would leave less than minShortErc, proxy for nearing end of slate
                if (currentSR.ercDebt - p.amountProposed < minShortErc) break;
            }

            /// At this point, the shortRecord passes all checks and will be included in the slate

            p.previousCR = p.currentCR;

            // @dev Cancel attached shortOrder if below minShortErc, regardless of ercDebt in SR
            // @dev All verified SR have ercDebt >= minShortErc so CR does not change in cancelShort()
            STypes.Order storage shortOrder = s.shorts[asset][p.shortOrderId];
            if (currentSR.status == SR.PartialFill && shortOrder.ercAmount < minShortErc) {
                if (shortOrder.shortRecordId != p.shortId || shortOrder.addr != p.shorter) revert Errors.InvalidShortOrder();
                LibOrders.cancelShort(asset, p.shortOrderId);
            }

            p.colRedeemed = p.oraclePrice.mulU88(p.amountProposed);
            if (p.colRedeemed > currentSR.collateral) {
                p.colRedeemed = currentSR.collateral;
            }

            currentSR.collateral -= p.colRedeemed;
            currentSR.ercDebt -= p.amountProposed;

            p.totalAmountProposed += p.amountProposed;
            p.totalColRedeemed += p.colRedeemed;

            // @dev directly write the properties of MTypes.ProposalData into bytes
            // instead of usual abi.encode to save on extra zeros being written
            slate = bytes.concat(
                slate,
                bytes20(p.shorter),
                bytes1(p.shortId),
                bytes8(uint64(p.currentCR)),
                bytes11(p.amountProposed),
                bytes11(p.colRedeemed)
            );

            LibSRUtil.disburseCollateral(p.asset, p.shorter, p.colRedeemed, currentSR.dethYieldRate, currentSR.updatedAt);
            p.redemptionCounter++;
            if (redemptionAmount - p.totalAmountProposed < minShortErc) break;
        }

        if (p.totalAmountProposed < minShortErc) revert Errors.RedemptionUnderMinShortErc();

        // @dev SSTORE2 the entire proposalData after validating proposalInput
        redeemerAssetUser.SSTORE2Pointer = SSTORE2.write(slate);
        redeemerAssetUser.slateLength = p.redemptionCounter;
        redeemerAssetUser.oraclePrice = p.oraclePrice;
        redeemerAssetUser.ercEscrowed -= p.totalAmountProposed;

        STypes.Asset storage Asset = s.asset[p.asset];
        Asset.ercDebt -= p.totalAmountProposed;

        uint32 protocolTime = LibOrders.getOffsetTime();
        redeemerAssetUser.timeProposed = protocolTime;
        // @dev Calculate the dispute period
        // @dev timeToDispute is immediate for shorts with CR <= 1.1x

        /*
        +-------+------------+
        | CR(X) |  Hours(Y)  |
        +-------+------------+
        | 1.1   |     0      |
        | 1.2   |    .333    |
        | 1.3   |    .75     |
        | 1.5   |    1.5     |
        | 1.7   |     3      |
        | 2.0   |     6      |
        +-------+------------+

        Creating fixed points and interpolating between points on the graph without using exponentials
        Using simple y = mx + b formula
        
        where x = currentCR - previousCR
        m = (y2-y1)/(x2-x1)
        b = previous fixed point (Y)
        */

        uint256 m;

        if (p.currentCR > 1.7 ether) {
            m = uint256(3 ether).div(0.3 ether);
            redeemerAssetUser.timeToDispute = protocolTime + uint32((m.mul(p.currentCR - 1.7 ether) + 3 ether) * 1 hours / 1 ether);
        } else if (p.currentCR > 1.5 ether) {
            m = uint256(1.5 ether).div(0.2 ether);
            redeemerAssetUser.timeToDispute =
                protocolTime + uint32((m.mul(p.currentCR - 1.5 ether) + 1.5 ether) * 1 hours / 1 ether);
        } else if (p.currentCR > 1.3 ether) {
            m = uint256(0.75 ether).div(0.2 ether);
            redeemerAssetUser.timeToDispute =
                protocolTime + uint32((m.mul(p.currentCR - 1.3 ether) + 0.75 ether) * 1 hours / 1 ether);
        } else if (p.currentCR > 1.2 ether) {
            m = uint256(0.417 ether).div(0.1 ether);
            redeemerAssetUser.timeToDispute =
                protocolTime + uint32((m.mul(p.currentCR - 1.2 ether) + C.ONE_THIRD) * 1 hours / 1 ether);
        } else if (p.currentCR > 1.1 ether) {
            m = uint256(C.ONE_THIRD.div(0.1 ether));
            redeemerAssetUser.timeToDispute = protocolTime + uint32(m.mul(p.currentCR - 1.1 ether) * 1 hours / 1 ether);
        }

        redeemerAssetUser.oraclePrice = p.oraclePrice;
        redeemerAssetUser.timeProposed = LibOrders.getOffsetTime();

        uint88 redemptionFee = calculateRedemptionFee(asset, p.totalColRedeemed, p.totalAmountProposed);
        if (redemptionFee > maxRedemptionFee) revert Errors.RedemptionFeeTooHigh();

        STypes.VaultUser storage VaultUser = s.vaultUser[Asset.vault][msg.sender];
        if (VaultUser.ethEscrowed < redemptionFee) revert Errors.InsufficientETHEscrowed();
        VaultUser.ethEscrowed -= redemptionFee;
        emit Events.ProposeRedemption(p.asset, msg.sender);
    }

    /**
     * @notice Challenge the proposed redemption candidates of a specific redeemer
     * @dev Fee is awarded based on ercDebt correctly disputed to encourage disputing bad proposals
     *
     * @param asset The market that will be impacted
     * @param redeemer Address of the redeemer
     * @param incorrectIndex Index of the proposal being disputed
     * @param disputeShorter Shorter address from the SR used to dispute the redeemer proposal
     * @param disputeShortId Id of the SR used to dispute the redeemer proposal
     *
     */
    function disputeRedemption(address asset, address redeemer, uint8 incorrectIndex, address disputeShorter, uint8 disputeShortId)
        external
        isNotFrozen(asset)
        nonReentrant
    {
        if (redeemer == msg.sender) revert Errors.CannotDisputeYourself();
        MTypes.DisputeRedemption memory d;
        d.asset = asset;
        d.redeemer = redeemer;

        STypes.AssetUser storage redeemerAssetUser = s.assetUser[d.asset][d.redeemer];
        if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();

        if (LibOrders.getOffsetTime() >= redeemerAssetUser.timeToDispute) revert Errors.TimeToDisputeHasElapsed();

        MTypes.ProposalData[] memory decodedProposalData =
            LibBytes.readProposalData(redeemerAssetUser.SSTORE2Pointer, redeemerAssetUser.slateLength);

        for (uint256 i = 0; i < decodedProposalData.length; i++) {
            if (decodedProposalData[i].shorter == disputeShorter && decodedProposalData[i].shortId == disputeShortId) {
                revert Errors.CannotDisputeWithRedeemerProposal();
            }
        }

        STypes.ShortRecord storage disputeSR = s.shortRecords[d.asset][disputeShorter][disputeShortId];
        // Match continue (skip) conditions in proposeRedemption()
        uint256 minShortErc = LibAsset.minShortErc(d.asset);
        if (!validRedemptionSR(disputeSR, d.redeemer, disputeShorter, minShortErc)) revert Errors.InvalidRedemption();

        MTypes.ProposalData memory incorrectProposal = decodedProposalData[incorrectIndex];
        MTypes.ProposalData memory currentProposal;
        STypes.Asset storage Asset = s.asset[d.asset];

        uint256 disputeCR = disputeSR.getCollateralRatio(redeemerAssetUser.oraclePrice);

        if (disputeCR < incorrectProposal.CR && disputeSR.updatedAt + C.DISPUTE_REDEMPTION_BUFFER <= redeemerAssetUser.timeProposed)
        {
            // @dev All proposals from the incorrectIndex onward will be removed
            // @dev Thus the proposer can only redeem a portion of their original slate
            for (uint256 i = incorrectIndex; i < decodedProposalData.length; i++) {
                currentProposal = decodedProposalData[i];

                STypes.ShortRecord storage currentSR = s.shortRecords[d.asset][currentProposal.shorter][currentProposal.shortId];
                currentSR.collateral += currentProposal.colRedeemed;
                currentSR.ercDebt += currentProposal.ercDebtRedeemed;

                d.incorrectCollateral += currentProposal.colRedeemed;
                d.incorrectErcDebt += currentProposal.ercDebtRedeemed;
            }

            s.vault[Asset.vault].dethCollateral += d.incorrectCollateral;
            Asset.dethCollateral += d.incorrectCollateral;
            Asset.ercDebt += d.incorrectErcDebt;

            // @dev Update the redeemer's SSTORE2Pointer
            if (incorrectIndex > 0) {
                redeemerAssetUser.slateLength = incorrectIndex;
            } else {
                // @dev this implies everything in the redeemer's proposal was incorrect
                delete redeemerAssetUser.SSTORE2Pointer;
                emit Events.DisputeRedemptionAll(d.asset, redeemer);
            }

            // @dev Penalty is based on the proposal with highest CR (decodedProposalData is sorted)
            // @dev PenaltyPct is bound between CallerFeePct and 33% to prevent exploiting primaryLiquidation fees
            uint256 penaltyPct = LibOrders.min(
                LibOrders.max(LibAsset.callerFeePct(d.asset), (currentProposal.CR - disputeCR).div(currentProposal.CR)), 0.33 ether
            );

            uint88 penaltyAmt = d.incorrectErcDebt.mulU88(penaltyPct);

            // @dev Give redeemer back ercEscrowed that is no longer used to redeem (penalty applied)
            redeemerAssetUser.ercEscrowed += (d.incorrectErcDebt - penaltyAmt);
            s.assetUser[d.asset][msg.sender].ercEscrowed += penaltyAmt;
        } else {
            revert Errors.InvalidRedemptionDispute();
        }
    }

    /**
     * @notice Claim the collateral from the verified redemption candidates
     * @dev Can only be called by the redeemer after the dispute period has passed
     *
     * @param asset The market that will be impacted
     *
     */
    function claimRedemption(address asset) external isNotFrozen(asset) nonReentrant {
        uint256 vault = s.asset[asset].vault;
        STypes.AssetUser storage redeemerAssetUser = s.assetUser[asset][msg.sender];
        STypes.VaultUser storage redeemerVaultUser = s.vaultUser[vault][msg.sender];
        if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();
        if (LibOrders.getOffsetTime() < redeemerAssetUser.timeToDispute) revert Errors.TimeToDisputeHasNotElapsed();

        MTypes.ProposalData[] memory decodedProposalData =
            LibBytes.readProposalData(redeemerAssetUser.SSTORE2Pointer, redeemerAssetUser.slateLength);

        uint88 totalColRedeemed;
        for (uint256 i = 0; i < decodedProposalData.length; i++) {
            MTypes.ProposalData memory currentProposal = decodedProposalData[i];
            totalColRedeemed += currentProposal.colRedeemed;
            _claimRemainingCollateral({
                asset: asset,
                vault: vault,
                shorter: currentProposal.shorter,
                shortId: currentProposal.shortId
            });
        }
        redeemerVaultUser.ethEscrowed += totalColRedeemed;
        delete redeemerAssetUser.SSTORE2Pointer;
        emit Events.ClaimRedemption(asset, msg.sender);
    }

    /**
     * @notice Claim the leftover collateral from a SR that has been fully redeemed
     * @dev Can only be called by the shorter after the dispute period has passed
     *
     * @param asset The market that will be impacted
     * @param redeemer Address of the redeemer
     * @param claimIndex Index of the proposal pointing to the shorter SR to be resolved
     * @param id Shorter address from the SR used to dispute the redeemer proposal
     *
     */
    // Redeemed shorters can call this to get their collateral back if redeemer does not claim
    function claimRemainingCollateral(address asset, address redeemer, uint8 claimIndex, uint8 id)
        external
        isNotFrozen(asset)
        nonReentrant
    {
        STypes.AssetUser storage redeemerAssetUser = s.assetUser[asset][redeemer];
        if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();
        if (redeemerAssetUser.timeToDispute > LibOrders.getOffsetTime()) revert Errors.TimeToDisputeHasNotElapsed();

        // @dev Only need to read up to the position of the SR to be claimed
        MTypes.ProposalData[] memory decodedProposalData =
            LibBytes.readProposalData(redeemerAssetUser.SSTORE2Pointer, claimIndex + 1);
        MTypes.ProposalData memory claimProposal = decodedProposalData[claimIndex];

        if (claimProposal.shorter != msg.sender && claimProposal.shortId != id) revert Errors.CanOnlyClaimYourShort();

        STypes.Asset storage Asset = s.asset[asset];
        _claimRemainingCollateral({asset: asset, vault: Asset.vault, shorter: msg.sender, shortId: id});
    }

    // Send leftover collateral back to shorter and close SR
    function _claimRemainingCollateral(address asset, uint256 vault, address shorter, uint8 shortId) private {
        STypes.ShortRecord storage shortRecord = s.shortRecords[asset][shorter][shortId];

        if (shortRecord.ercDebt == 0 && shortRecord.status == SR.FullyFilled) {
            // @dev Refund shorter the remaining collateral only if fully redeemed and not claimed already
            uint88 collateral = shortRecord.collateral;
            s.vaultUser[vault][shorter].ethEscrowed += collateral;
            // @dev Shorter shouldn't lose any unclaimed yield because dispute time > YIELD_DELAY_SECONDS
            LibSRUtil.disburseCollateral(asset, shorter, collateral, shortRecord.dethYieldRate, shortRecord.updatedAt);
            LibShortRecord.deleteShortRecord(asset, shorter, shortId);
        }
    }

    // @dev inspired by https://docs.liquity.org/faq/lusd-redemptions#how-is-the-redemption-fee-calculated
    function calculateRedemptionFee(address asset, uint88 colRedeemed, uint88 ercDebtRedeemed)
        internal
        returns (uint88 redemptionFee)
    {
        STypes.Asset storage Asset = s.asset[asset];
        uint32 protocolTime = LibOrders.getOffsetTime();
        uint256 secondsPassed = uint256((protocolTime - Asset.lastRedemptionTime)) * 1 ether;
        uint256 decayFactor = C.SECONDS_DECAY_FACTOR.pow(secondsPassed);
        uint256 decayedBaseRate = Asset.baseRate.mulU64(decayFactor);
        // @dev Calculate Asset.ercDebt prior to proposal
        uint104 totalAssetErcDebt = (ercDebtRedeemed + Asset.ercDebt).mulU104(C.BETA);
        // @dev Derived via this forumula: baseRateNew = baseRateOld + redeemedLUSD / (2 * totalLUSD)
        uint256 redeemedDUSDFraction = ercDebtRedeemed.div(totalAssetErcDebt);
        uint256 newBaseRate = decayedBaseRate + redeemedDUSDFraction;
        newBaseRate = LibOrders.min(newBaseRate, 1 ether); // cap baseRate at a maximum of 100%
        assert(newBaseRate > 0); // Base rate is always non-zero after redemption
        // Update the baseRate state variable
        Asset.baseRate = uint64(newBaseRate);
        Asset.lastRedemptionTime = protocolTime;
        uint256 redemptionRate = LibOrders.min((Asset.baseRate + 0.005 ether), 1 ether);
        return uint88(redemptionRate.mul(colRedeemed));
    }
}
