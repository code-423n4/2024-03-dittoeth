// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {GasHelper} from "test-gas/GasHelper.sol";

contract GasVaultTest is GasHelper {
    using U256 for uint256;

    function setUp() public override {
        super.setUp();
        uint88 amount = 1000 ether;
        uint256 preBal = dusd.balanceOf(sender);
        // transfer remainder balance
        vm.prank(sender);
        dusd.transfer(receiver, preBal);

        vm.prank(_diamond);
        dusd.mint(sender, amount);

        assertEq(dusd.balanceOf(sender), amount);

        //for withdraw
        ob.depositEth(sender, amount);
        ob.depositUsd(sender, amount);
    }

    function testGas_DepositAssetDUSD() public {
        address _dusd = address(dusd);
        vm.startPrank(sender);
        startMeasuringGas("Vault-DepositAsset-DUSD");
        diamond.depositAsset(_dusd, 500 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }

    function testGas_WithdrawAssetDUSD() public {
        address _dusd = address(dusd);
        vm.startPrank(sender);
        startMeasuringGas("Vault-WithdrawAsset-DUSD");
        diamond.withdrawAsset(_dusd, 500 ether);
        stopMeasuringGas();
        vm.stopPrank();
    }
}
