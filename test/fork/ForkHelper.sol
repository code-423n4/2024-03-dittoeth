// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {C, VAULT} from "contracts/libraries/Constants.sol";

import {IRocketTokenRETH} from "interfaces/IRocketTokenRETH.sol";
import {IDiamondCut} from "contracts/interfaces/IDiamondCut.sol";

import {BridgeReth} from "contracts/bridges/BridgeReth.sol";
import {BridgeSteth} from "contracts/bridges/BridgeSteth.sol";

// import {console} from "contracts/libraries/console.sol";

contract ForkHelper is OBFixture {
    using U256 for uint256;

    address[] public persistentAddresses;
    uint256 public forkBlock = 15_333_111;

    uint256 public liquidationBlock = 16_020_111;
    uint256 public bridgeBlock = 18_189_414;
    uint256 public deployBlock = 18_500_000;

    uint256 public mainnetFork;
    uint256 public liquidationFork;
    uint256 public bridgeFork;
    uint256 public deployFork;

    IDiamondCut.FacetCut[] public cutBridge;

    function setUp() public virtual override {
        try vm.envString("MAINNET_RPC_URL") returns (string memory rpcUrl) {
            mainnetFork = vm.createSelectFork(rpcUrl, forkBlock);
            liquidationFork = vm.createFork(rpcUrl, liquidationBlock);
            bridgeFork = vm.createFork(rpcUrl, bridgeBlock);
            deployFork = vm.createFork(rpcUrl, deployBlock);
            assertEq(vm.activeFork(), mainnetFork);
        } catch {
            revert("env: MAINNET_RPC_URL failure");
        }

        _ethAggregator = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
        _steth = address(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
        _unsteth = address(0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1);
        _rocketStorage = address(0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46);

        isMock = false;
        super.setUp();

        rewind(C.STARTING_TIME);
        vm.startPrank(owner);

        //remove mock bridges deployed in DeployHelper
        diamond.deleteBridge(_bridgeSteth);
        diamond.deleteBridge(_bridgeReth);

        bridgeSteth = new BridgeSteth(steth, unsteth, _diamond);
        _bridgeSteth = address(bridgeSteth);

        _reth = rocketStorage.getAddress(keccak256(abi.encodePacked("contract.address", "rocketTokenRETH")));
        reth = IRocketTokenRETH(_reth);

        bridgeReth = new BridgeReth(rocketStorage, _diamond);
        _bridgeReth = address(bridgeReth);

        diamond.createBridge({bridge: _bridgeReth, vault: VAULT.ONE, withdrawalFee: 50});
        diamond.createBridge({bridge: _bridgeSteth, vault: VAULT.ONE, withdrawalFee: 1});
        // Diamond Cut update with real bridges
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

        testFacet.setAssetOracle(_dusd, _ethAggregator);
        diamond.setSecondaryLiquidationCR(_dusd, 140);
        diamond.setPrimaryLiquidationCR(_dusd, 170);
        diamond.setInitialCR(_dusd, 200);

        diamond.setOracleTimeAndPrice(_dusd, uint256(ethAggregator.latestAnswer() * ORACLE_DECIMALS).inv());

        vm.stopPrank();
        persistentAddresses = [
            //deployed
            _diamond,
            _bridgeSteth,
            _bridgeReth,
            _deth,
            _dusd,
            _ditto,
            _diamondCut,
            _diamondLoupe,
            _ownerFacet,
            _viewFacet,
            _yield,
            _vaultFacet,
            _bridgeRouter,
            _shortRecord,
            _askOrders,
            _shortOrders,
            _bidOrders,
            _orders,
            _exitShort,
            _liquidatePrimary,
            _liquidateSecondary,
            _marketShutdown,
            _redemption,
            _twapFacet,
            _testFacet,
            //external
            _steth,
            _reth,
            _unsteth,
            //users
            sender,
            receiver
        ];
        vm.makePersistent(persistentAddresses);
    }
}
