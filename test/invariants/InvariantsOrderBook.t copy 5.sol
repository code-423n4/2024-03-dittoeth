// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {InvariantsBase} from "./InvariantsBase.sol";

/* solhint-disable */
/// @dev This contract deploys the target contract, the Handler, adds the Handler's actions to the invariant fuzzing
/// @dev targets, then defines invariants that should always hold throughout any invariant run.
contract InvariantsOrderBook is InvariantsBase {
    function setUp() public override {
        super.setUp();

        targetSelector(FuzzSelector({addr: address(s_handler), selectors: selectors}));
        targetContract(address(s_handler));
    }

    function statefulFuzz_askHead() public {
        askHead();
    }
}
