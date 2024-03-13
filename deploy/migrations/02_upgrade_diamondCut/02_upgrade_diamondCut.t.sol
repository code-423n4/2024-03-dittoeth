// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors, stdError, IDiamond, IDiamondCut, RemovedFunctions, UpgradeDiamondCut02} from "./02_upgrade_diamondCut.s.sol";
import {IDiamondLoupe} from "contracts/interfaces/IDiamondLoupe.sol";

contract UpgradeDiamond02Test is UpgradeDiamondCut02 {
    function setUp() public virtual override {
        super.setUp();
    }

    function testFork_Migration_02() public {
        RemovedFunctions removedFunctions = RemovedFunctions(_diamond);

        IDiamondLoupe.Facet[] memory facets = diamond.facets();

        uint256 selectorCount = 0;
        uint256 ownerFacetCount = 0;
        uint256 oldDiamondCutCount = 0;
        for (uint256 i = 0; i < facets.length; i++) {
            selectorCount += facets[i].functionSelectors.length;
            if (facets[i].facetAddress == address(0xCc7C8Eb5aDdEc694fC2EB29ae6c762D9ebCC9deb)) {
                ownerFacetCount = facets[i].functionSelectors.length;
                bool selectorPresent = false;
                for (uint256 x = 0; x < facets[i].functionSelectors.length; x++) {
                    if (facets[i].functionSelectors[x] == RemovedFunctions.setUnstakeFee.selector) {
                        selectorPresent = true;
                    }
                }
                if (selectorPresent == false) revert();
            } else if (facets[i].facetAddress == address(0xe518176203D28b8E556C9d3CdE1039aeFDb81f3a)) {
                oldDiamondCutCount = facets[i].functionSelectors.length;
                bool selectorPresent = false;
                for (uint256 x = 0; x < facets[i].functionSelectors.length; x++) {
                    if (facets[i].functionSelectors[x] == IDiamondCut.diamondCut.selector) {
                        selectorPresent = true;
                    }
                }
                if (selectorPresent == false) revert();
            }
        }
        assertTrue(ownerFacetCount > 0);
        assertTrue(oldDiamondCutCount > 0);

        assertEq(selectorCount, 113);
        assertEq(ownerFacetCount, 28);
        facetCut.push(
            IDiamondCut.FacetCut({
                facetAddress: address(0),
                action: IDiamondCut.FacetCutAction.Remove,
                functionSelectors: removeSelectors
            })
        );

        vm.prank(_safeWallet);
        //error is caused by a bug in diamondCut due to how solidity 0.8 handles over/underflows
        vm.expectRevert(stdError.arithmeticError);
        diamond.diamondCut(facetCut, address(0), "");

        vm.expectRevert(Errors.NotOwnerOrAdmin.selector);
        removedFunctions.setUnstakeFee(_bridgeSteth, 1);

        bytes memory diamondCutBytecode = getBytecode(DIAMOND_CUT_PATH);

        vm.prank(_dittoDeployer);
        address _newDiamondCut = create2Factory.safeCreate2(DIAMONDCUT_SALT, abi.encodePacked(diamondCutBytecode));

        assertEq(_newDiamondCut, address(0xd40f94e5fD70835AC6FC0f0eaf00AEb20767A4E8));

        facetCut[0] = IDiamondCut.FacetCut({
            facetAddress: _newDiamondCut,
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: replaceSelectors
        });
        vm.prank(_safeWallet);
        diamond.diamondCut(facetCut, address(0), "");

        facetCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: removeSelectors
        });
        vm.prank(_safeWallet);
        diamond.diamondCut(facetCut, address(0), "");

        vm.expectRevert(abi.encodeWithSignature("FunctionNotFound(bytes4)", RemovedFunctions.setUnstakeFee.selector));
        removedFunctions.setUnstakeFee(_bridgeSteth, 1);

        facets = diamond.facets();

        selectorCount = 0;
        ownerFacetCount = 0;
        uint256 newDiamondCutCount = 0;
        for (uint256 i = 0; i < facets.length; i++) {
            selectorCount += facets[i].functionSelectors.length;
            if (
                facets[i]
                    //existing owner facet
                    .facetAddress == address(0xCc7C8Eb5aDdEc694fC2EB29ae6c762D9ebCC9deb)
            ) {
                ownerFacetCount = facets[i].functionSelectors.length;
                bool selectorPresent = false;
                for (uint256 x = 0; x < facets[i].functionSelectors.length; x++) {
                    if (facets[i].functionSelectors[x] == RemovedFunctions.setUnstakeFee.selector) {
                        selectorPresent = true;
                    }
                }
                if (selectorPresent == true) revert();
            } else if (
                facets[i]
                    // old diamond cut facet
                    .facetAddress == address(0xe518176203D28b8E556C9d3CdE1039aeFDb81f3a)
            ) {
                revert();
            } else if (
                facets[i]
                    // new diamond cut facet
                    .facetAddress == address(0xd40f94e5fD70835AC6FC0f0eaf00AEb20767A4E8)
            ) {
                newDiamondCutCount = facets[i].functionSelectors.length;
                bool selectorPresent = false;
                for (uint256 x = 0; x < facets[i].functionSelectors.length; x++) {
                    if (facets[i].functionSelectors[x] == IDiamondCut.diamondCut.selector) {
                        selectorPresent = true;
                    }
                }
                if (selectorPresent == false) revert();
            }
        }

        assertTrue(ownerFacetCount > 0);
        assertTrue(newDiamondCutCount > 0);

        assertEq(selectorCount, 112);
        assertEq(ownerFacetCount, 27);
    }
}
