// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors} from "contracts/libraries/Errors.sol";
import {IDiamondCut} from "contracts/interfaces/IDiamondCut.sol";
import {IDiamond} from "interfaces/IDiamond.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {OBFixture} from "test/utils/OBFixture.sol";

interface ITestingFacet {
    function newFunction() external returns (uint256);
}

contract AddFacet {
    function newFunction() external pure returns (uint256) {
        return 1;
    }
}

contract ReplaceFacet {
    function newFunction() external pure returns (uint256) {
        return 2;
    }
}

contract DiamondTest is OBFixture {
    IDiamondCut.FacetCut[] public replaceCut;
    bytes4[] internal replaceVaultFacetSelectors = [IDiamond.withdrawAsset.selector];

    function setUp() public override {
        super.setUp();
    }

    function test_FacetCutAction_Add() public {
        vm.startPrank(owner);

        // create the facet
        AddFacet addFacet = new AddFacet();

        bytes4[] memory testSelectors = new bytes4[](1);
        testSelectors[0] = ITestingFacet.newFunction.selector;

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(addFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: testSelectors
            })
        );

        // check that no function exists
        vm.expectRevert();
        ITestingFacet(_diamond).newFunction();

        IDiamondCut(_diamond).diamondCut(cut, address(0), "");

        assertEq(ITestingFacet(_diamond).newFunction(), 1);
    }

    function test_FacetCutAction_Replace() public {
        vm.startPrank(owner);

        AddFacet addFacet = new AddFacet();

        bytes4[] memory testSelectors = new bytes4[](1);
        testSelectors[0] = ITestingFacet.newFunction.selector;

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(addFacet),
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: testSelectors
            })
        );

        // check that function exists
        IDiamondCut(_diamond).diamondCut(cut, address(0), "");
        assertEq(ITestingFacet(_diamond).newFunction(), 1);

        // create the facet
        ReplaceFacet replaceFacet = new ReplaceFacet();

        cut[0] = (
            IDiamondCut.FacetCut({
                facetAddress: address(replaceFacet),
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: testSelectors
            })
        );

        IDiamondCut(_diamond).diamondCut(cut, address(0), "");
        assertEq(ITestingFacet(_diamond).newFunction(), 2);
    }

    function test_DiamondFacetFunctionRemoved() public {
        //test withdrawAsset before remove
        vm.prank(sender);
        vm.expectRevert(Errors.InsufficientERCEscrowed.selector);
        diamond.withdrawAsset(_dusd, 1 ether);
        assertEq(diamond.facetAddress(IDiamond.withdrawAsset.selector), _vaultFacet);

        //important note: facetAddress is address(0) when removing functions
        replaceCut.push(
            IDiamondCut.FacetCut({
                facetAddress: address(0),
                action: IDiamondCut.FacetCutAction.Remove,
                functionSelectors: replaceVaultFacetSelectors
            })
        );
        vm.prank(owner);
        diamond.diamondCut(replaceCut, address(0), "");

        //test withdrawAsset isn't callable anymore
        vm.prank(sender);
        vm.expectRevert(abi.encodeWithSignature("FunctionNotFound(bytes4)", IDiamond.withdrawAsset.selector));
        diamond.withdrawAsset(_dusd, 1 ether);
        assertEq(diamond.facetAddress(IDiamond.withdrawAsset.selector), address(0));

        //test different function on the same facet
        vm.prank(sender);
        vm.expectRevert("ERC20: burn amount exceeds balance");
        diamond.depositAsset(_dusd, 1 ether);
    }
}
