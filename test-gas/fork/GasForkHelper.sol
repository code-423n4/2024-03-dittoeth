// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {stdJson} from "forge-std/StdJson.sol";
import {IDiamond} from "interfaces/IDiamond.sol";
import {IDiamondCut} from "contracts/interfaces/IDiamondCut.sol";
import {IImmutableCreate2Factory} from "deploy/DeployHelper.sol";
import {IRocketStorage} from "interfaces/IRocketStorage.sol";
import {IRocketTokenRETH} from "interfaces/IRocketTokenRETH.sol";
import {ISTETH} from "interfaces/ISTETH.sol";
import {IUNSTETH} from "interfaces/IUNSTETH.sol";

import {BridgeReth} from "contracts/bridges/BridgeReth.sol";
import {BridgeSteth} from "contracts/bridges/BridgeSteth.sol";

import {VAULT} from "contracts/libraries/Constants.sol";

import {GasHelper} from "test-gas/GasHelper.sol";

//DO NOT REMOVE. WIll BREAK CI
import {ImmutableCreate2Factory} from "deploy/ImmutableCreate2Factory.sol";

contract GasForkHelper is GasHelper {
    uint256 public forkBlock = 17_273_111;
    uint256 public mainnetFork;
    // RocketPool
    address public rocketStorage = address(0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46);
    address public _reth;
    address public _bridgeReth;
    IRocketTokenRETH public reth;
    BridgeReth public bridgeReth;
    // Lido
    address public _steth;
    address public _unsteth;
    address public _bridgeSteth;
    ISTETH public steth;
    IUNSTETH public unsteth;
    BridgeSteth public bridgeSteth;
    // Setup for diamondcut
    IImmutableCreate2Factory public factory;
    IDiamondCut.FacetCut[] public cutBridge;
    bytes4[] internal bridgeRouterSelectors = [
        IDiamond.getDethTotal.selector,
        IDiamond.getBridges.selector,
        IDiamond.deposit.selector,
        IDiamond.depositEth.selector,
        IDiamond.withdraw.selector,
        IDiamond.withdrawTapp.selector
    ];

    function setUp() public virtual override {
        try vm.envString("MAINNET_RPC_URL") returns (string memory rpcUrl) {
            mainnetFork = vm.createSelectFork(rpcUrl, forkBlock);
        } catch {
            revert("env: MAINNET_RPC_URL failure");
        }
        assertEq(vm.activeFork(), mainnetFork);

        super.setUp();

        _reth = IRocketStorage(rocketStorage).getAddress(keccak256(abi.encodePacked("contract.address", "rocketTokenRETH")));
        reth = IRocketTokenRETH(_reth);
        bridgeReth = new BridgeReth(IRocketStorage(rocketStorage), _diamond);
        _bridgeReth = address(bridgeReth);

        _steth = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
        steth = ISTETH(_steth);
        _unsteth = address(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);
        unsteth = IUNSTETH(payable(_unsteth));
        bridgeSteth = new BridgeSteth(steth, unsteth, _diamond);
        _bridgeSteth = address(bridgeSteth);

        vm.startPrank(owner);
        // Delete mock bridges
        diamond.deleteBridge(ob.contracts("bridgeSteth"));
        diamond.deleteBridge(ob.contracts("bridgeReth"));

        diamond.createBridge({bridge: _bridgeReth, vault: VAULT.ONE, withdrawalFee: 50});
        diamond.createBridge({bridge: _bridgeSteth, vault: VAULT.ONE, withdrawalFee: 25});
        // DiamondCut with real bridges
        address _immutableCreate2Factory = address(0x0000000000FFe8B47B3e2130213B802212439497);
        factory = IImmutableCreate2Factory(_immutableCreate2Factory);

        bytes32 salt = bytes32(0x00000000000000000000000000000000000000005272369be7612000004a33fd);
        address _bridgeRouter = factory.safeCreate2(
            salt, abi.encodePacked(vm.getCode("BridgeRouterFacet.sol:BridgeRouterFacet"), abi.encode(_bridgeReth, _bridgeSteth))
        );
        cutBridge.push(
            IDiamondCut.FacetCut({
                facetAddress: _bridgeRouter,
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: bridgeRouterSelectors
            })
        );

        diamond.diamondCut(cutBridge, address(0x0), "");

        vm.stopPrank();

        deal(_reth, sender, 1000 ether);
        deal(sender, 2000 ether);
        vm.startPrank(sender);
        steth.submit{value: 1000 ether}(address(0)); // Can't deal STETH, get it the old fashioned way

        reth.approve(_bridgeReth, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        diamond.deposit(_bridgeReth, 500 ether);
        steth.approve(_bridgeSteth, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        diamond.deposit(_bridgeSteth, 500 ether);
        vm.stopPrank();
    }
}
