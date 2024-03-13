// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {ForkHelper} from "test/fork/ForkHelper.sol";
import {VAULT} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract BridgeForkTest is ForkHelper {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public virtual override {
        forkBlock = 17_787_931; // @dev need earlier block where deposit pool has space
        super.setUp();
        deal(sender, 1000 ether);
        assertEq(sender.balance, 1000 ether);
        assertEq(diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed, 0);
    }

    function testFork_RethIntegration_Eth() public {
        uint256 initialDeposit = 100 ether;

        vm.startPrank(sender);
        assertEq(reth.balanceOf(sender), 0);
        assertEq(reth.balanceOf(_bridgeReth), 0);

        diamond.depositEth{value: initialDeposit}(_bridgeReth);

        //rocketpool reth deposit fee = 5 bps
        uint256 rethDepositFee = initialDeposit.mul(0.0005 ether);
        uint256 dethMinted = initialDeposit - rethDepositFee;

        assertEq(reth.balanceOf(_bridgeReth), reth.getRethValue(dethMinted));
        assertEq(sender.balance, 1000 ether - initialDeposit);

        uint88 currentEthEscrowed = diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed;

        assertApproxEqAbs(currentEthEscrowed, dethMinted, MAX_DELTA_SMALL);

        diamond.withdraw(_bridgeReth, currentEthEscrowed);

        assertEq(diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed, 0);
        assertEq(sender.balance, 1000 ether - initialDeposit);
        assertApproxEqAbs(reth.balanceOf(sender), reth.getRethValue(dethMinted), MAX_DELTA_SMALL);
        assertApproxEqAbs(reth.balanceOf(_bridgeReth), 0, MAX_DELTA_SMALL);
    }

    function testFork_RethIntegration_Reth() public {
        uint88 initialDeposit = 100 ether;
        deal(_reth, sender, initialDeposit);

        vm.startPrank(sender);
        assertEq(reth.balanceOf(_bridgeReth), 0);
        assertEq(reth.balanceOf(sender), initialDeposit);

        reth.approve(_bridgeReth, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        diamond.deposit(_bridgeReth, initialDeposit);

        uint256 dethMinted = reth.getEthValue(initialDeposit);

        assertEq(reth.balanceOf(_bridgeReth), initialDeposit);
        assertEq(reth.balanceOf(sender), 0);

        uint88 currentEthEscrowed = diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed;
        assertEq(currentEthEscrowed, dethMinted);

        diamond.withdraw(_bridgeReth, currentEthEscrowed);

        assertEq(diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed, 0);
        assertApproxEqAbs(reth.balanceOf(sender), initialDeposit, MAX_DELTA_SMALL);
        assertApproxEqAbs(reth.balanceOf(_bridgeReth), 0, MAX_DELTA_SMALL);
    }

    function testFork_StethIntegration_Eth() public {
        uint256 initialDeposit = 100 ether;
        vm.startPrank(sender);
        assertEq(steth.balanceOf(_bridgeSteth), 0);
        diamond.depositEth{value: initialDeposit}(_bridgeSteth);
        assertApproxEqAbs(steth.balanceOf(_bridgeSteth), initialDeposit, MAX_DELTA_SMALL);
        assertEq(sender.balance, 1000 ether - initialDeposit);

        uint88 currentEthEscrowed = diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed;
        assertApproxEqAbs(currentEthEscrowed, initialDeposit, MAX_DELTA_SMALL);

        diamond.withdraw(_bridgeSteth, currentEthEscrowed);
        assertEq(diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed, 0);
        assertApproxEqAbs(steth.balanceOf(_bridgeSteth), 0, MAX_DELTA_SMALL);
        assertApproxEqAbs(steth.balanceOf(sender), initialDeposit, MAX_DELTA_SMALL);
    }

    function testFork_StethIntegration_Steth() public {
        uint88 initialDeposit = 100 ether;
        vm.startPrank(sender);

        steth.submit{value: initialDeposit}(address(0));
        steth.approve(_bridgeSteth, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        assertEq(sender.balance, 1000 ether - initialDeposit);
        assertApproxEqAbs(steth.balanceOf(sender), initialDeposit, MAX_DELTA_SMALL);
        assertEq(steth.balanceOf(_bridgeSteth), 0);

        diamond.deposit(_bridgeSteth, initialDeposit);
        assertEq(steth.balanceOf(sender), 0);
        assertApproxEqAbs(steth.balanceOf(_bridgeSteth), initialDeposit, MAX_DELTA_SMALL);

        uint88 currentEthEscrowed = diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed;
        assertApproxEqAbs(currentEthEscrowed, initialDeposit, MAX_DELTA_SMALL);
        assertEq(unsteth.balanceOf(sender), 0);

        diamond.withdraw(_bridgeSteth, currentEthEscrowed);

        assertEq(diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed, 0);
        assertApproxEqAbs(steth.balanceOf(sender), initialDeposit, MAX_DELTA_SMALL);
        assertApproxEqAbs(steth.balanceOf(_bridgeSteth), 0, MAX_DELTA_SMALL);
    }
}
