// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {stdError} from "forge-std/StdError.sol";
import {IGovernor} from "@openzeppelin-v5/contracts/governance/IGovernor.sol";
import {IERC20} from "@openzeppelin-v5/contracts/interfaces/IERC20.sol";

import {ConstantsTest} from "test/utils/ConstantsTest.sol";
import {IDiamond, IDiamondCut} from "interfaces/IDiamond.sol";
import {IDitto} from "contracts/interfaces/IDitto.sol";
import {console} from "contracts/libraries/console.sol";
import {Errors} from "contracts/libraries/Errors.sol";

interface IImmutableCreate2Factory {
    function safeCreate2(bytes32 salt, bytes memory contractCreationCode) external returns (address);

    function hasBeenDeployed(address deploymentAddress) external view returns (bool);

    function findCreate2Address(bytes32 salt, bytes calldata initCode) external view returns (address deploymentAddress);
}

interface Relay {
    function relay(address target, uint256 value, bytes calldata data) external payable;
}

interface IDittoTimelockController {
    function schedule(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt, uint256 delay)
        external;

    function scheduleBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external;

    function execute(address target, uint256 value, bytes calldata payload, bytes32 predecessor, bytes32 salt) external;

    function executeBatch(
        address[] calldata targets,
        uint256[] calldata values,
        bytes[] calldata payloads,
        bytes32 predecessor,
        bytes32 salt
    ) external;

    function grantRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role, address account) external;

    function hasRole(bytes32 role, address account) external view returns (bool);

    function getMinDelay() external view returns (uint256);

    function hashOperation(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt)
        external
        view
        returns (bytes32);

    function cancel(bytes32 id) external;
}

contract MigrationHelper is ConstantsTest, Script {
    //copy from artifact-gas into relevant migration folder
    string internal constant MIGRATION_DIRECTORY = "./deploy/migrations/";

    bytes32 internal constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 internal constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 internal constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    address internal constant _safeWallet = address(0xc74487730fCa3f2040cC0f6Fb95348a9B1c19EFc);
    address internal constant _dittoDeployer = address(0xf846f3635e9E3F5C193eDa1c155c985D7a57d225);

    address internal constant _immutableCreate2Factory = address(0x0000000000FFe8B47B3e2130213B802212439497);
    address internal constant _ethAggregator = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
    address internal constant _steth = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    address internal constant _unsteth = address(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);
    address internal constant _rocketStorage = address(0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46);
    address internal constant _diamond = address(0xd177000Be70Ea4EfC23987aCD1a79EaBa8b758f1);

    address internal constant _deth = address(0xd1770004661852cbC0B317c7775f4fA22E6bC60A);
    address internal constant _dusd = address(0xD177000a2BC4F4d2246F0527Ad74Fd4140e029fd);
    address internal constant _ditto = address(0xD177000D71aB154CA6B75f42Be53c18e0b7148F7);

    address internal constant _bridgeSteth = address(0x364626644d2C5E34a6f27c1bab3DCb73D43E12fB);
    address internal constant _bridgeReth = address(0x769a9041f96e29408ebB6Fd4Ce999AF852Dbf9aE);

    address internal constant _timelock = address(0xd177000c8f4D69ada2aCDeCa6fEB15ceA9586A07);
    address internal constant _governor = address(0xD177000c2F68D5f6c33Bca61f2ddEd93C7e6564E);

    IDiamondCut.FacetCut[] public facetCut;

    IDiamond public diamond = IDiamond(payable(_diamond));
    IImmutableCreate2Factory public create2Factory = IImmutableCreate2Factory(_immutableCreate2Factory);

    IDitto public ditto = IDitto(_ditto);
    IDittoTimelockController timelock = IDittoTimelockController(_timelock);
    IGovernor governor = IGovernor(_governor);
    Relay relay = Relay(_governor);

    IERC20 public steth = IERC20(_steth);

    address[] internal targets;
    uint256[] internal values;
    bytes[] internal calldatas;
    string internal descriptionString;
    bytes32 internal descriptionHash;

    //find the block of the current diamond implementation pre-migration
    function fork(uint256 forkBlock) public {
        try vm.envString("MAINNET_RPC_URL") returns (string memory rpcUrl) {
            require(forkBlock != 0, "Enter Fork Block In Test Setup");
            uint256 mainnetFork = vm.createSelectFork(rpcUrl, forkBlock);
            assertEq(vm.activeFork(), mainnetFork);
        } catch {
            revert("env: MAINNET_RPC_URL failure");
        }
    }

    function getSelector(string memory _func) internal pure returns (bytes4) {
        return bytes4(keccak256(bytes(_func)));
    }

    function getBytecode(string memory path) internal view returns (bytes memory) {
        //copied from artifacts-gas NOT artifacts
        return
            vm.parseBytes(stdJson.readString(vm.readFile(string(abi.encodePacked(MIGRATION_DIRECTORY, path))), ".bytecode.object"));
    }
}
