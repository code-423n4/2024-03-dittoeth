// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Modifiers} from "contracts/libraries/AppStorage.sol";

//TODO: Add facet, call, than remove
contract ThrowAwayFacet is Modifiers {
    function zeroOutLastRedemption() external onlyDAO {
        s.asset[address(0xD177000a2BC4F4d2246F0527Ad74Fd4140e029fd)].lastRedemptionTime = 0;
    }
}
