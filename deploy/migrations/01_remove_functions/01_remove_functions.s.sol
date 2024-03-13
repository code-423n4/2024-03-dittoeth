// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors, stdError, IDiamond, IDiamondCut, console, MigrationHelper} from "deploy/migrations/MigrationHelper.sol";

interface RemovedFunctions {
    function depositDETH(address deth, uint88 amount) external;

    function withdrawDETH(address deth, uint88 amount) external;

    function unstakeEth(address bridge, uint88 dethAmount) external;
}

// FOUNDRY_PROFILE=deploy-mainnet forge script RemoveFunctions01 --ffi
contract RemoveFunctions01 is MigrationHelper {
    bytes4[] internal removeSelectors =
        [RemovedFunctions.depositDETH.selector, RemovedFunctions.withdrawDETH.selector, RemovedFunctions.unstakeEth.selector];

    IDiamondCut.FacetCut internal removeFacetCut = IDiamondCut.FacetCut({
        facetAddress: address(0),
        action: IDiamondCut.FacetCutAction.Remove,
        functionSelectors: removeSelectors
    });

    function run() external {
        facetCut.push(removeFacetCut);

        bytes memory diamondCut = abi.encodeWithSelector(IDiamond.diamondCut.selector, facetCut, address(0), "");

        console.log("diamondCut remove txn data");
        emit log_bytes(diamondCut);
    }
}
