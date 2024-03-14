// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U104, U80, U88, U16} from "contracts/libraries/PRBMathHelper.sol";

import {IDiamond} from "interfaces/IDiamond.sol";

import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";
import {STypes, MTypes, O, SR} from "contracts/libraries/DataTypes.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {LibVault} from "contracts/libraries/LibVault.sol";
import {C} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

library LibOrders {
    using LibOracle for address;
    using LibVault for uint256;
    using U256 for uint256;
    using U104 for uint104;
    using U16 for uint16;
    using U80 for uint80;
    using U88 for uint88;

    // @dev in seconds
    function getOffsetTime() internal view returns (uint32 timeInSeconds) {
        // shouldn't overflow in 136 years
        return uint32(block.timestamp - C.STARTING_TIME); // @dev(safe-cast)
    }

    function convertCR(uint16 cr) internal pure returns (uint256) {
        return (uint256(cr) * 1 ether) / C.TWO_DECIMAL_PLACES;
    }

    // For matched token reward
    function increaseSharesOnMatch(address asset, STypes.Order memory order, MTypes.Match memory matchTotal, uint88 eth) internal {
        AppStorage storage s = appStorage();

        // @dev use the diff to get more time (2159), to prevent overflow at year 2106
        uint32 timeTillMatch = getOffsetTime() - order.creationTime;
        if (timeTillMatch > C.MIN_DURATION) {
            // shares in eth-days
            uint88 shares = eth * (timeTillMatch / 1 days);
            matchTotal.dittoMatchedShares += shares;

            uint256 vault = s.asset[asset].vault;
            s.vaultUser[vault][order.addr].dittoMatchedShares += shares;
        }
    }

    function currentOrders(mapping(address => mapping(uint16 => STypes.Order)) storage orders, address asset)
        internal
        view
        returns (STypes.Order[] memory)
    {
        uint16 currentId = orders[asset][C.HEAD].nextId;
        uint256 size;

        while (currentId != C.TAIL) {
            size++;
            currentId = orders[asset][currentId].nextId;
        }

        STypes.Order[] memory list = new STypes.Order[](size);
        currentId = orders[asset][C.HEAD].nextId; // reset currentId

        for (uint256 i = 0; i < size; i++) {
            list[i] = orders[asset][currentId];
            currentId = orders[asset][currentId].nextId;
        }
        return list;
    }

    function isShort(STypes.Order memory order) internal pure returns (bool) {
        return order.orderType == O.LimitShort;
    }

    function addBid(address asset, STypes.Order memory order, MTypes.OrderHint[] memory orderHintArray) internal {
        AppStorage storage s = appStorage();
        uint16 hintId;

        if (order.orderType == O.MarketBid) {
            return;
        }
        uint16 nextId = s.bids[asset][C.HEAD].nextId;
        if (order.price > s.bids[asset][nextId].price || nextId == C.TAIL) {
            hintId = C.HEAD;
        } else {
            hintId = findOrderHintId(s.bids, asset, orderHintArray);
        }

        addOrder(s.bids, asset, order, hintId);

        uint256 vault = s.asset[asset].vault;
        uint88 eth = order.ercAmount.mulU88(order.price);
        s.vaultUser[vault][order.addr].ethEscrowed -= eth;
    }

    function addAsk(address asset, STypes.Order memory order, MTypes.OrderHint[] memory orderHintArray) internal {
        AppStorage storage s = appStorage();
        uint16 hintId;

        if (order.orderType == O.MarketAsk) {
            return;
        }
        uint16 nextId = s.asks[asset][C.HEAD].nextId;
        if (order.price < s.asks[asset][nextId].price || nextId == C.TAIL) {
            hintId = C.HEAD;
        } else {
            hintId = findOrderHintId(s.asks, asset, orderHintArray);
        }
        addOrder(s.asks, asset, order, hintId);

        s.assetUser[asset][order.addr].ercEscrowed -= order.ercAmount;
    }

    /**
     * @notice Add short struct onto market
     *
     * @param asset The market that will be impacted
     * @param order The short struct passed from shortMatchAlgo
     * @param orderHintArray array of Id passed in front end for optimized looping
     */
    function addShort(address asset, STypes.Order memory order, MTypes.OrderHint[] memory orderHintArray) internal {
        AppStorage storage s = appStorage();
        uint16 hintId;
        uint16 nextId = s.shorts[asset][C.HEAD].nextId;
        if (order.price < s.shorts[asset][nextId].price || nextId == C.TAIL) {
            hintId = C.HEAD;
        } else {
            hintId = findOrderHintId(s.shorts, asset, orderHintArray);
        }

        // @dev: Only need to set this when placing incomingShort onto market
        addOrder(s.shorts, asset, order, hintId);
        updateStartingShortIdViaShort(asset, order);
        uint256 vault = s.asset[asset].vault;
        uint88 eth = order.ercAmount.mulU88(order.price).mulU88(LibOrders.convertCR(order.shortOrderCR));
        s.vaultUser[vault][order.addr].ethEscrowed -= eth;
    }

    /**
     * @notice Add ask/short struct onto market
     *
     * @param asset The market that will be impacted
     * @param incomingOrder The ask or short struct passed from sellMatchAlgo
     * @param orderHintArray array of Id passed in front end for optimized looping
     */
    function addSellOrder(STypes.Order memory incomingOrder, address asset, MTypes.OrderHint[] memory orderHintArray) private {
        O o = normalizeOrderType(incomingOrder.orderType);
        if (o == O.LimitShort) {
            addShort(asset, incomingOrder, orderHintArray);
        } else if (o == O.LimitAsk) {
            addAsk(asset, incomingOrder, orderHintArray);
        }
    }

    /**
     * @notice Adds order onto market
     * @dev Reuses order ids for gas saving and id recycling
     *
     * @param orders the order mapping
     * @param asset The market that will be impacted
     * @param incomingOrder Bid, Ask, or Short Order
     * @param hintId Id passed in front end for optimized looping
     */

    // @dev partial addOrder
    function addOrder(
        mapping(address => mapping(uint16 => STypes.Order)) storage orders,
        address asset,
        STypes.Order memory incomingOrder,
        uint16 hintId
    ) private {
        AppStorage storage s = appStorage();
        // hint.prevId <-> hint <-> hint.nextId
        // set links of incoming to hint
        uint16 prevId = findPrevOfIncomingId(orders, asset, incomingOrder, hintId);
        uint16 nextId = orders[asset][prevId].nextId;
        incomingOrder.prevId = prevId;
        incomingOrder.nextId = nextId;
        uint16 id = incomingOrder.id;
        uint16 canceledID = orders[asset][C.HEAD].prevId;
        // @dev (ID) is exiting, [ID] is inserted
        // in this case, the protocol is re-using (ID) and moving it to [ID]
        // check if a previously cancelled or matched order exists
        if (canceledID != C.HEAD) {
            incomingOrder.prevOrderType = orders[asset][canceledID].orderType;
            // BEFORE: CancelledID <- (ID) <- HEAD <-> .. <-> PREV <----------> NEXT
            // AFTER1: CancelledID <--------- HEAD <-> .. <-> PREV <-> [ID] <-> NEXT
            uint16 prevCanceledID = orders[asset][canceledID].prevId;
            if (prevCanceledID != C.HEAD) {
                orders[asset][C.HEAD].prevId = prevCanceledID;
            } else {
                // BEFORE: HEAD <- (ID) <- HEAD <-> .. <-> PREV <----------> NEXT
                // AFTER1: HEAD <--------- HEAD <-> .. <-> PREV <-> [ID] <-> NEXT
                orders[asset][C.HEAD].prevId = C.HEAD;
            }
            // re-use the previous order's id
            id = incomingOrder.id = canceledID;
        } else {
            // BEFORE: HEAD <-> .. <-> PREV <--------------> NEXT
            // AFTER1: HEAD <-> .. <-> PREV <-> (NEW ID) <-> NEXT
            // otherwise just increment to a new order id
            // and the market grows in height/size
            s.asset[asset].orderIdCounter += 1;
        }
        orders[asset][id] = incomingOrder;
        if (nextId != C.TAIL) {
            orders[asset][nextId].prevId = incomingOrder.id;
        }

        orders[asset][prevId].nextId = incomingOrder.id;
        emit Events.CreateOrder(asset, incomingOrder.addr, incomingOrder.orderType, incomingOrder.id, incomingOrder.ercAmount);
    }

    /**
     * @notice Verifies that bid id is between two id based on price
     *
     * @param asset The market that will be impacted
     * @param _prevId The first id supposedly preceding the new price
     * @param _newPrice price of prospective order
     * @param _nextId The first id supposedly following the new price
     *
     * @return direction int direction to search (PREV, EXACT, NEXT)
     */
    function verifyBidId(address asset, uint16 _prevId, uint256 _newPrice, uint16 _nextId)
        internal
        view
        returns (int256 direction)
    {
        AppStorage storage s = appStorage();
        // @dev: TAIL can't be prevId because it will always be last item in list
        bool check1 = s.bids[asset][_prevId].price >= _newPrice || _prevId == C.HEAD;
        bool check2 = _newPrice > s.bids[asset][_nextId].price || _nextId == C.TAIL;

        if (check1 && check2) {
            return C.EXACT;
        } else if (!check1) {
            return C.PREV;
        } else if (!check2) {
            return C.NEXT;
        }
    }

    /**
     * @notice Verifies that short id is between two id based on price
     *
     * @param asset The market that will be impacted
     * @param _prevId The first id supposedly preceding the new price
     * @param _newPrice price of prospective order
     * @param _nextId The first id supposedly following the new price
     *
     * @return direction int direction to search (PREV, EXACT, NEXT)
     */
    function verifySellId(
        mapping(address => mapping(uint16 => STypes.Order)) storage orders,
        address asset,
        uint16 _prevId,
        uint256 _newPrice,
        uint16 _nextId
    ) private view returns (int256 direction) {
        // @dev: TAIL can't be prevId because it will always be last item in list
        bool check1 = orders[asset][_prevId].price <= _newPrice || _prevId == C.HEAD;

        bool check2 = _newPrice < orders[asset][_nextId].price || _nextId == C.TAIL;

        if (check1 && check2) {
            return C.EXACT;
        } else if (!check1) {
            return C.PREV;
        } else if (!check2) {
            return C.NEXT;
        }
    }

    /**
     * @notice Handles the reordering of market when order is canceled
     * @dev Reuses order ids for gas saving and id recycling
     *
     * @param orders the order mapping
     * @param asset The market that will be impacted
     * @param id Id of order
     */
    function cancelOrder(mapping(address => mapping(uint16 => STypes.Order)) storage orders, address asset, uint16 id) internal {
        // save this since it may be replaced
        uint16 prevHEAD = orders[asset][C.HEAD].prevId;

        // remove the links of ID in the market
        // @dev (ID) is exiting, [ID] is inserted
        // BEFORE: PREV <-> (ID) <-> NEXT
        // AFTER : PREV <----------> NEXT
        orders[asset][orders[asset][id].nextId].prevId = orders[asset][id].prevId;
        orders[asset][orders[asset][id].prevId].nextId = orders[asset][id].nextId;

        // create the links using the other side of the HEAD
        emit Events.CancelOrder(asset, id, orders[asset][id].orderType);
        _reuseOrderIds(orders, asset, id, prevHEAD, O.Cancelled);
    }

    /**
     * @notice moves the matched id to the prev side of HEAD
     * @dev this is how an id gets re-used
     *
     * @param orders the order mapping
     * @param asset The market that will be impacted
     * @param id ID of most recent matched order
     *
     */
    function matchOrder(mapping(address => mapping(uint16 => STypes.Order)) storage orders, address asset, uint16 id) internal {
        uint16 prevHEAD = orders[asset][C.HEAD].prevId;
        _reuseOrderIds(orders, asset, id, prevHEAD, O.Matched);
    }

    // shared function for both canceling and order and matching an order
    function _reuseOrderIds(
        mapping(address => mapping(uint16 => STypes.Order)) storage orders,
        address asset,
        uint16 id,
        uint16 prevHEAD,
        O cancelledOrMatched
    ) private {
        // matching ID1 and ID2
        // BEFORE: HEAD <- <---------------- HEAD <-> (ID1) <-> (ID2) <-> (ID3) <-> NEXT
        // AFTER1: HEAD <- [ID1] <---------- HEAD <-----------> (ID2) <-> (ID3) <-> NEXT
        // AFTER2: HEAD <- [ID1] <- [ID2] <- HEAD <---------------------> (ID3) <-> NEXT

        // @dev mark as cancelled instead of deleting the order itself
        orders[asset][id].orderType = cancelledOrMatched;
        orders[asset][C.HEAD].prevId = id;
        // Move the cancelled ID behind HEAD to re-use it
        // note: C_IDs (cancelled ids) only need to point back (set prevId, can retain nextId)
        // BEFORE: .. C_ID2 <- C_ID1 <--------- HEAD <-> ... [ID]
        // AFTER1: .. C_ID2 <- C_ID1 <- [ID] <- HEAD <-> ...
        if (prevHEAD != C.HEAD) {
            orders[asset][id].prevId = prevHEAD;
        } else {
            // if this is the first ID cancelled
            // HEAD.prevId needs to be HEAD
            // and one of the cancelled id.prevID should point to HEAD
            // BEFORE: HEAD <--------- HEAD <-> ... [ID]
            // AFTER1: HEAD <- [ID] <- HEAD <-> ...
            orders[asset][id].prevId = C.HEAD;
        }
    }

    /**
     * @notice Helper function for finding the (previous) id so that an incoming
     * @notice order can be placed onto the correct market.
     * @notice Uses hintId if possible, otherwise fallback to traversing the
     * @notice list of orders starting from HEAD
     *
     * @param orders the order mapping
     * @param asset The market that will be impacted
     * @param incomingOrder the Order to be placed
     * @param hintId Id used to optimize finding the place to insert into ob
     */
    function findPrevOfIncomingId(
        mapping(address => mapping(uint16 => STypes.Order)) storage orders,
        address asset,
        STypes.Order memory incomingOrder,
        uint16 hintId
    ) internal view returns (uint16) {
        uint16 nextId = orders[asset][hintId].nextId;

        // if invalid hint (if the id points to 0 then it's an empty id)
        if (hintId == 0 || nextId == 0) {
            return getOrderId(orders, asset, C.NEXT, C.HEAD, incomingOrder.price, incomingOrder.orderType);
        }

        // check if the hint is valid
        int256 direction = verifyId(orders, asset, hintId, incomingOrder.price, nextId, incomingOrder.orderType);

        // if its 0, it's correct
        // otherwise it could be off because a tx could of modified state
        // so search in a direction based on price.
        if (direction == C.EXACT) {
            return hintId;
        } else if (direction == C.NEXT) {
            return getOrderId(orders, asset, C.NEXT, nextId, incomingOrder.price, incomingOrder.orderType);
        } else {
            uint16 prevId = orders[asset][hintId].prevId;
            return getOrderId(orders, asset, C.PREV, prevId, incomingOrder.price, incomingOrder.orderType);
        }
    }

    /**
     * @notice Verifies that an id is between two id based on price and orderType
     *
     * @param asset The market that will be impacted
     * @param prevId The first id supposedly preceding the new price
     * @param newPrice price of prospective order
     * @param nextId The first id supposedly following the new price
     * @param orderType order type (bid, ask, short)
     *
     * @return direction int direction to search (PREV, EXACT, NEXT)
     */
    function verifyId(
        mapping(address => mapping(uint16 => STypes.Order)) storage orders,
        address asset,
        uint16 prevId,
        uint256 newPrice,
        uint16 nextId,
        O orderType
    ) internal view returns (int256 direction) {
        orderType = normalizeOrderType(orderType);

        if (orderType == O.LimitAsk || orderType == O.LimitShort) {
            return verifySellId(orders, asset, prevId, newPrice, nextId);
        } else if (orderType == O.LimitBid) {
            return verifyBidId(asset, prevId, newPrice, nextId);
        }
    }

    // @dev not used to change state, just which methods to call
    function normalizeOrderType(O o) private pure returns (O newO) {
        if (o == O.LimitBid || o == O.MarketBid) {
            return O.LimitBid;
        } else if (o == O.LimitAsk || o == O.MarketAsk) {
            return O.LimitAsk;
        } else if (o == O.LimitShort) {
            return O.LimitShort;
        }
    }

    /**
     * @notice Helper function for finding and returning id of potential order
     *
     * @param orders the order mapping
     * @param asset The market that will be impacted
     * @param direction int direction to search (PREV, EXACT, NEXT)
     * @param hintId hint id
     * @param _newPrice price of prospective order used to find the id
     * @param orderType which OrderType to verify
     */
    function getOrderId(
        mapping(address => mapping(uint16 => STypes.Order)) storage orders,
        address asset,
        int256 direction,
        uint16 hintId,
        uint256 _newPrice,
        O orderType
    ) internal view returns (uint16 _hintId) {
        while (true) {
            uint16 nextId = orders[asset][hintId].nextId;

            if (verifyId(orders, asset, hintId, _newPrice, nextId, orderType) == C.EXACT) {
                return hintId;
            }

            if (direction == C.PREV) {
                uint16 prevId = orders[asset][hintId].prevId;
                hintId = prevId;
            } else {
                hintId = nextId;
            }
        }
    }

    /**
     * @notice Helper function for updating the bids mapping when matched
     * @dev More efficient way to remove matched orders. Instead
     * @dev Instead of canceling each one, just wait till the last match and only swap prevId/nextId there, since the rest are gone
     *
     * @param orders The market that will be impacted
     * @param asset The market that will be impacted
     * @param id Most recent matched Bid
     * @param isOrderFullyFilled Boolean to see if full or partial
     */
    function updateBidOrdersOnMatch(
        mapping(address => mapping(uint16 => STypes.Order)) storage orders,
        address asset,
        uint16 id,
        bool isOrderFullyFilled
    ) internal {
        // BEFORE: HEAD <-> ... <-> (ID) <-> NEXT
        // AFTER : HEAD <------------------> NEXT
        if (isOrderFullyFilled) {
            _updateOrders(orders, asset, C.HEAD, id);
        } else {
            // BEFORE: HEAD <-> ... <-> (ID)
            // AFTER : HEAD <---------> (ID)
            orders[asset][id].prevId = C.HEAD;
            orders[asset][C.HEAD].nextId = id;
        }
    }

    /**
     * @notice Helper function for updating the asks/shorts mapping when matched by incomingBid
     * @dev firstShortId isn't necessarily HEAD because orders start matching from oracle price
     *
     * @param asset The market that will be impacted
     * @param b Memory based struct passed from BidMatchAlgo
     */
    function updateSellOrdersOnMatch(address asset, MTypes.BidMatchAlgo memory b) internal {
        AppStorage storage s = appStorage();
        if (b.matchedAskId != 0) {
            _updateOrders(s.asks, asset, C.HEAD, b.matchedAskId);
        }

        if (b.matchedShortId != 0) {
            if (!b.isMovingBack && !b.isMovingFwd) {
                // @dev Handles only matching one thing
                // @dev If does not get fully matched, b.matchedShortId == 0 and therefore not hit this block
                _updateOrders(s.shorts, asset, b.prevShortId, b.matchedShortId);
            } else if (!b.isMovingBack && b.isMovingFwd) {
                // @dev Handles moving forward only
                _updateOrders(s.shorts, asset, b.firstShortIdBelowOracle, b.matchedShortId);
            } else if (b.isMovingBack && !b.isMovingFwd) {
                //@handles moving backwards only.
                _updateOrders(s.shorts, asset, b.prevShortId, b.shortHintId);
            } else if (b.isMovingBack && b.isMovingFwd) {
                uint16 id = b.prevShortId == b.firstShortIdBelowOracle ? b.shortHintId : b.matchedShortId;
                // @dev Handle going backward and forward
                _updateOrders(s.shorts, asset, b.firstShortIdBelowOracle, id);
            }
        }
    }

    /**
     * @notice Base helper function for updating any kind of orders
     *
     * @param orders the order mapping
     * @param asset The market that will be impacted
     * @param headId Either HEAD or first SHORT with price >= oracle price
     * @param lastMatchedId Most recent matched SHORT in a specific Bid transaction
     */
    function _updateOrders(
        mapping(address => mapping(uint16 => STypes.Order)) storage orders,
        address asset,
        uint16 headId,
        uint16 lastMatchedId
    ) private {
        // BEFORE: FIRST <-> ... <-> (LAST) <-> NEXT
        // AFTER : FIRST <--------------------> NEXT
        uint16 nextAskId = orders[asset][lastMatchedId].nextId;
        if (nextAskId != C.TAIL) {
            orders[asset][nextAskId].prevId = headId;
        }
        orders[asset][headId].nextId = nextAskId;
    }

    /**
     * @notice The matching algorithm for asks
     *
     * @param asset The market that will be impacted
     * @param incomingAsk Newly created ask struct
     * @param orderHintArray Id passed in from front end for optimized looping
     * @param minAskEth Minimum ask dust amount
     *
     */
    function sellMatchAlgo(
        address asset,
        STypes.Order memory incomingAsk,
        MTypes.OrderHint[] memory orderHintArray,
        uint256 minAskEth
    ) internal {
        AppStorage storage s = appStorage();
        uint16 startingId = s.bids[asset][C.HEAD].nextId;
        if (incomingAsk.price > s.bids[asset][startingId].price) {
            if (incomingAsk.ercAmount.mul(incomingAsk.price) >= minAskEth) {
                addSellOrder(incomingAsk, asset, orderHintArray);
            }
            return;
        }
        // matching loop starts
        MTypes.Match memory matchTotal;
        while (true) {
            STypes.Order memory highestBid = s.bids[asset][startingId];
            if (incomingAsk.price <= highestBid.price) {
                // Consider ask filled if only dust amount left
                if (incomingAsk.ercAmount.mul(highestBid.price) == 0) {
                    updateBidOrdersOnMatch(s.bids, asset, highestBid.id, false);
                    incomingAsk.ercAmount = 0;
                    matchIncomingSell(asset, incomingAsk, matchTotal);
                    return;
                }
                matchHighestBid(incomingAsk, highestBid, asset, matchTotal);
                if (incomingAsk.ercAmount > highestBid.ercAmount) {
                    incomingAsk.ercAmount -= highestBid.ercAmount;
                    highestBid.ercAmount = 0;
                    matchOrder(s.bids, asset, highestBid.id);

                    // loop
                    startingId = highestBid.nextId;
                    if (startingId == C.TAIL) {
                        matchIncomingSell(asset, incomingAsk, matchTotal);

                        if (incomingAsk.ercAmount.mul(incomingAsk.price) >= minAskEth) {
                            addSellOrder(incomingAsk, asset, orderHintArray);
                        }
                        s.bids[asset][C.HEAD].nextId = C.TAIL;
                        return;
                    }
                } else {
                    if (incomingAsk.ercAmount == highestBid.ercAmount) {
                        matchOrder(s.bids, asset, highestBid.id);
                        updateBidOrdersOnMatch(s.bids, asset, highestBid.id, true);
                    } else {
                        highestBid.ercAmount -= incomingAsk.ercAmount;
                        s.bids[asset][highestBid.id].ercAmount = highestBid.ercAmount;
                        updateBidOrdersOnMatch(s.bids, asset, highestBid.id, false);
                        // Check reduced dust threshold for existing limit orders
                        if (highestBid.ercAmount.mul(highestBid.price) < LibAsset.minBidEth(asset).mul(C.DUST_FACTOR)) {
                            cancelBid(asset, highestBid.id);
                        }
                    }
                    incomingAsk.ercAmount = 0;
                    matchIncomingSell(asset, incomingAsk, matchTotal);
                    return;
                }
            } else {
                updateBidOrdersOnMatch(s.bids, asset, highestBid.id, false);
                matchIncomingSell(asset, incomingAsk, matchTotal);

                if (incomingAsk.ercAmount.mul(incomingAsk.price) >= minAskEth) {
                    addSellOrder(incomingAsk, asset, orderHintArray);
                }
                return;
            }
        }
    }

    function matchIncomingSell(address asset, STypes.Order memory incomingOrder, MTypes.Match memory matchTotal) private {
        O o = normalizeOrderType(incomingOrder.orderType);

        emit Events.MatchOrder(
            asset, incomingOrder.addr, incomingOrder.orderType, incomingOrder.id, matchTotal.fillEth, matchTotal.fillErc
        );

        if (o == O.LimitShort) {
            matchIncomingShort(asset, incomingOrder, matchTotal);
        } else if (o == O.LimitAsk) {
            matchIncomingAsk(asset, incomingOrder, matchTotal);
        }

        // @dev match price is based on the order that was already on orderbook
        LibOrders.handlePriceDiscount(asset, matchTotal.lastMatchPrice);
    }

    /**
     * @notice Final settlement of incoming ask
     *
     * @param asset The market that will be impacted
     * @param incomingAsk Newly created ask struct
     * @param matchTotal Struct of the running matched totals
     */
    function matchIncomingAsk(address asset, STypes.Order memory incomingAsk, MTypes.Match memory matchTotal) private {
        AppStorage storage s = appStorage();
        uint256 vault = s.asset[asset].vault;
        address asker = incomingAsk.addr;
        s.assetUser[asset][asker].ercEscrowed -= matchTotal.fillErc;
        s.vaultUser[vault][asker].ethEscrowed += matchTotal.fillEth;
        s.vault[vault].dittoMatchedShares += matchTotal.dittoMatchedShares;
    }

    /**
     * @notice Final settlement of incoming short
     *
     * @param asset The market that will be impacted
     * @param incomingShort Newly created short struct
     * @param matchTotal Struct of the running matched totals
     */
    function matchIncomingShort(address asset, STypes.Order memory incomingShort, MTypes.Match memory matchTotal) private {
        AppStorage storage s = appStorage();
        STypes.Asset storage Asset = s.asset[asset];
        uint256 vault = Asset.vault;
        STypes.Vault storage Vault = s.vault[vault];

        s.vaultUser[vault][incomingShort.addr].ethEscrowed -= matchTotal.colUsed;
        matchTotal.fillEth += matchTotal.colUsed;

        SR status = incomingShort.ercAmount == 0 ? SR.FullyFilled : SR.PartialFill;

        LibShortRecord.fillShortRecord(
            asset,
            incomingShort.addr,
            incomingShort.shortRecordId,
            status,
            matchTotal.fillEth,
            matchTotal.fillErc,
            Asset.ercDebtRate,
            Vault.dethYieldRate
        );

        Vault.dittoMatchedShares += matchTotal.dittoMatchedShares;
        Vault.dethCollateral += matchTotal.fillEth;
        Asset.dethCollateral += matchTotal.fillEth;
        Asset.ercDebt += matchTotal.fillErc;
    }

    /**
     * @notice Settles highest bid and updates incoming Ask or Short
     * @dev DittoMatchedShares only assigned for bids sitting > 2 weeks of seconds
     *
     * @param incomingSell Newly created Ask or Short
     * @param highestBid Highest bid (first bid) in the sorted bid
     * @param asset The market that will be impacted
     * @param matchTotal Struct of the running matched totals
     */
    function matchHighestBid(
        STypes.Order memory incomingSell,
        STypes.Order memory highestBid,
        address asset,
        MTypes.Match memory matchTotal
    ) internal {
        AppStorage storage s = appStorage();
        uint88 fillErc = incomingSell.ercAmount > highestBid.ercAmount ? highestBid.ercAmount : incomingSell.ercAmount;
        uint88 fillEth = highestBid.price.mulU88(fillErc);

        increaseSharesOnMatch(asset, highestBid, matchTotal, fillEth);

        if (incomingSell.orderType == O.LimitShort) {
            matchTotal.colUsed += incomingSell.price.mulU88(fillErc).mulU88(LibOrders.convertCR(incomingSell.shortOrderCR));
        }
        matchTotal.fillErc += fillErc;
        matchTotal.fillEth += fillEth;
        matchTotal.lastMatchPrice = highestBid.price;

        // @dev this happens at the end so fillErc isn't affected in previous calculations
        s.assetUser[asset][highestBid.addr].ercEscrowed += fillErc;
    }

    function _updateOracleAndStartingShort(address asset, uint16[] memory shortHintArray) private {
        AppStorage storage s = appStorage();
        uint256 oraclePrice = LibOracle.getOraclePrice(asset);
        uint256 savedPrice = asset.getPrice();
        asset.setPriceAndTime(oraclePrice, getOffsetTime());
        if (oraclePrice == savedPrice) {
            return; // no need to update startingShortId
        }

        STypes.Asset storage Asset = s.asset[asset];
        bool shortOrdersIsEmpty = s.shorts[asset][C.HEAD].nextId == C.TAIL;
        if (shortOrdersIsEmpty) {
            Asset.startingShortId = C.HEAD;
        } else {
            uint16 shortHintId;
            for (uint256 i = 0; i < shortHintArray.length;) {
                shortHintId = shortHintArray[i];
                unchecked {
                    ++i;
                }

                STypes.Order storage short = s.shorts[asset][shortHintId];
                {
                    O shortOrderType = short.orderType;
                    if (shortOrderType == O.Cancelled || shortOrderType == O.Matched || shortOrderType == O.Uninitialized) {
                        continue;
                    }
                }

                uint80 shortPrice = short.price;
                uint16 prevId = short.prevId;
                uint80 prevShortPrice = s.shorts[asset][prevId].price;
                // @dev force hint to be within 0.5% of oraclePrice
                bool startingShortWithinOracleRange = shortPrice <= oraclePrice.mul(1.005 ether) && prevShortPrice >= oraclePrice;
                bool isExactStartingShort = shortPrice >= oraclePrice && prevShortPrice < oraclePrice;
                bool allShortUnderOraclePrice = shortPrice < oraclePrice && short.nextId == C.TAIL;

                if (isExactStartingShort) {
                    Asset.startingShortId = shortHintId;
                    return;
                } else if (startingShortWithinOracleRange) {
                    // @dev prevShortPrice >= oraclePrice
                    Asset.startingShortId = prevId;
                    return;
                } else if (allShortUnderOraclePrice) {
                    Asset.startingShortId = C.HEAD;
                    return;
                }
            }

            revert Errors.BadShortHint();
        }
    }

    // @dev Update on match if order matches and price diff between order price and oracle > chainlink threshold (i.e. eth .5%)
    function updateOracleAndStartingShortViaThreshold(
        address asset,
        uint256 savedPrice,
        STypes.Order memory incomingOrder,
        uint16[] memory shortHintArray
    ) internal {
        bool orderPriceGtThreshold;
        // @dev handle .5% deviations in either directions
        if (incomingOrder.price >= savedPrice) {
            orderPriceGtThreshold = (incomingOrder.price - savedPrice).div(savedPrice) > 0.005 ether;
        } else {
            orderPriceGtThreshold = (savedPrice - incomingOrder.price).div(savedPrice) > 0.005 ether;
        }

        if (orderPriceGtThreshold) {
            _updateOracleAndStartingShort(asset, shortHintArray);
        }
    }

    // @dev Possible for this function to never get called if updateOracleAndStartingShortViaThreshold() gets called often enough
    function updateOracleAndStartingShortViaTimeBidOnly(address asset, uint16[] memory shortHintArray) internal {
        uint256 timeDiff = getOffsetTime() - LibOracle.getTime(asset);
        if (timeDiff >= 15 minutes) {
            _updateOracleAndStartingShort(asset, shortHintArray);
        }
    }

    function updateStartingShortIdViaShort(address asset, STypes.Order memory incomingShort) internal {
        AppStorage storage s = appStorage();
        STypes.Asset storage Asset = s.asset[asset];
        uint256 savedPrice = LibOracle.getPrice(asset);
        uint256 startingShortPrice = s.shorts[asset][Asset.startingShortId].price;
        bool shortOrdersIsEmpty = s.shorts[asset][C.HEAD].nextId == C.TAIL;

        if (shortOrdersIsEmpty || Asset.startingShortId == C.HEAD) {
            if (incomingShort.price >= savedPrice) {
                Asset.startingShortId = incomingShort.id;
            }
        } else if (incomingShort.price < startingShortPrice && incomingShort.price >= savedPrice) {
            Asset.startingShortId = incomingShort.id;
        }
    }

    function findOrderHintId(
        mapping(address => mapping(uint16 => STypes.Order)) storage orders,
        address asset,
        MTypes.OrderHint[] memory orderHintArray
    ) internal view returns (uint16 hintId) {
        bool anyOrderHintPrevMatched;
        for (uint256 i; i < orderHintArray.length; i++) {
            MTypes.OrderHint memory orderHint = orderHintArray[i];
            STypes.Order storage order = orders[asset][orderHint.hintId];
            O hintOrderType = order.orderType;
            if (hintOrderType == O.Cancelled || hintOrderType == O.Matched) {
                continue;
            } else if (order.creationTime == orderHint.creationTime) {
                return orderHint.hintId;
            } else if (!anyOrderHintPrevMatched && order.prevOrderType == O.Matched) {
                anyOrderHintPrevMatched = true;
            }
        }

        if (anyOrderHintPrevMatched) {
            // @dev If hint was prev matched, assume that hint was close to HEAD and therefore is reasonable to use HEAD
            return C.HEAD;
        }

        revert Errors.BadHintIdArray();
    }

    // Helper Functions for cancelling orders
    function cancelBid(address asset, uint16 id) internal {
        AppStorage storage s = appStorage();
        STypes.Order storage bid = s.bids[asset][id];

        O orderType = bid.orderType;
        if (orderType == O.Cancelled || orderType == O.Matched) revert Errors.NotActiveOrder();

        uint256 vault = s.asset[asset].vault;
        uint88 eth = bid.ercAmount.mulU88(bid.price);
        s.vaultUser[vault][bid.addr].ethEscrowed += eth;

        cancelOrder(s.bids, asset, id);
    }

    function cancelAsk(address asset, uint16 id) internal {
        AppStorage storage s = appStorage();
        STypes.Order storage ask = s.asks[asset][id];

        O orderType = ask.orderType;
        if (orderType == O.Cancelled || orderType == O.Matched) {
            revert Errors.NotActiveOrder();
        }

        s.assetUser[asset][ask.addr].ercEscrowed += ask.ercAmount;

        cancelOrder(s.asks, asset, id);
    }

    function cancelShort(address asset, uint16 id) internal {
        AppStorage storage s = appStorage();
        STypes.Order storage shortOrder = s.shorts[asset][id];

        O orderType = shortOrder.orderType;
        if (orderType == O.Cancelled || orderType == O.Matched) revert Errors.NotActiveOrder();

        uint88 eth = shortOrder.ercAmount.mulU88(shortOrder.price).mulU88(LibOrders.convertCR(shortOrder.shortOrderCR));

        STypes.Asset storage Asset = s.asset[asset];
        uint256 vault = Asset.vault;

        uint8 shortRecordId = shortOrder.shortRecordId;
        address shorter = shortOrder.addr;
        STypes.ShortRecord storage shortRecord = s.shortRecords[asset][shorter][shortRecordId];

        if (shortRecord.status == SR.Closed) {
            // @dev creating shortOrder automatically creates a closed shortRecord which also sets a shortRecordId
            // @dev cancelling an unmatched order needs to also handle/recycle the shortRecordId
            LibShortRecord.deleteShortRecord(asset, shorter, shortRecordId);
        } else {
            uint88 minShortErc = uint88(LibAsset.minShortErc(asset));
            if (shortRecord.ercDebt < minShortErc) {
                // @dev prevents leaving behind a partially filled SR is under minShortErc
                // @dev if the corresponding short is cancelled, then the partially filled SR's debt will == minShortErc
                uint88 debtDiff = minShortErc - shortRecord.ercDebt;
                {
                    STypes.Vault storage Vault = s.vault[vault];

                    uint88 collateralDiff = shortOrder.price.mulU88(debtDiff).mulU88(LibOrders.convertCR(shortOrder.shortOrderCR));

                    LibShortRecord.fillShortRecord(
                        asset,
                        shorter,
                        shortRecordId,
                        SR.FullyFilled,
                        collateralDiff,
                        debtDiff,
                        Asset.ercDebtRate,
                        Vault.dethYieldRate
                    );

                    Vault.dethCollateral += collateralDiff;
                    Asset.dethCollateral += collateralDiff;
                    Asset.ercDebt += debtDiff;

                    // @dev update the eth refund amount
                    eth -= collateralDiff;
                }
                // @dev virtually mint the increased debt
                s.assetUser[asset][shorter].ercEscrowed += debtDiff;
            } else {
                shortRecord.status = SR.FullyFilled;
            }
        }

        s.vaultUser[vault][shorter].ethEscrowed += eth;

        // Approximating the startingShortId, rather than expecting exact match
        if (id == Asset.startingShortId) {
            uint256 savedPrice = LibOracle.getPrice(asset);
            uint256 prevPrice = s.shorts[asset][shortOrder.prevId].price;
            if (prevPrice >= savedPrice) {
                Asset.startingShortId = shortOrder.prevId;
            } else {
                Asset.startingShortId = shortOrder.nextId;
            }
        }

        cancelOrder(s.shorts, asset, id);
    }

    // Approximates the match price compared to the oracle price and accounts for any discount by increasing dethTithePercent
    function handlePriceDiscount(address asset, uint80 price) internal {
        AppStorage storage s = appStorage();
        uint256 vault = s.asset[asset].vault;
        STypes.Vault storage Vault = s.vault[vault];
        uint256 savedPrice = LibOracle.getPrice(asset);
        bool isDiscounted = savedPrice > price.mul(1.01 ether);

        // @dev tithe is increased only if discount is greater than 1%
        if (isDiscounted) {
            // @dev bound the new tithe amount between 25% and 100%
            uint256 discountPct = max(0.01 ether, min(((savedPrice - price).div(savedPrice)), 0.04 ether));

            // @dev Vault.dethTitheMod is added onto Vault.dethTithePercent to get tithe amount
            Vault.dethTitheMod = (C.MAX_TITHE - Vault.dethTithePercent).mulU16(discountPct.div(0.04 ether));
        } else {
            // @dev dethTitheMod is only set when setTithe is called.
            bool titheWasChanged = Vault.dethTitheMod != C.INITIAL_TITHE_MOD;

            if (titheWasChanged) {
                // @dev change back to original tithe percent
                Vault.dethTitheMod = C.INITIAL_TITHE_MOD;
            } else {
                return;
            }
        }

        // @dev exists because of ShortOrderFacet contract size
        IDiamond(payable(address(this)))._updateYieldDiamond(vault);
    }

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }
}
