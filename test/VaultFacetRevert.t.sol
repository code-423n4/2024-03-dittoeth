// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors} from "contracts/libraries/Errors.sol";

import {OBFixture} from "test/utils/OBFixture.sol";

contract VaultFacetRevertTest is OBFixture {
    function test_CannotDepositOtherTokenType() public {
        vm.expectRevert(Errors.InvalidAsset.selector);
        diamond.depositAsset(randomAddr, 1 ether);
    }

    function test_CannotWithdrawOtherTokenType() public {
        vm.expectRevert(Errors.InvalidAsset.selector);
        diamond.withdrawAsset(randomAddr, 1 ether);
    }

    function test_CannotDepositZero() public {
        vm.expectRevert(Errors.PriceOrAmountIs0.selector);
        diamond.depositAsset(_dusd, 0);
    }

    function test_CannotWithdrawZero() public {
        vm.expectRevert(Errors.PriceOrAmountIs0.selector);
        diamond.withdrawAsset(asset, 0);
    }

    function test_CannotWithdrawMoreERCThanBalance() public {
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        diamond.withdrawAsset(asset, 2 wei);
    }
}
