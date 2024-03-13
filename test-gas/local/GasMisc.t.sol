// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {IAsset} from "interfaces/IAsset.sol";
import {IMockAggregatorV3} from "interfaces/IMockAggregatorV3.sol";

import {MTypes, STypes} from "contracts/libraries/DataTypes.sol";
import {VAULT} from "contracts/libraries/Constants.sol";
import {GasHelper} from "test-gas/GasHelper.sol";

import {console} from "contracts/libraries/console.sol";

contract GasCreateOBTest is GasHelper {
    IAsset public cgld;
    address public _cgld;
    IMockAggregatorV3 public cgldAggregator;
    address public _cgldAggregator;

    function setUp() public override {
        super.setUp();

        vm.startPrank(owner);
        _cgld = deployCode("Asset.sol", abi.encode(_diamond, "Ditto Gold", "CGLD"));
        cgld = IAsset(_cgld);
        vm.label(_cgld, "CGLD");
        _cgldAggregator = deployCode("MockAggregatorV3.sol");
        cgldAggregator = IMockAggregatorV3(_cgldAggregator);
        cgldAggregator.setRoundData(
            92233720368547778907 wei, 2000 ether, block.timestamp, block.timestamp, 92233720368547778907 wei
        );
        vm.stopPrank();
    }

    function testGas_CreateMarket() public {
        STypes.Asset memory a;
        a.vault = uint8(VAULT.ONE);
        a.oracle = _cgldAggregator;
        a.initialCR = 400; // 400 -> 4 ether
        a.primaryLiquidationCR = 300; // 300 -> 3 ether
        a.secondaryLiquidationCR = 200; // 200 -> 2 ether
        a.forcedBidPriceBuffer = 120; // 12 -> 1.2 ether
        a.resetLiquidationTime = 14; // 14 -> 14 hours
        a.secondLiquidationTime = 10; // 10 -> 10 hours
        a.firstLiquidationTime = 8; // 8 -> 8 hours
        a.penaltyCR = 110; // 110 -> 1.1 ether
        a.tappFeePct = 25; // 25 -> .025 ether
        a.callerFeePct = 5; // 5 -> .005 ether
        a.minBidEth = 10; // 1 -> .1 ether
        a.minAskEth = 10; // 1 -> .1 ether
        a.minShortErc = 2000; // 2000 -> 2000 ether
        a.recoveryCR = 150; // 150 -> 1.5 ether
        a.dittoTargetCR = 20; // 20 -> 2.0 ether

        address token = _cgld;

        vm.startPrank(owner);
        startMeasuringGas("Owner-CreateMarket");
        diamond.createMarket({asset: token, a: a});
        stopMeasuringGas();
    }

    // 99,274
    // 82,174
    function testGas_CreateBridge() public {
        address _bridgeAddress = address(123);
        vm.startPrank(owner);
        startMeasuringGas("Owner-CreateBridge");
        diamond.createBridge({bridge: _bridgeAddress, vault: VAULT.ONE, withdrawalFee: 50});
        stopMeasuringGas();
    }

    // 78,845
    function testGas_CreateVault() public {
        MTypes.CreateVaultParams memory vaultParams;
        vaultParams.dethTithePercent = 10_00;
        vaultParams.dittoMatchedRate = 0;
        vaultParams.dittoShorterRate = 0;

        vm.prank(owner);
        startMeasuringGas("Owner-CreateVault");
        diamond.createVault({deth: address(1), vault: 2, params: vaultParams});
        stopMeasuringGas();
    }

    function testGas_Mint() public {
        address _sender = sender;
        vm.prank(_diamond);
        startMeasuringGas("Vault-MintAsset");
        dusd.mint(_sender, 1 ether);
        stopMeasuringGas();
    }

    // 52,077
    function testGas_TransferOwnership() public {
        vm.prank(owner);
        startMeasuringGas("Owner-TransferOwnership");
        diamond.transferOwnership(address(1));
        stopMeasuringGas();
    }

    // 35,114
    function testGas_TransferAdminship() public {
        vm.startPrank(owner);
        diamond.transferOwnership(address(1));
        startMeasuringGas("Owner-TransferAdminship");
        diamond.transferAdminship(address(1));
        stopMeasuringGas();
    }
}
