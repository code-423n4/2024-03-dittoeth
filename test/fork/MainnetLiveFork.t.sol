// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {IDiamond, IDiamondCut} from "interfaces/IDiamond.sol";
import {Test} from "forge-std/Test.sol";

interface IDittoTimelockController {
    function schedule(address target, uint256 value, bytes calldata data, bytes32 predecessor, bytes32 salt, uint256 delay)
        external;

    function execute(address target, uint256 value, bytes calldata payload, bytes32 predecessor, bytes32 salt) external;
}

contract MainnetLiveForkTests is Test {
    address internal _timelock = address(0xd177000c8f4D69ada2aCDeCa6fEB15ceA9586A07);
    address internal _safeWallet = address(0xc74487730fCa3f2040cC0f6Fb95348a9B1c19EFc);
    address internal _diamond = address(0xd177000Be70Ea4EfC23987aCD1a79EaBa8b758f1);
    address internal _dusd = address(0xD177000a2BC4F4d2246F0527Ad74Fd4140e029fd);

    IDittoTimelockController internal timelock = IDittoTimelockController(_timelock);
    IDiamond internal diamond = IDiamond(payable(_diamond));
    address internal _viewFacet;
    IDiamondCut.FacetCut[] internal facetCut;
    bytes internal diamondCutPayload;

    string internal rpcUrl;
    uint256 internal currentFork;
    uint256 internal forkBlock;

    function setUp() public virtual {
        try vm.envString("MAINNET_RPC_URL") returns (string memory _rpcUrl) {
            rpcUrl = _rpcUrl;
        } catch {
            revert("env: MAINNET_RPC_URL failure");
        }
    }

    function testFork_TappSrStorageSlot() public {
        forkBlock = 19163790;
        currentFork = vm.createSelectFork(rpcUrl, forkBlock);
        assertEq(vm.activeFork(), currentFork);

        if (forkBlock > 18700000) {
            _viewFacet = deployCode("ViewFacet.sol", abi.encode(_dusd));
        } else {
            revert("check fork block");
        }
        vm.startPrank(_safeWallet);
        bytes4[] memory viewSelectors = new bytes4[](2);
        viewSelectors[0] = IDiamond.getAssetUserStruct.selector;
        viewSelectors[1] = IDiamond.getShortRecord.selector;
        facetCut.push(
            IDiamondCut.FacetCut({
                facetAddress: _viewFacet,
                action: IDiamondCut.FacetCutAction.Replace,
                functionSelectors: viewSelectors
            })
        );
        diamondCutPayload = abi.encodeWithSelector(IDiamond.diamondCut.selector, facetCut, address(0), "");
        timelock.schedule(_diamond, 0, diamondCutPayload, bytes32(0), bytes32(0), 0);
        timelock.execute(_diamond, 0, diamondCutPayload, bytes32(0), bytes32(0));

        //// OLD ////
        // struct AssetUser {
        //     uint104 ercEscrowed;
        //     uint24 g_flaggerId;
        //     uint32 g_flaggedAt;
        //     uint8 shortRecordCounter;
        //     uint88 filler;
        // }

        //// NEW ////
        // struct AssetUser {
        //     uint104 ercEscrowed;
        //     uint56 filler1;
        //     uint8 shortRecordCounter;
        //     uint88 filler2;
        // }

        assertEq(diamond.getAssetUserStruct(_dusd, _diamond).ercEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(_dusd, _diamond).filler1, 0);
        assertEq(diamond.getAssetUserStruct(_dusd, _diamond).shortRecordCounter, 3);
        assertEq(diamond.getAssetUserStruct(_dusd, _diamond).filler2, 0);

        //// OLD ////
        // struct ShortRecord {
        //     // SLOT 1: 88 + 88 + 80 = 256
        //     uint88 collateral;
        //     uint88 ercDebt;
        //     uint80 dethYieldRate;
        //     // SLOT 2: 64 + 40 + 32 + 24 + 8 + 8 + 8 + 8 = 184 (64 remaining)
        //     SR status;
        //     uint8 prevId;
        //     uint8 id;
        //     uint8 nextId;
        //     uint64 ercDebtRate;
        //     uint32 updatedAt;
        //     uint32 flaggedAt;
        //     uint24 flaggerId;
        //     uint40 tokenId;
        // }

        //// NEW ////
        // struct ShortRecord {
        //     // SLOT 1: 88 + 88 + 80 = 256
        //     uint88 collateral;
        //     uint88 ercDebt;
        //     uint80 dethYieldRate;
        //     // SLOT 2: 88 + 64 + 40 + 32 + 8 + 8 + 8 + 8 = 256 (0 remaining)
        //     SR status;
        //     uint8 prevId;
        //     uint8 id;
        //     uint8 nextId;
        //     uint64 ercDebtRate;
        //     uint32 updatedAt;
        //     uint88 ercRedeemed;
        //     uint40 tokenId;
        // }

        assertEq(diamond.getShortRecord(_dusd, _diamond, 2).collateral, 0);
        assertEq(diamond.getShortRecord(_dusd, _diamond, 2).ercDebt, 0);
        assertEq(diamond.getShortRecord(_dusd, _diamond, 2).dethYieldRate, 0);
        assertEq(uint8(diamond.getShortRecord(_dusd, _diamond, 2).status), 1);
        assertEq(diamond.getShortRecord(_dusd, _diamond, 2).prevId, 1);
        assertEq(diamond.getShortRecord(_dusd, _diamond, 2).id, 2);
        assertEq(diamond.getShortRecord(_dusd, _diamond, 2).nextId, 1);
        assertEq(diamond.getShortRecord(_dusd, _diamond, 2).ercDebtRate, 0);
        assertEq(diamond.getShortRecord(_dusd, _diamond, 2).updatedAt, 38430958);
        assertEq(diamond.getShortRecord(_dusd, _diamond, 2).tokenId, 0);

        vm.stopPrank();
    }
}
