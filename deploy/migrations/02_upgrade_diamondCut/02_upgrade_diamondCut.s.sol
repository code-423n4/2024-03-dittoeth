// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors, stdError, IDiamond, IDiamondCut, console, MigrationHelper} from "deploy/migrations/MigrationHelper.sol";

interface RemovedFunctions {
    function setUnstakeFee(address bridge, uint8 unstakeFee) external;
}

// FOUNDRY_PROFILE=deploy-mainnet forge script UpgradeDiamondCut02 --ffi
contract UpgradeDiamondCut02 is MigrationHelper {
    bytes4[] internal replaceSelectors = [IDiamond.diamondCut.selector];

    bytes4[] internal removeSelectors = [RemovedFunctions.setUnstakeFee.selector];

    bytes32 internal DIAMONDCUT_SALT = bytes32(0);

    string public DIAMOND_CUT_PATH = "02_upgrade_diamondCut/DiamondCutFacet.json";

    function setUp() public virtual {
        fork(18772409);
    }

    function run() external {
        bytes memory diamondCutBytecode = getBytecode(DIAMOND_CUT_PATH);

        bytes memory safeCreate2 =
            abi.encodeWithSelector(create2Factory.safeCreate2.selector, DIAMONDCUT_SALT, abi.encodePacked(diamondCutBytecode));

        console.log("safeCreate2 txn data");
        emit log_bytes(safeCreate2);

        address newDiamondCutFacetAddress = create2Factory.findCreate2Address(DIAMONDCUT_SALT, abi.encodePacked(diamondCutBytecode));

        //txn 2
        facetCut.push(
            IDiamondCut.FacetCut({
                facetAddress: newDiamondCutFacetAddress,
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: replaceSelectors
            })
        );
        console.log("----------------------------------");
        console.log("diamondCut replace txn data");
        bytes memory diamondCut = abi.encodeWithSelector(IDiamond.diamondCut.selector, facetCut, address(0), "");
        emit log_bytes(diamondCut);

        //txn 3
        facetCut[0] = IDiamondCut.FacetCut({
            facetAddress: address(0),
            action: IDiamondCut.FacetCutAction.Remove,
            functionSelectors: removeSelectors
        });
        console.log("----------------------------------");
        console.log("diamondCut remove txn data");
        diamondCut = abi.encodeWithSelector(IDiamond.diamondCut.selector, facetCut, address(0), "");
        emit log_bytes(diamondCut);
    }
}
