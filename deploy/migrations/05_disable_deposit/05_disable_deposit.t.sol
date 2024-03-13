// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {IDiamond, DisableDeposit05} from "./05_disable_deposit.s.sol";

contract DisableDeposit05Test is DisableDeposit05 {
    function setUp() public virtual override {
        super.setUp();
    }

    function testFork_Migration_05() public {
        assertEq(diamond.getDethTotal(1), 0);

        vm.startPrank(address(0xeb37e481050c18A9C86E669cd23cf672e4594339));
        steth.approve(_bridgeSteth, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        diamond.deposit(_bridgeSteth, 1 ether);
        diamond.depositEth{value: 1 ether}(_bridgeSteth);

        vm.startPrank(_safeWallet);
        timelock.schedule(_diamond, 0, diamondCutPayload, bytes32(0), bytes32(0), 0);
        timelock.execute(_diamond, 0, diamondCutPayload, bytes32(0), bytes32(0));

        vm.startPrank(address(0xeb37e481050c18A9C86E669cd23cf672e4594339));
        vm.expectRevert(abi.encodeWithSignature("FunctionNotFound(bytes4)", IDiamond.deposit.selector));
        diamond.deposit(_bridgeSteth, 1 ether);
        vm.expectRevert(abi.encodeWithSignature("FunctionNotFound(bytes4)", IDiamond.depositEth.selector));
        diamond.depositEth{value: 1 ether}(_bridgeSteth);
    }
}
