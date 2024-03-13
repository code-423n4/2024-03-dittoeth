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

    function statefulFuzz_boundTest() public {
        boundTest();
    }

    // function statefulFuzz_sortedBidsHighestToLowest() public {
    //     sortedBidsHighestToLowest();
    // }

    // function statefulFuzz_sortedAsksLowestToHighest() public {
    //     sortedAsksLowestToHighest();
    // }

    // function statefulFuzz_sortedShortsLowestToHighest() public {
    //     sortedShortsLowestToHighest();
    // }

    // function statefulFuzz_bidHead() public {
    //     bidHead();
    // }

    // function statefulFuzz_askHead() public {
    //     askHead();
    // }

    // function statefulFuzz_shortHead() public {
    //     shortHead();
    // }

    // function statefulFuzz_orderIdGtMarketDepth() public {
    //     orderIdGtMarketDepth();
    // }

    // function statefulFuzz_oracleTimeAlwaysIncrease() public {
    //     oracleTimeAlwaysIncrease();
    // }

    // function statefulFuzz_startingShortPriceGteOraclePrice() public {
    //     startingShortPriceGteOraclePrice();
    // }

    // function statefulFuzz_allOrderIdsUnique() public {
    //     allOrderIdsUnique();
    // }

    // function statefulFuzz_shortRecordExists() public {
    //     shortRecordExists();
    // }

    // function statefulFuzz_Vault_ErcEscrowedPlusAssetBalanceEqTotalDebt() public {
    //     vault_ErcEscrowedPlusAssetBalanceEqTotalDebt();
    // }

    // function statefulFuzz_Vault_DethTotal() public {
    //     vault_DethTotal();
    // }

    // function statefulFuzz_dethCollateralRewardAlwaysIncrease() public {
    //     dethCollateralRewardAlwaysIncrease();
    // }

    // function statefulFuzz_dethYieldRateAlwaysIncrease() public {
    //     dethYieldRateAlwaysIncrease();
    // }

    // function statefulFuzz_dittoMatchedShares() public {
    //     dittoMatchedShares();
    // }

    // // Valid when ditto reward only comes from shorters
    // function statefulFuzz_dittoShorterReward() public {
    //     dittoShorterReward();
    // }
}
