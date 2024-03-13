// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

//some imports are used through inheritance
import {Errors, stdError, IDiamond, IDiamondCut, console, MigrationHelper} from "deploy/migrations/MigrationHelper.sol";

interface RemovedFunctions {
    function setAssetOracle(address, address) external;
}

// FOUNDRY_PROFILE=deploy-mainnet forge script DeployDao03 --ffi
contract DeployDao03 is MigrationHelper {
    bytes32 internal constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 internal TIMELOCK_SALT = bytes32(0x000000000000000000000000000000000000000093ed3189d3ff000000084072);
    bytes32 internal GOVERNOR_SALT = bytes32(0x0000000000000000000000000000000000000000bfc7db13a2f1c000013d0f55);
    address[] internal proposers = [_safeWallet];
    address[] internal executors = [_safeWallet];
    address internal admin = _safeWallet;
    bytes internal timelockInitcode;
    address internal timelockAddress;
    bytes internal governorInitcode;
    address internal governorAddress;
    bytes internal claimOwnerPayload;

    bytes4[] internal removeSelectors = [RemovedFunctions.setAssetOracle.selector];
    bytes internal diamondCutPayload;

    // fork and initialize variables shared between the script and test
    function setUp() public virtual {
        fork(18821534);
        //timelock
        bytes memory timelockBytecode = getBytecode("03_deploy_dao/DittoTimelockController.json");
        timelockInitcode = abi.encodePacked(timelockBytecode, abi.encode(proposers, executors, admin));
        timelockAddress = create2Factory.findCreate2Address(TIMELOCK_SALT, timelockInitcode);
        //governor
        bytes memory governorBytecode = getBytecode("03_deploy_dao/DittoGovernor.json");
        governorInitcode = abi.encodePacked(governorBytecode, abi.encode(_ditto, timelockAddress));
        governorAddress = create2Factory.findCreate2Address(GOVERNOR_SALT, governorInitcode);

        claimOwnerPayload = abi.encodeWithSelector(IDiamond.claimOwnership.selector);

        facetCut.push(
            IDiamondCut.FacetCut({
                facetAddress: address(0),
                action: IDiamondCut.FacetCutAction.Remove,
                functionSelectors: removeSelectors
            })
        );

        diamondCutPayload = abi.encodeWithSelector(IDiamond.diamondCut.selector, facetCut, address(0), "");
    }

    function run() external {
        // console.log("init code hash for timelock salt generation");
        // emit log_bytes32(keccak256(timelockInitcode));

        //deploy timelock
        bytes memory safeCreate2 = abi.encodeWithSelector(create2Factory.safeCreate2.selector, TIMELOCK_SALT, timelockInitcode);
        console.log("----------------------------------------------------");
        console.log("batch 1 - timelock safeCreate2 txn data");
        console.log("to address: ", _immutableCreate2Factory);
        console.newLine();
        emit log_bytes(safeCreate2);
        console.newLine();

        // console.log("----------------------------------------------------");
        // console.log("init code hash for governor salt generation");
        // emit log_bytes32(keccak256(governorInitcode));

        //deploy governor
        safeCreate2 = abi.encodeWithSelector(create2Factory.safeCreate2.selector, GOVERNOR_SALT, governorInitcode);
        console.log("----------------------------------------------------");
        console.log("batch 2 - governor safeCreate2 txn data");
        console.log("to address: ", _immutableCreate2Factory);
        console.newLine();
        emit log_bytes(safeCreate2);
        console.newLine();

        //grant roles
        bytes memory grantRole = abi.encodeWithSelector(timelock.grantRole.selector, EXECUTOR_ROLE, _governor);
        console.log("----------------------------------------------------");
        console.log("batch 3 - grant executor to governor txn data");
        console.log("to address: ", _timelock);
        console.newLine();
        emit log_bytes(grantRole);
        console.newLine();

        grantRole = abi.encodeWithSelector(timelock.grantRole.selector, PROPOSER_ROLE, _governor);
        console.log("----------------------------------------------------");
        console.log("batch 3 - grant proposer to governor txn data");
        console.log("to address: ", _timelock);
        console.newLine();
        emit log_bytes(grantRole);
        console.newLine();

        grantRole = abi.encodeWithSelector(timelock.grantRole.selector, EXECUTOR_ROLE, _timelock);
        console.log("----------------------------------------------------");
        console.log("batch 3 - grant executor to timelock txn data");
        console.log("to address: ", _timelock);
        console.newLine();
        emit log_bytes(grantRole);
        console.newLine();

        //renounce role
        bytes memory renounceRole = abi.encodeWithSelector(timelock.renounceRole.selector, DEFAULT_ADMIN_ROLE, _safeWallet);
        console.log("----------------------------------------------------");
        console.log("batch 3 - renounce timelock admin txn data");
        console.log("to address: ", _timelock);
        console.newLine();
        emit log_bytes(renounceRole);
        console.newLine();

        //diamond cut remove setAssetOracle
        //differs from test because in tests this is a governance proposal to test out governor/timelock
        console.log("----------------------------------------------------");
        console.log("batch 3 - diamondCut remove setAssetOracle txn data");
        console.log("to address: ", _diamond);
        console.newLine();
        emit log_bytes(diamondCutPayload);
        console.newLine();

        //transfer diamond ownership
        bytes memory transferOwnership = abi.encodeWithSelector(diamond.transferOwnership.selector, _timelock);
        console.log("----------------------------------------------------");
        console.log("batch 3 - transfer diamond ownership txn data");
        console.log("to address: ", _diamond);
        console.newLine();
        emit log_bytes(transferOwnership);
        console.newLine();

        //timelock schedule claimOwner
        bytes memory timelockSchedule =
            abi.encodeWithSelector(timelock.schedule.selector, _diamond, 0, claimOwnerPayload, bytes32(0), bytes32(0), 0);
        console.log("----------------------------------------------------");
        console.log("batch 4 - timelock schedule claim ownership txn data");
        console.log("to address: ", _timelock);
        console.newLine();
        emit log_bytes(timelockSchedule);
        console.newLine();

        //timelock execute claimOwner
        bytes memory timelockExecute =
            abi.encodeWithSelector(timelock.execute.selector, _diamond, 0, claimOwnerPayload, bytes32(0), bytes32(0), 0);
        console.log("----------------------------------------------------");
        console.log("batch 4 - timelock execute claim ownership txn data");
        console.log("to address: ", _timelock);
        console.newLine();
        emit log_bytes(timelockExecute);
        console.newLine();

        //send DAO funds to timelock
        bytes memory dittoTransfer = abi.encodeWithSelector(ditto.transfer.selector, _timelock, 35_000_000 ether);
        console.log("----------------------------------------------------");
        console.log("batch 4 - send DAO funds to timelock");
        console.log("to address: ", _ditto);
        console.newLine();
        emit log_bytes(dittoTransfer);
        console.newLine();
    }
}
