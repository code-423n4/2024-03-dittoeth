// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Errors, stdError, IDiamond, IDiamondCut, RemovedFunctions, console, DeployDao03} from "./03_deploy_dao.s.sol";

contract DeployDao03Test is DeployDao03 {
    function setUp() public virtual override {
        super.setUp();
    }

    function testFork_Migration_03() public {
        //deploy timelock with 0xD1770 prefix
        address deployedTimelockAddress = create2Factory.safeCreate2(TIMELOCK_SALT, timelockInitcode);
        assertEq(deployedTimelockAddress, timelockAddress);
        assertEq(deployedTimelockAddress, _timelock);

        //deploy governor with 0xD1770 prefix
        address deployedGovernorAddress = create2Factory.safeCreate2(GOVERNOR_SALT, governorInitcode);
        assertEq(deployedGovernorAddress, governorAddress);
        assertEq(deployedGovernorAddress, _governor);

        vm.startPrank(_safeWallet);
        //grant roles
        timelock.grantRole(EXECUTOR_ROLE, _governor);
        timelock.grantRole(PROPOSER_ROLE, _governor);
        //this is necessary because of GovernorTimelockControl module
        timelock.grantRole(EXECUTOR_ROLE, _timelock);
        //renounce admin role
        timelock.renounceRole(DEFAULT_ADMIN_ROLE, _safeWallet);

        //admin role renounced
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", _safeWallet, bytes32(0)));
        //governor should not be given canceller until future
        timelock.grantRole(CANCELLER_ROLE, _governor);

        //transfer ownership of diamond to timelock
        diamond.transferOwnership(_timelock);
        //ditto safe wallet can propose to timelock operation
        timelock.schedule(_diamond, 0, claimOwnerPayload, bytes32(0), bytes32(0), 0);

        //ditto safe wallet can cancel timelock operation
        timelock.cancel(timelock.hashOperation(_diamond, 0, claimOwnerPayload, bytes32(0), bytes32(0)));

        timelock.schedule(_diamond, 0, claimOwnerPayload, bytes32(0), bytes32(0), 0);
        //ditto safe wallet can execute timelock txns
        timelock.execute(_diamond, 0, claimOwnerPayload, bytes32(0), bytes32(0));
        assertEq(diamond.owner(), _timelock);

        //ownership transferred from safeWallet
        vm.expectRevert("LibDiamond: Must be contract owner");
        diamond.diamondCut(facetCut, address(0), "");

        timelock.schedule(_diamond, 0, diamondCutPayload, bytes32(0), bytes32(0), 0);

        bytes memory cancelPayload = abi.encodeWithSelector(
            timelock.cancel.selector, timelock.hashOperation(_diamond, 0, diamondCutPayload, bytes32(0), bytes32(0))
        );

        targets.push(_timelock);
        values.push(0);
        calldatas.push(cancelPayload);

        //must self-delegate to get voting power.
        ditto.delegate(_safeWallet);
        vm.roll(block.number + 1);

        uint256 proposalId = governor.propose(targets, values, calldatas, "cancel diamondCut");

        //skip 1 day to bypass voting delay
        vm.roll(block.number + 7201);

        governor.castVote(proposalId, 1);

        vm.roll(block.number + 50_401);

        governor.queue(targets, values, calldatas, keccak256("cancel diamondCut"));
        //governor cannot cancel scheduled timelock txn
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", _timelock, CANCELLER_ROLE));
        governor.execute(targets, values, calldatas, keccak256("cancel diamondCut"));

        bytes memory executePayload =
            abi.encodeWithSelector(timelock.execute.selector, _diamond, 0, diamondCutPayload, bytes32(0), bytes32(0));

        targets[0] = _timelock;
        values[0] = 0;
        calldatas[0] = executePayload;

        proposalId = governor.propose(targets, values, calldatas, "diamondCut remove setAssetOracle");

        vm.roll(block.number + 7201);
        governor.castVote(proposalId, 1);
        vm.roll(block.number + 50_401);

        governor.queue(targets, values, calldatas, keccak256("diamondCut remove setAssetOracle"));

        //function exists

        vm.expectRevert("LibDiamond: Must be contract owner");
        RemovedFunctions(_diamond).setAssetOracle(_dusd, address(0));

        governor.execute(targets, values, calldatas, keccak256("diamondCut remove setAssetOracle"));

        //function doesn't exist on diamond
        vm.expectRevert(abi.encodeWithSignature("FunctionNotFound(bytes4)", RemovedFunctions.setAssetOracle.selector));
        RemovedFunctions(_diamond).setAssetOracle(_dusd, address(0));

        //transfer DAO funds (35%) to timelock
        assertEq(ditto.balanceOf(_safeWallet), 70_000_000 ether);
        ditto.transfer(_timelock, 35_000_000 ether);
        assertEq(ditto.balanceOf(_timelock), 35_000_000 ether);
        assertEq(ditto.balanceOf(_safeWallet), 35_000_000 ether);

        vm.stopPrank();
    }
}
