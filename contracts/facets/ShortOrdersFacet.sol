// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {STypes, MTypes, O, SR} from "contracts/libraries/DataTypes.sol";
import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {LibSRRecovery} from "contracts/libraries/LibSRRecovery.sol";
import {C} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract ShortOrdersFacet is Modifiers {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    /**
     * @notice Creates limit short in market system
     * @dev incomingShort created here instead of AskMatchAlgo to prevent stack too deep
     * @dev Shorts can only be limits
     *
     * @param asset The market that will be impacted
     * @param price Unit price in eth for erc sold
     * @param ercAmount Amount of erc minted and sold
     * @param orderHintArray Array of hint ID for gas-optimized sorted placement on market
     * @param shortHintArray Array of hint ID for gas-optimized short matching above oracle price
     * @param shortOrderCR Initial Collateral Ratio for a short order, between min/max, converted to uint8
     */
    function createLimitShort(
        address asset,
        uint80 price,
        uint88 ercAmount,
        MTypes.OrderHint[] memory orderHintArray,
        uint16[] memory shortHintArray,
        uint16 shortOrderCR
    ) external isNotFrozen(asset) onlyValidAsset(asset) nonReentrant {
        MTypes.CreateLimitShortParam memory p;
        STypes.Asset storage Asset = s.asset[asset];
        STypes.Order memory incomingShort;

        //@dev create "empty" SR. Fail early.
        incomingShort.shortRecordId = LibShortRecord.createShortRecord(asset, msg.sender, SR.Closed, 0, 0, 0, 0, 0);

        uint256 cr = LibOrders.convertCR(shortOrderCR);
        if ((shortOrderCR + C.BID_CR) < Asset.initialCR || cr >= C.CRATIO_MAX_INITIAL) {
            revert Errors.InvalidCR();
        }

        // @dev minShortErc needs to be modified (bigger) when cr < 1
        p.minShortErc = cr < 1 ether ? LibAsset.minShortErc(asset).mul(1 ether + cr.inv()) : LibAsset.minShortErc(asset);
        p.eth = price.mul(ercAmount);
        p.minAskEth = LibAsset.minAskEth(asset);
        if (ercAmount < p.minShortErc || p.eth < p.minAskEth) revert Errors.OrderUnderMinimumSize();

        // For a short, need enough collateral to cover minting ERC (calculated using initialCR)
        if (s.vaultUser[Asset.vault][msg.sender].ethEscrowed < p.eth.mul(cr)) revert Errors.InsufficientETHEscrowed();

        incomingShort.addr = msg.sender;
        incomingShort.price = price;
        incomingShort.ercAmount = ercAmount;
        incomingShort.id = Asset.orderIdCounter;
        incomingShort.orderType = O.LimitShort;
        incomingShort.creationTime = LibOrders.getOffsetTime();
        incomingShort.shortOrderCR = shortOrderCR; // 170 -> 1.70x

        p.startingId = s.bids[asset][C.HEAD].nextId;
        STypes.Order storage highestBid = s.bids[asset][p.startingId];
        //@dev if match and match price is gt .5% to saved oracle in either direction, update startingShortId
        if (highestBid.price >= incomingShort.price && highestBid.orderType == O.LimitBid) {
            LibOrders.updateOracleAndStartingShortViaThreshold(asset, LibOracle.getPrice(asset), incomingShort, shortHintArray);
        }

        p.oraclePrice = LibOracle.getSavedOrSpotOraclePrice(asset);
        if (LibSRRecovery.checkRecoveryModeViolation(asset, cr, p.oraclePrice)) {
            revert Errors.BelowRecoveryModeCR();
        }

        //@dev reading spot oracle price
        if (incomingShort.price < p.oraclePrice) {
            LibOrders.addShort(asset, incomingShort, orderHintArray);
        } else {
            LibOrders.sellMatchAlgo(asset, incomingShort, orderHintArray, p.minAskEth);
        }
    }
}
