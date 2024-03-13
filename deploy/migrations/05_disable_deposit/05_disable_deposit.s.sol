// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors, stdError, IDiamond, IDiamondCut, console, MigrationHelper} from "deploy/migrations/MigrationHelper.sol";

// FOUNDRY_PROFILE=deploy-mainnet forge script DisableDeposit05 --ffi
contract DisableDeposit05 is MigrationHelper {
    bytes4[] internal removeSelectors = [IDiamond.deposit.selector, IDiamond.depositEth.selector];
    bytes internal diamondCutPayload;

    function setUp() public virtual {
        fork(19364178);

        facetCut.push(
            IDiamondCut.FacetCut({
                facetAddress: address(0),
                action: IDiamondCut.FacetCutAction.Remove,
                functionSelectors: removeSelectors
            })
        );

        diamondCutPayload = abi.encodeWithSelector(IDiamond.diamondCut.selector, facetCut, address(0), "");

        targets.push(_diamond);
        values.push(0);
        calldatas.push(diamondCutPayload);
    }

    function run() external {
        //timelock schedule diamond cut remove deposit/depositEth
        bytes memory timelockSchedule =
            abi.encodeWithSelector(timelock.schedule.selector, _diamond, 0, diamondCutPayload, bytes32(0), bytes32(0), 0);
        console.log("----------------------------------------------------");
        console.log("batch 4 - timelock schedule remove deposit/depositEth txn data");
        console.log("to address: ", _timelock);
        console.newLine();
        emit log_bytes(timelockSchedule);
        console.newLine();

        //timelock execute diamond cut remove deposit/depositEth
        bytes memory timelockExecute =
            abi.encodeWithSelector(timelock.execute.selector, _diamond, 0, diamondCutPayload, bytes32(0), bytes32(0), 0);
        console.log("----------------------------------------------------");
        console.log("batch 4 - timelock execute remove deposit/depositEth txn data");
        console.log("to address: ", _timelock);
        console.newLine();
        emit log_bytes(timelockExecute);
        console.newLine();
    }
}
