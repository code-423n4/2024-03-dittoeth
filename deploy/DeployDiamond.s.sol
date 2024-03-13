// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {DeployHelper} from "deploy/DeployHelper.sol";

// import {console} from "contracts/libraries/console.sol";

struct Deployed {
    string name;
    address addr;
}

contract DeployDiamond is DeployHelper {
    uint256 private deployerPrivateKey;
    address private deployerAddress;
    string private profile;
    uint256 private chainId;

    string private constant PATH = "./.deploy-snapshots/";

    function run() external {
        isMock = false;
        string[] memory cmd = new string[](3);
        cmd[0] = "mkdir";
        cmd[1] = "-p";
        cmd[2] = PATH;
        vm.ffi(cmd);
        //read env variables and choose EOA for transaction signing
        profile = vm.envOr("FOUNDRY_PROFILE", string("default"));
        if (keccak256(abi.encodePacked(profile)) == keccak256(abi.encodePacked("deploy-local"))) {
            try vm.envUint("ANVIL_9_PRIVATE_KEY") returns (uint256 privateKey) {
                deployerPrivateKey = privateKey;
            } catch {
                revert("add ANVIL_9_PRIVATE_KEY to env");
            }
            deployerAddress = vm.rememberKey(deployerPrivateKey);
            chainId = 31337;
            isLocalDeploy = true;
            vm.startBroadcast(deployerPrivateKey);
            deployContracts(deployerAddress, chainId);
            vm.stopBroadcast();
            setFacets(chainId);
            vm.startBroadcast(deployerPrivateKey);
            postDeploySetup(chainId);
            _setETH(1700 ether);
            vm.stopBroadcast();
        } else if (keccak256(abi.encodePacked(profile)) == keccak256(abi.encodePacked("deploy-mainnet"))) {
            chainId = 1;
            vm.startBroadcast(address(0xf846f3635e9E3F5C193eDa1c155c985D7a57d225));
            deployContracts(address(0xf846f3635e9E3F5C193eDa1c155c985D7a57d225), chainId);
            vm.stopBroadcast();
            setFacets(chainId);
            vm.startBroadcast(address(0xf846f3635e9E3F5C193eDa1c155c985D7a57d225));
            postDeploySetup(chainId);
            vm.stopBroadcast();
        } else {
            revert("invalid foundry profile");
        }

        Deployed[] memory contracts = new Deployed[](13);
        contracts[0] = Deployed("tapp", _diamond);
        contracts[1] = Deployed("deth", _deth);
        contracts[2] = Deployed("ditto", _ditto);
        contracts[3] = Deployed("dusd", _dusd);
        contracts[4] = Deployed("bridgeReth", _bridgeReth);
        contracts[5] = Deployed("bridgeSteth", _bridgeSteth);
        contracts[6] = Deployed("diamond", _diamond);
        contracts[7] = Deployed("steth", _steth);
        contracts[8] = Deployed("ethAggregator", _ethAggregator);
        contracts[9] = Deployed("rocketStorage", _rocketStorage);
        contracts[10] = Deployed("reth", _reth);
        contracts[11] = Deployed("multicall3", _multicall3);
        contracts[12] = Deployed("unsteth", _unsteth);

        for (uint256 i = 0; i < contracts.length; i++) {
            string memory snapFile = string(abi.encodePacked(PATH, contracts[i].name, "-", vm.toString(chainId), ".snap"));
            vm.writeFile(snapFile, vm.toString(contracts[i].addr));
        }
    }
}
