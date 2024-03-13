// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors, stdError, IDiamondCut, RemovedFunctions, RemoveFunctions01} from "./01_remove_functions.s.sol";

contract RemoveFunctions01Test is RemoveFunctions01 {
    function setUp() public {
        fork(18743674);
    }

    function testFork_Migration_01() public {
        RemovedFunctions removedFunctions = RemovedFunctions(_diamond);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        removedFunctions.depositDETH(_deth, 1 ether);

        vm.expectRevert(Errors.InsufficientETHEscrowed.selector);
        removedFunctions.withdrawDETH(_deth, 1 ether);

        vm.expectRevert(stdError.arithmeticError);
        removedFunctions.unstakeEth(_bridgeSteth, 1 ether);

        facetCut.push(removeFacetCut);
        vm.prank(_safeWallet);
        diamond.diamondCut(facetCut, address(0), "");

        vm.expectRevert(abi.encodeWithSignature("FunctionNotFound(bytes4)", RemovedFunctions.depositDETH.selector));
        removedFunctions.depositDETH(_deth, 1 ether);

        vm.expectRevert(abi.encodeWithSignature("FunctionNotFound(bytes4)", RemovedFunctions.withdrawDETH.selector));
        removedFunctions.withdrawDETH(_deth, 1 ether);

        vm.expectRevert(abi.encodeWithSignature("FunctionNotFound(bytes4)", RemovedFunctions.unstakeEth.selector));
        removedFunctions.unstakeEth(_bridgeSteth, 1 ether);
    }
}
