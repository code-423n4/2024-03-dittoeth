// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {C, VAULT} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {OBFixture} from "test/utils/OBFixture.sol";

interface ProcessWithdrawal {
    function processWithdrawal() external;
}

contract VaultFacetTest is OBFixture {
    function setUp() public override {
        super.setUp();
    }

    function test_CanDepositSteth() public {
        assertEq(diamond.getVaultStruct(vault).dethTotal, 0);
        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, 0);
        depositEth(receiver, DEFAULT_AMOUNT);
        assertEq(deth.balanceOf(receiver), 0);
        assertEq(diamond.getVaultStruct(vault).dethTotal, DEFAULT_AMOUNT);
        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, DEFAULT_AMOUNT);
    }

    function test_CanDepositUsd() public {
        assertEq(getTotalErc(), 0 ether);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, 0);
        depositUsd(receiver, DEFAULT_AMOUNT);
        assertEq(token.balanceOf(receiver), 0);
        assertEq(getTotalErc(), DEFAULT_AMOUNT);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, DEFAULT_AMOUNT);
    }

    function test_CanWithdrawUsd() public {
        test_CanDepositUsd();
        vm.prank(receiver);
        diamond.withdrawAsset(asset, DEFAULT_AMOUNT);
        assertEq(token.balanceOf(receiver), DEFAULT_AMOUNT);
        assertEq(getTotalErc(), 0);
        assertEq(diamond.getAssetUserStruct(asset, receiver).ercEscrowed, 0);
    }
}
