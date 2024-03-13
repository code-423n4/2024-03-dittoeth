// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {IDiamond} from "interfaces/IDiamond.sol";

import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {STypes, MTypes, O, SR} from "contracts/libraries/DataTypes.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {C} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract BidOrdersFacet is Modifiers {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;
    using {LibOrders.isShort} for STypes.Order;

    /**
     * @notice Creates bid order in market
     * @dev IncomingBid created here instead of BidMatchAlgo to prevent stack too deep
     *
     * @param asset The market that will be impacted
     * @param price Unit price in eth for erc
     * @param ercAmount Amount of erc to buy
     * @param isMarketOrder Boolean for whether the bid is limit or market
     * @param orderHintArray Array of hint ID for gas-optimized sorted placement on market
     * @param shortHintArray Array of hint ID for gas-optimized short matching above oracle price
     *
     * @return ethFilled Amount of eth filled
     * @return ercAmountLeft Amount of erc not matched
     */
    function createBid(
        address asset,
        uint80 price,
        uint88 ercAmount,
        bool isMarketOrder,
        MTypes.OrderHint[] calldata orderHintArray,
        uint16[] calldata shortHintArray
    ) external isNotFrozen(asset) onlyValidAsset(asset) nonReentrant returns (uint88 ethFilled, uint88 ercAmountLeft) {
        LibOrders.updateOracleAndStartingShortViaTimeBidOnly(asset, shortHintArray);

        return _createBid(msg.sender, asset, price, ercAmount, isMarketOrder, orderHintArray, shortHintArray);
    }

    /**
     * @notice create a bid order for exiting a short, only callable by specific contracts
     *
     * @param sender Address of caller (only for exiting a short)
     * @param asset The market that will be impacted
     * @param price Unit price in eth for erc
     * @param ercAmount Amount of erc to buy
     * @param shortHintArray Array of hint ID for gas-optimized short matching above oracle price
     *
     * @return ethFilled Amount of eth filled
     * @return ercAmountLeft Amount of erc not matched
     */
    function createForcedBid(address sender, address asset, uint80 price, uint88 ercAmount, uint16[] calldata shortHintArray)
        external
        onlyDiamond
        returns (uint88 ethFilled, uint88 ercAmountLeft)
    {
        // @dev leave empty, don't need hint for market buys
        MTypes.OrderHint[] memory orderHintArray;

        // @dev update oracle in callers
        return _createBid(sender, asset, price, ercAmount, C.MARKET_ORDER, orderHintArray, shortHintArray);
    }

    function _createBid(
        address sender,
        address asset,
        uint80 price,
        uint88 ercAmount,
        bool isMarketOrder,
        MTypes.OrderHint[] memory orderHintArray,
        uint16[] memory shortHintArray
    ) private returns (uint88 ethFilled, uint88 ercAmountLeft) {
        uint256 eth = ercAmount.mul(price);
        if (eth < LibAsset.minBidEth(asset)) revert Errors.OrderUnderMinimumSize();

        STypes.Asset storage Asset = s.asset[asset];
        if (s.vaultUser[Asset.vault][sender].ethEscrowed < eth) revert Errors.InsufficientETHEscrowed();

        STypes.Order memory incomingBid;
        incomingBid.addr = sender;
        incomingBid.price = price;
        incomingBid.ercAmount = ercAmount;
        incomingBid.id = Asset.orderIdCounter;
        incomingBid.orderType = isMarketOrder ? O.MarketBid : O.LimitBid;
        incomingBid.creationTime = LibOrders.getOffsetTime();

        MTypes.BidMatchAlgo memory b;
        b.askId = s.asks[asset][C.HEAD].nextId;
        // @dev setting initial shortId to match "backwards" (See _shortDirectionHandler() below)
        b.shortHintId = b.shortId = Asset.startingShortId;

        STypes.Order memory lowestSell = _getLowestSell(asset, b);
        if (incomingBid.price >= lowestSell.price && (lowestSell.orderType == O.LimitAsk || lowestSell.orderType == O.LimitShort)) {
            // @dev if match and match price is gt .5% to saved oracle in either direction, update startingShortId
            LibOrders.updateOracleAndStartingShortViaThreshold(asset, LibOracle.getPrice(asset), incomingBid, shortHintArray);
            b.shortHintId = b.shortId = Asset.startingShortId;
            b.oraclePrice = LibOracle.getPrice(asset);
            return bidMatchAlgo(asset, incomingBid, orderHintArray, b);
        } else {
            // @dev no match, add to market if limit order
            LibOrders.addBid(asset, incomingBid, orderHintArray);
            return (0, ercAmount);
        }
    }

    /**
     * @notice The matching algorithm for bids
     *
     * @param asset The market that will be impacted
     * @param incomingBid Active bid order
     * @param orderHintArray Array of hint ID for gas-optimized sorted placement on market
     * @param b Memory struct used throughout bidMatchAlgo
     *
     * @return ethFilled Amount of eth filled
     * @return ercAmountLeft Amount of erc not matched
     */
    function bidMatchAlgo(
        address asset,
        STypes.Order memory incomingBid,
        MTypes.OrderHint[] memory orderHintArray,
        MTypes.BidMatchAlgo memory b
    ) private returns (uint88 ethFilled, uint88 ercAmountLeft) {
        uint256 minBidEth = LibAsset.minBidEth(asset);
        MTypes.Match memory matchTotal;

        while (true) {
            // @dev Handles scenario when no sells left after partial fill
            if (b.askId == C.TAIL && b.shortId == C.TAIL) {
                if (incomingBid.ercAmount.mul(incomingBid.price) >= minBidEth) {
                    LibOrders.addBid(asset, incomingBid, orderHintArray);
                }
                return matchIncomingBid(asset, incomingBid, matchTotal, b);
            }

            STypes.Order memory lowestSell = _getLowestSell(asset, b);

            if (incomingBid.price >= lowestSell.price) {
                // Consider bid filled if only dust amount left
                if (incomingBid.ercAmount.mul(lowestSell.price) == 0) {
                    return matchIncomingBid(asset, incomingBid, matchTotal, b);
                }
                matchlowestSell(asset, lowestSell, incomingBid, matchTotal);
                if (incomingBid.ercAmount > lowestSell.ercAmount) {
                    incomingBid.ercAmount -= lowestSell.ercAmount;
                    lowestSell.ercAmount = 0;
                    if (lowestSell.isShort()) {
                        b.matchedShortId = lowestSell.id;
                        b.prevShortId = lowestSell.prevId;
                        LibOrders.matchOrder(s.shorts, asset, lowestSell.id);
                        _shortDirectionHandler(asset, lowestSell, incomingBid, b);
                    } else {
                        b.matchedAskId = lowestSell.id;
                        LibOrders.matchOrder(s.asks, asset, lowestSell.id);
                        b.askId = lowestSell.nextId;
                    }
                } else {
                    if (incomingBid.ercAmount == lowestSell.ercAmount) {
                        if (lowestSell.isShort()) {
                            b.matchedShortId = lowestSell.id;
                            b.prevShortId = lowestSell.prevId;
                            LibOrders.matchOrder(s.shorts, asset, lowestSell.id);
                        } else {
                            b.matchedAskId = lowestSell.id;
                            LibOrders.matchOrder(s.asks, asset, lowestSell.id);
                        }
                    } else {
                        lowestSell.ercAmount -= incomingBid.ercAmount;
                        if (lowestSell.isShort()) {
                            b.dustShortId = lowestSell.id;
                            STypes.Order storage lowestShort = s.shorts[asset][lowestSell.id];
                            lowestShort.ercAmount = lowestSell.ercAmount;
                        } else {
                            b.dustAskId = lowestSell.id;
                            s.asks[asset][lowestSell.id].ercAmount = lowestSell.ercAmount;
                        }
                        // Check reduced dust threshold for existing limit orders
                        if (lowestSell.ercAmount.mul(lowestSell.price) >= LibAsset.minAskEth(asset).mul(C.DUST_FACTOR)) {
                            b.dustShortId = b.dustAskId = 0;
                        }
                    }
                    incomingBid.ercAmount = 0;
                    return matchIncomingBid(asset, incomingBid, matchTotal, b);
                }
            } else {
                if (incomingBid.ercAmount.mul(incomingBid.price) >= minBidEth) {
                    LibOrders.addBid(asset, incomingBid, orderHintArray);
                }
                return matchIncomingBid(asset, incomingBid, matchTotal, b);
            }
        }
    }
    /**
     * @notice Settles lowest ask and updates incoming bid
     * @dev DittoMatchedShares only assigned for asks sitting > 2 weeks of seconds
     *
     * @param asset The market that will be impacted
     * @param lowestSell Lowest sell order (ask or short) on market
     * @param incomingBid Active bid order
     * @param matchTotal Struct of the running matched totals
     */

    function matchlowestSell(
        address asset,
        STypes.Order memory lowestSell,
        STypes.Order memory incomingBid,
        MTypes.Match memory matchTotal
    ) private {
        uint88 fillErc = incomingBid.ercAmount > lowestSell.ercAmount ? lowestSell.ercAmount : incomingBid.ercAmount;
        uint88 fillEth = lowestSell.price.mulU88(fillErc);

        if (lowestSell.orderType == O.LimitShort) {
            // Match short
            uint88 colUsed = fillEth.mulU88(LibOrders.convertCR(lowestSell.shortOrderCR));
            LibOrders.increaseSharesOnMatch(asset, lowestSell, matchTotal, colUsed);
            uint88 shortFillEth = fillEth + colUsed;
            matchTotal.shortFillEth += shortFillEth;
            // Saves gas when multiple shorts are matched
            if (!matchTotal.ratesQueried) {
                STypes.Asset storage Asset = s.asset[asset];
                matchTotal.ratesQueried = true;
                matchTotal.ercDebtRate = Asset.ercDebtRate;
                matchTotal.dethYieldRate = s.vault[Asset.vault].dethYieldRate;
            }
            // Default enum is PartialFill
            SR status;
            if (incomingBid.ercAmount >= lowestSell.ercAmount) {
                status = SR.FullyFilled;
            }

            LibShortRecord.fillShortRecord(
                asset,
                lowestSell.addr,
                lowestSell.shortRecordId,
                status,
                shortFillEth,
                fillErc,
                matchTotal.ercDebtRate,
                matchTotal.dethYieldRate
            );
        } else {
            // Match ask
            s.vaultUser[s.asset[asset].vault][lowestSell.addr].ethEscrowed += fillEth;
            matchTotal.askFillErc += fillErc;
        }

        matchTotal.fillErc += fillErc;
        matchTotal.fillEth += fillEth;
        matchTotal.lastMatchPrice = lowestSell.price;
    }

    /**
     * @notice Final settlement of incoming bid
     *
     * @param asset The market that will be impacted
     * @param incomingBid Active bid order
     * @param matchTotal Struct of the running matched totals
     * @param b Memory struct used throughout bidMatchAlgo
     *
     * @return ethFilled Amount of eth filled
     * @return ercAmountLeft Amount of erc not matched
     */
    function matchIncomingBid(
        address asset,
        STypes.Order memory incomingBid,
        MTypes.Match memory matchTotal,
        MTypes.BidMatchAlgo memory b
    ) private returns (uint88 ethFilled, uint88 ercAmountLeft) {
        if (matchTotal.fillEth == 0) {
            return (0, incomingBid.ercAmount);
        }

        STypes.Asset storage Asset = s.asset[asset];
        uint256 vault = Asset.vault;

        LibOrders.updateSellOrdersOnMatch(asset, b);

        // Remove last sell order from order book if under dust threshold
        // @dev needs to happen after updateSellOrdersOnMatch()
        if (b.dustAskId > 0) {
            IDiamond(payable(address(this)))._cancelAsk(asset, b.dustAskId);
        } else if (b.dustShortId > 0) {
            IDiamond(payable(address(this)))._cancelShort(asset, b.dustShortId);
        }

        // If at least one short was matched
        if (matchTotal.shortFillEth > 0) {
            STypes.Vault storage Vault = s.vault[vault];

            // Matched Shares
            Vault.dittoMatchedShares += matchTotal.dittoMatchedShares;
            // Yield Accounting
            Vault.dethCollateral += matchTotal.shortFillEth;
            Asset.dethCollateral += matchTotal.shortFillEth;
            Asset.ercDebt += matchTotal.fillErc - matchTotal.askFillErc;

            // @dev Approximates the startingShortId after bid is fully executed
            STypes.Order storage currentShort = s.shorts[asset][b.shortId];
            O shortOrderType = currentShort.orderType;
            STypes.Order storage prevShort = s.shorts[asset][b.prevShortId];
            O prevShortOrderType = prevShort.orderType;

            if (shortOrderType != O.Cancelled && shortOrderType != O.Matched) {
                Asset.startingShortId = b.shortId;
            } else if (prevShortOrderType != O.Cancelled && prevShortOrderType != O.Matched && prevShort.price >= b.oraclePrice) {
                Asset.startingShortId = b.prevShortId;
            } else {
                if (b.isMovingFwd) {
                    Asset.startingShortId = currentShort.nextId;
                } else {
                    Asset.startingShortId = s.shorts[asset][b.shortHintId].nextId;
                }
            }
        }

        // Match bid
        address bidder = incomingBid.addr; // saves 18 gas
        s.vaultUser[vault][bidder].ethEscrowed -= matchTotal.fillEth;
        s.assetUser[asset][bidder].ercEscrowed += matchTotal.fillErc;
        emit Events.MatchOrder(asset, bidder, incomingBid.orderType, incomingBid.id, matchTotal.fillEth, matchTotal.fillErc);

        // @dev match price is based on the order that was already on orderbook
        LibOrders.handlePriceDiscount(asset, matchTotal.lastMatchPrice);
        return (matchTotal.fillEth, incomingBid.ercAmount);
    }

    // @dev If neither conditions are true, it returns an empty Order struct
    function _getLowestSell(address asset, MTypes.BidMatchAlgo memory b) private view returns (STypes.Order memory lowestSell) {
        if (b.shortId != C.HEAD) {
            STypes.Order storage lowestShort = s.shorts[asset][b.shortId];
            STypes.Order storage lowestAsk = s.asks[asset][b.askId];
            // @dev Setting lowestSell after comparing short and ask prices
            bool noAsks = b.askId == C.TAIL;
            bool shortPriceLessThanAskPrice = lowestShort.price < lowestAsk.price;
            if (noAsks || shortPriceLessThanAskPrice) {
                return lowestShort;
            } else {
                return lowestAsk;
            }
        } else if (b.askId != C.TAIL) {
            // @dev Handles scenario when there are no shorts
            return s.asks[asset][b.askId];
        }
    }

    function _shortDirectionHandler(
        address asset,
        STypes.Order memory lowestSell,
        STypes.Order memory incomingBid,
        MTypes.BidMatchAlgo memory b
    ) private view {
        /*
        @dev: Table refers to how algo updates the shorts after execution. Refer to updateSellOrdersOnMatch()
         +----------------+-------------------------+--------------------------+
         |    Direction   |         First ID        |          Last ID         |
         +----------------+-------------------------+--------------------------+
         | Fwd only       | firstShortIdBelowOracle*| matchedShortId           |
         | Back only      | prevShortId             |shortHintId**             |
         | Back then fwd  | firstShortIdBelowOracle | shortId                  |
         +----------------+-------------------------+--------------------------+
        
        * firstShortIdBelowOracle directly PRECEDES the first short Id that can be matched.
        firstShortIdBelowOracle cannot itself be matched since it is below oracle price
        
        ** shortHintId will always be first Id matched if valid (within 1% of oracle)
        As such, it will be used as the last Id matched (if moving backwards ONLY)

        Example:
        BEFORE: HEAD <-> (ID1)* <-> (ID2) <-> (ID3) <-> (ID4) <-> [ID5] <-> (ID6) <-> NEXT

        Assume (ID1) is under the oracle price, therefore (ID2) is technically first eligible short that can be matched
        Imagine the user passes in [ID5] as the hint, which corresponds to a price within 1% of the oracle, thus making it valid
        If the bid matches BACKWARDS ONLY, lets say to (ID2), then the linked list will look like this after execution

        AFTER: HEAD <-> (ID1)* <-> (ID6) <-> NEXT
        
        Here, (ID1) becomes the "First ID" and the shortHint ID [ID5] was the "LastID"
        */
        uint80 prevPrice = s.shorts[asset][b.prevShortId].price;
        if (prevPrice >= b.oraclePrice && !b.isMovingFwd) {
            // @dev shortHintId should always be the first thing matched
            b.isMovingBack = true;
            b.shortId = b.prevShortId;
        } else if (prevPrice < b.oraclePrice && !b.isMovingFwd) {
            b.firstShortIdBelowOracle = b.prevShortId;
            b.shortId = s.shorts[asset][b.shortHintId].nextId;

            STypes.Order storage nextShort = s.shorts[asset][lowestSell.nextId];
            // @dev Only set to true if actually moving forward
            if (b.shortId != C.HEAD && nextShort.price <= incomingBid.price) {
                b.isMovingFwd = true;
            }
        } else if (b.isMovingFwd) {
            b.shortId = lowestSell.nextId;
        }
    }
}
