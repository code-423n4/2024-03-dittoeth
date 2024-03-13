// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {stdError} from "forge-std/StdError.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {C} from "contracts/libraries/Constants.sol";
import {ForkHelper} from "test/fork/ForkHelper.sol";

contract BridgeRouterRevertTest is ForkHelper {
    function setUp() public virtual override {
        forkBlock = bridgeBlock;
        super.setUp();
    }

    // wrong bridge

    function testFork_RevertIf_DepositEthToBadBridge() public {
        deal(sender, 1 ether);
        vm.startPrank(sender);
        vm.expectRevert(Errors.InvalidBridge.selector);
        diamond.depositEth{value: 1 ether}(address(88));
    }

    function testFork_RevertIf_DepositToBadBridge() public {
        vm.startPrank(sender);
        vm.expectRevert(Errors.InvalidBridge.selector);
        diamond.deposit(address(88), 1 ether);
    }

    function testFork_RevertIf_WithdrawToBadBridge() public {
        vm.startPrank(sender);
        vm.expectRevert(Errors.InvalidBridge.selector);
        diamond.withdraw(address(88), 1 ether);
    }

    function testFork_RevertIf_WithdrawTappToBadBridge() public {
        vm.prank(sender);
        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.withdrawTapp(address(88), 0);

        vm.prank(owner);
        vm.expectRevert(Errors.InvalidBridge.selector);
        diamond.withdrawTapp(address(88), 1 ether);
    }

    // if zero

    function testFork_RevertIf_DepositEthUnderMin() public {
        vm.deal(sender, C.MIN_DEPOSIT);
        vm.startPrank(sender);
        vm.expectRevert(Errors.UnderMinimumDeposit.selector);
        diamond.depositEth{value: C.MIN_DEPOSIT - 1}(_bridgeReth);

        vm.expectRevert(Errors.UnderMinimumDeposit.selector);
        diamond.depositEth{value: C.MIN_DEPOSIT - 1}(_bridgeSteth);
    }

    function testFork_RevertIf_DepositUnderMin() public {
        vm.startPrank(sender);
        vm.expectRevert(Errors.UnderMinimumDeposit.selector);
        diamond.deposit(_bridgeReth, C.MIN_DEPOSIT - 1);

        vm.expectRevert(Errors.UnderMinimumDeposit.selector);
        diamond.deposit(_bridgeSteth, C.MIN_DEPOSIT - 1);
    }

    function testFork_RevertIf_WithdrawZero() public {
        vm.startPrank(sender);
        vm.expectRevert(Errors.ParameterIsZero.selector);
        diamond.withdraw(_bridgeReth, 0);

        vm.expectRevert(Errors.ParameterIsZero.selector);
        diamond.withdraw(_bridgeSteth, 0);
    }

    function testFork_RevertIf_WithdrawTappZero() public {
        vm.startPrank(owner);
        vm.expectRevert(Errors.ParameterIsZero.selector);
        diamond.withdrawTapp(_bridgeReth, 0);

        vm.expectRevert(Errors.ParameterIsZero.selector);
        diamond.withdrawTapp(_bridgeSteth, 0);
    }

    // if not enough token

    function testFork_RevertIf_DepositEthWithoutToken() public {
        vm.startPrank(sender);
        vm.expectRevert();
        diamond.depositEth{value: 1 ether}(_bridgeReth);

        vm.expectRevert();
        diamond.depositEth{value: 1 ether}(_bridgeSteth);
    }

    function testFork_RevertIf_DepositWithoutToken() public {
        vm.startPrank(sender);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        diamond.deposit(_bridgeReth, 1 ether);

        vm.expectRevert("ALLOWANCE_EXCEEDED");
        diamond.deposit(_bridgeSteth, 1 ether);
    }

    function testFork_RevertIf_WithdrawWithoutToken() public {
        vm.startPrank(sender);
        vm.expectRevert(stdError.arithmeticError);
        diamond.withdraw(_bridgeReth, 1 ether);

        vm.expectRevert(stdError.arithmeticError);
        diamond.withdraw(_bridgeSteth, 1 ether);
    }

    function testFork_RevertIf_WithdrawTappWithoutToken() public {
        vm.startPrank(owner);
        vm.expectRevert(stdError.arithmeticError);
        diamond.withdrawTapp(_bridgeReth, 1 ether);

        vm.expectRevert(stdError.arithmeticError);
        diamond.withdrawTapp(_bridgeSteth, 1 ether);
    }

    // if not owner

    function testFork_RevertIf_WithdrawTappNotOwner() public {
        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.withdrawTapp(_bridgeReth, 1 ether);

        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.withdrawTapp(_bridgeSteth, 1 ether);
    }
}
