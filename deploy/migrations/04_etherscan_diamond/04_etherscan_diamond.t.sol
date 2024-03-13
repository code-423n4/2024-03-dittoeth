// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors, stdError, IDiamond, IDiamondCut, console, AddedFunctions, EtherscanDiamond04} from "./04_etherscan_diamond.s.sol";

import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";

contract EtherscanDiamond04Test is EtherscanDiamond04 {
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    function setUp() public virtual override {
        super.setUp();
    }

    function testFork_Migration_04() public {
        vm.startPrank(_safeWallet);

        address _etherscanDiamondImpl = create2Factory.safeCreate2(SALT, etherscanDiamondImplInitC);
        assertEq(_etherscanDiamondImpl, etherscanDiamondImplAddress);

        address _etherscanFacet = create2Factory.safeCreate2(SALT, etherscanFacetInitC);
        assertEq(_etherscanFacet, etherscanFacetAddress);

        assertEq(StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value, address(0));

        timelock.scheduleBatch(targets, values, calldatas, bytes32(0), bytes32(0), 0);
        timelock.executeBatch(targets, values, calldatas, bytes32(0), bytes32(0));

        assertEq(newDiamond.implementation(), _etherscanDiamondImpl);
        vm.stopPrank();
    }
}
