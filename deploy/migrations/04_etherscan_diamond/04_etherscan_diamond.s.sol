// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors, stdError, IDiamond, IDiamondCut, console, MigrationHelper} from "deploy/migrations/MigrationHelper.sol";

interface AddedFunctions {
    function setDummyImplementation(address) external;
    function implementation() external view returns (address);
}

// FOUNDRY_PROFILE=deploy-mainnet forge script EtherscanDiamond04 --ffi
contract EtherscanDiamond04 is MigrationHelper {
    bytes etherscanDiamondImplInitC;
    address etherscanDiamondImplAddress;

    bytes etherscanFacetInitC;
    address etherscanFacetAddress;

    bytes32 SALT = bytes32(0);

    bytes4[] internal addSelectors = [AddedFunctions.setDummyImplementation.selector, AddedFunctions.implementation.selector];

    bytes internal diamondCutPayload;
    bytes internal dummyImplPayload;

    AddedFunctions newDiamond = AddedFunctions(_diamond);

    function setUp() public virtual {
        fork(19092986);

        bytes memory etherscanDiamondImplByteC = getBytecode("04_etherscan_diamond/EtherscanDiamondImpl.json");
        etherscanDiamondImplInitC = abi.encodePacked(etherscanDiamondImplByteC);
        etherscanDiamondImplAddress = create2Factory.findCreate2Address(SALT, etherscanDiamondImplInitC);

        bytes memory etherscanFacetByteC = getBytecode("04_etherscan_diamond/DiamondEtherscanFacet.json");
        etherscanFacetInitC = abi.encodePacked(etherscanFacetByteC);
        etherscanFacetAddress = create2Factory.findCreate2Address(SALT, etherscanFacetInitC);

        facetCut.push(
            IDiamondCut.FacetCut({
                facetAddress: etherscanFacetAddress,
                action: IDiamondCut.FacetCutAction.Add,
                functionSelectors: addSelectors
            })
        );

        diamondCutPayload = abi.encodeWithSelector(IDiamond.diamondCut.selector, facetCut, address(0), "");

        dummyImplPayload = abi.encodeWithSelector(AddedFunctions.setDummyImplementation.selector, etherscanDiamondImplAddress);

        targets.push(_diamond);
        values.push(0);
        calldatas.push(diamondCutPayload);

        targets.push(_diamond);
        values.push(0);
        calldatas.push(dummyImplPayload);
    }

    function run() external {
        console.log("----------------------------------------------------");
        console.log("batch 1 - etherscan diamond impl safeCreate2 txn data");
        console.log("to address: ", _immutableCreate2Factory);
        console.newLine();
        bytes memory safeCreate2 = abi.encodeWithSelector(create2Factory.safeCreate2.selector, SALT, etherscanDiamondImplInitC);
        emit log_bytes(safeCreate2);
        console.newLine();

        console.log("----------------------------------------------------");
        console.log("batch 2 - etherscanFacet safeCreate2 txn data");
        console.log("to address: ", _immutableCreate2Factory);
        console.newLine();
        safeCreate2 = abi.encodeWithSelector(create2Factory.safeCreate2.selector, SALT, etherscanFacetInitC);
        emit log_bytes(safeCreate2);
        console.newLine();

        console.log("----------------------------------------------------");
        console.log("batch 2 - scheduleBatch diamondCut add etherscanFacet & setDummyImpl txn data");
        console.log("to address: ", _timelock);
        console.newLine();
        bytes memory timelockSchedule =
            abi.encodeWithSelector(timelock.scheduleBatch.selector, targets, values, calldatas, bytes32(0), bytes32(0), 0);
        emit log_bytes(timelockSchedule);
        console.newLine();

        console.log("----------------------------------------------------");
        console.log("batch 2 - executeBatch diamondCut add etherscanFacet & setDummyImpl txn data");
        console.log("to address: ", _timelock);
        console.newLine();
        bytes memory timelockExecute =
            abi.encodeWithSelector(timelock.executeBatch.selector, targets, values, calldatas, bytes32(0), bytes32(0));
        emit log_bytes(timelockExecute);
        console.newLine();
    }
}
