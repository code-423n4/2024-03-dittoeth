// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {InvariantsBase} from "./InvariantsBase.sol";
import {Handler} from "./Handler.sol";

/* solhint-disable */
/// @dev This contract deploys the target contract, the Handler, adds the Handler's actions to the invariant fuzzing
/// @dev targets, then defines invariants that should always hold throughout any invariant run.
/// @dev Similar to InvariantsOrderBook but with a greater focus on yield
contract InvariantsYield is InvariantsBase {
    function setUp() public override {
        super.setUp();

        //@dev duplicate the selector to increase the distribution of certain handler calls
        selectors = [
            // Bridge
            Handler.deposit.selector,
            Handler.deposit.selector,
            Handler.deposit.selector,
            Handler.depositEth.selector,
            Handler.depositEth.selector,
            Handler.depositEth.selector,
            Handler.withdraw.selector,
            // OrderBook
            Handler.createLimitBid.selector,
            Handler.createLimitBid.selector,
            Handler.createLimitBid.selector,
            Handler.createLimitAsk.selector,
            Handler.createLimitShort.selector,
            Handler.createLimitShort.selector,
            Handler.createLimitShort.selector,
            Handler.createLimitShort.selector,
            Handler.cancelOrder.selector,
            // Yield
            Handler.fakeYield.selector,
            Handler.fakeYield.selector,
            Handler.distributeYield.selector,
            Handler.distributeYield.selector,
            Handler.distributeYieldAll.selector,
            Handler.claimDittoMatchedReward.selector,
            Handler.claimDittoMatchedRewardAll.selector,
            // Vault
            Handler.withdrawAsset.selector,
            Handler.withdrawDittoReward.selector,
            Handler.withdrawDittoRewardAll.selector,
            // Short
            Handler.secondaryLiquidation.selector,
            Handler.primaryLiquidation.selector,
            Handler.exitShort.selector,
            Handler.increaseCollateral.selector,
            Handler.decreaseCollateral.selector,
            Handler.combineShorts.selector
        ];

        targetSelector(FuzzSelector({addr: address(s_handler), selectors: selectors}));
        targetContract(address(s_handler));
    }

    function statefulFuzz_dittoReward() public {
        dittoReward();
    }
}
