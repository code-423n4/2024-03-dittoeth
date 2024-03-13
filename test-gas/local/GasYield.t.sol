// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {GasHelper} from "test-gas/GasHelper.sol";
import {C} from "contracts/libraries/Constants.sol";
import {IBridge} from "contracts/interfaces/IBridge.sol";

import {console} from "contracts/libraries/console.sol";

contract YieldGasFixture is GasHelper {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(owner);
        diamond.setTithe(ob.vault(), 10);
    }

    function generateYield(uint256 amount) internal {
        IBridge bridgeSteth = IBridge(ob.contracts("bridgeSteth"));
        uint256 startingAmt = bridgeSteth.getDethValue();
        uint256 endingAmt = startingAmt + amount;
        deal(ob.contracts("steth"), ob.contracts("bridgeSteth"), endingAmt);
        diamond.updateYield(ob.vault());
        skip(C.YIELD_DELAY_SECONDS + 1);
    }

    modifier generateShares() {
        ob.fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        ob.skipTimeAndSetEth({skipTime: C.MIN_DURATION + 1, ethPrice: 4000 ether});
        ob.fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        _;
    }

    function testGas_ClaimDittoMatchedReward() public generateShares {
        uint256 vault = ob.vault();
        assertGt(diamond.getVaultUserStruct(vault, receiver).dittoMatchedShares, 0);

        vm.prank(receiver);
        startMeasuringGas("Yield-ClaimDittoMatchedReward");
        diamond.claimDittoMatchedReward(vault);
        stopMeasuringGas();

        assertEq(diamond.getVaultUserStruct(vault, receiver).dittoMatchedShares, 1);
    }

    function testGas_WithdrawDittoReward() public generateShares {
        uint256 vault = ob.vault();
        assertEq(diamond.getVaultUserStruct(vault, receiver).dittoReward, 0);
        vm.prank(receiver);
        diamond.claimDittoMatchedReward(vault);
        assertGt(diamond.getVaultUserStruct(vault, receiver).dittoReward, 0);

        vm.prank(receiver);
        startMeasuringGas("Yield-WithdrawDittoReward");
        diamond.withdrawDittoReward(vault);
        stopMeasuringGas();

        assertEq(diamond.getVaultUserStruct(vault, receiver).dittoReward, 1);
    }

    modifier distributeYieldForShorts(uint256 numShorts) {
        address[] memory assets = new address[](1);
        assets[0] = asset;

        for (uint160 i = 0; i < numShorts; i++) {
            ob.fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
            ob.fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        }

        vm.startPrank(receiver);
        generateYield(DEFAULT_AMOUNT);
        diamond.distributeYield(assets);
        _;
    }

    function testGas_DistributeYield() public distributeYieldForShorts(1) {
        generateYield(DEFAULT_AMOUNT);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        startMeasuringGas("Yield-DistributeYield");
        diamond.distributeYield(assets);
        stopMeasuringGas();
    }

    function testGas_DistributeYieldx2() public distributeYieldForShorts(2) {
        generateYield(DEFAULT_AMOUNT);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        startMeasuringGas("Yield-DistributeYieldx2");
        diamond.distributeYield(assets);
        stopMeasuringGas();
    }

    function testGas_DistributeYieldx4() public distributeYieldForShorts(4) {
        generateYield(DEFAULT_AMOUNT);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        startMeasuringGas("Yield-DistributeYieldx4");
        diamond.distributeYield(assets);
        stopMeasuringGas();
    }

    function testGas_DistributeYieldx16() public distributeYieldForShorts(16) {
        generateYield(DEFAULT_AMOUNT);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        startMeasuringGas("Yield-DistributeYieldx16");
        diamond.distributeYield(assets);
        stopMeasuringGas();
    }
}
