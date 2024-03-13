// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import "@openzeppelin-v5/contracts/governance/TimelockController.sol";

contract DittoTimelockController is TimelockController {
    constructor(address[] memory proposers, address[] memory executors, address admin)
        //no initial timelock delay - set after bootstrap phase
        TimelockController(0, proposers, executors, admin)
    {}
}
