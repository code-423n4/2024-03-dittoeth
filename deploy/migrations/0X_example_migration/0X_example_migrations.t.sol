// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {
    Errors, stdError, IDiamond, IDiamondCut, ReplacedFunctions, console, ExampleMigration0X
} from "./0X_example_migration.s.sol";

contract ExampleMigration0XTest is ExampleMigration0X {
    function setUp() public virtual override {
        super.setUp();
    }

    //bun run test --match-test test_Migration_03 -vv
    function testFork_Migration_03() public {
        vm.startPrank(_safeWallet);
        address vaultAddress = create2Factory.safeCreate2(SALT, vaultFacetInitcode);
        assertEq(vaultFacetAddress, vaultAddress);

        address oldVaultAddress = diamond.facetAddress(ReplacedFunctions.depositAsset.selector);
        assertNotEq(oldVaultAddress, vaultFacetAddress);

        timelock.schedule(_diamond, 0, diamondCutPayload, bytes32(0), bytes32(0), 0);
        timelock.execute(_diamond, 0, diamondCutPayload, bytes32(0), bytes32(0));
        //add tests for new facet behavior
        assertNotEq(diamond.facetFunctionSelectors(vaultFacetAddress).length, 0);
        assertEq(diamond.facetFunctionSelectors(oldVaultAddress).length, 0);

        uint256 proposalId = governor.propose(targets, values, calldatas, descriptionString);

        //skip 1 day to bypass voting delay
        vm.roll(block.number + 7201);

        //voting yes to proposal as safewallet
        governor.castVote(proposalId, 1);

        //skip 1 week voting period
        vm.roll(block.number + 50_401);

        //queue the proposal on the timelock - must normally go through the timelock wait period, which is currently set to ZERO
        governor.queue(targets, values, calldatas, descriptionHash);

        //execute proposal - set tithe of vault_one from 10% to 11%
        governor.execute(targets, values, calldatas, descriptionHash);

        //test proposal behavior
        assertEq(diamond.getTithe(1), 0.11 ether);

        vm.stopPrank();
    }
}
