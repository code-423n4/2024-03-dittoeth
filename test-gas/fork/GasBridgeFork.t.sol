// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {GasForkHelper} from "test-gas/fork/GasForkHelper.sol";

contract GasForkBridge is GasForkHelper {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();
    }

    function testFork_GasDepositTokenETHtoRETH() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-ETHtoRETH");
        diamond.depositEth{value: 1 ether}(bridgeReth);
        stopMeasuringGas();
    }

    function testFork_GasDepositTokenETHtoRETHLarge() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-ETHtoRETH-Large");
        diamond.depositEth{value: 100 ether}(bridgeReth);
        stopMeasuringGas();
    }

    function testFork_GasDepositTokenETHtoSTETH() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-ETHtoSTETH");
        diamond.depositEth{value: 1 ether}(bridgeSteth);
        stopMeasuringGas();
    }

    function testFork_GasDepositTokenETHtoSTETHLarge() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-ETHtoSTETH-Large");
        diamond.depositEth{value: 100 ether}(bridgeSteth);
        stopMeasuringGas();
    }

    function testFork_GasDepositTokenRETH() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-RETH");
        diamond.deposit(bridgeReth, 1 ether);
        stopMeasuringGas();
    }

    function testFork_GasDepositTokenRETHLarge() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-RETH-Large");
        diamond.deposit(bridgeReth, 100 ether);
        stopMeasuringGas();
    }

    function testFork_GasDepositTokenSTETH() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-STETH");
        diamond.deposit(bridgeSteth, 1 ether);
        stopMeasuringGas();
    }

    function testFork_GasDepositTokenSTETHLarge() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-DepositToken-STETH-Large");
        diamond.deposit(bridgeSteth, 100 ether);
        stopMeasuringGas();
    }
}

contract GasForkBridgeWithdrawWithCreditTest is GasForkBridge {
    using U256 for uint256;

    function testFork_GasWithdrawRETH() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-Withdraw-RETH");
        diamond.withdraw(bridgeReth, 1 ether);
        stopMeasuringGas();
    }

    function testFork_GasWithdrawSTETH() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-Withdraw-STETH");
        diamond.withdraw(bridgeSteth, 1 ether);
        stopMeasuringGas();
    }
}

contract GasForkBridgeWithdrawPastCreditTest is GasForkBridge {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();
        diamond.setBridgeCredit(sender, 0, 0);
    }

    function testFork_GasWithdrawRETHPastCredit() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-Withdraw-RETH-No-Credit");
        diamond.withdraw(bridgeReth, 1 ether);
        stopMeasuringGas();
    }

    function testFork_GasWithdrawSTETHPastCredit() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(sender);
        startMeasuringGas("Bridge-Withdraw-STETH-No-Credit");
        diamond.withdraw(bridgeSteth, 1 ether);
        stopMeasuringGas();
    }
}

contract GasForkBridgeWithdrawTappTest is GasForkBridge {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();
        diamond.setEthEscrowed(_diamond, 1 ether);
        // Seed TAPP with nonzero to get steady state gas cost
        deal(_reth, owner, 1 ether);
        deal(owner, 1 ether);
        vm.prank(owner);
        steth.submit{value: 1 ether}(address(0));
    }

    function testFork_GasWithdrawTappRETH() public {
        address bridgeReth = _bridgeReth;
        vm.startPrank(owner);
        startMeasuringGas("Bridge-WithdrawTapp-RETH");
        diamond.withdrawTapp(bridgeReth, 1 ether);
        stopMeasuringGas();
    }

    function testFork_GasWithdrawTappSTETH() public {
        address bridgeSteth = _bridgeSteth;
        vm.startPrank(owner);
        startMeasuringGas("Bridge-WithdrawTapp-STETH");
        diamond.withdrawTapp(bridgeSteth, 1 ether);
        stopMeasuringGas();
    }
}
