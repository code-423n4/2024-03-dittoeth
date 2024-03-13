// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {OBFixture} from "test/utils/OBFixture.sol";

contract DiamondTest is OBFixture {
    error NotDiamond();

    function setUp() public override {
        super.setUp();
    }

    function test_RevertIfNotDiamondForDITTO() public {
        // works for diamond
        vm.prank(_diamond);
        ditto.mint(sender, 1);

        vm.expectRevert(NotDiamond.selector);
        ditto.mint(sender, 1);

        vm.expectRevert(NotDiamond.selector);
        ditto.burnFrom(sender, 1);
    }

    function test_Asset() public {
        vm.startPrank(_diamond);
        deth.mint(sender, 1);
        deth.burnFrom(sender, 1);

        ditto.mint(sender, 1);
        ditto.burnFrom(sender, 1);

        dusd.mint(sender, 1);
        dusd.burnFrom(sender, 1);
    }

    function test_RevertIfNotDiamondForDETH() public {
        // works for diamond
        vm.prank(_diamond);
        deth.mint(sender, 1);

        vm.expectRevert(NotDiamond.selector);
        deth.mint(sender, 1);

        vm.expectRevert(NotDiamond.selector);
        deth.burnFrom(sender, 1);
    }

    function test_RevertIfNotDiamondForDUSD() public {
        // works for diamond
        vm.prank(_diamond);
        dusd.mint(sender, 1);

        vm.expectRevert(NotDiamond.selector);
        dusd.mint(sender, 1);

        vm.expectRevert(NotDiamond.selector);
        dusd.burnFrom(sender, 1);
    }
}
