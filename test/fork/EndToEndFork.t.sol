// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {ForkHelper} from "test/fork/ForkHelper.sol";
import {VAULT} from "contracts/libraries/Constants.sol";
import {MTypes, STypes, SR} from "contracts/libraries/DataTypes.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {console} from "contracts/libraries/console.sol";

contract EndToEndForkTest is ForkHelper {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    //current price at block 15_333_111 above using chainlink
    uint256 public currentEthPriceUSD = 1992.70190598 ether;
    uint16[] public shortHints = new uint16[](1);
    uint256 public receiverPostCollateral;
    uint256 public receiverEthEscrowed;
    uint80 public currentPrice;

    function setUp() public virtual override {
        super.setUp();

        assertApproxEqAbs(diamond.getOraclePriceT(_dusd), currentEthPriceUSD.inv(), MAX_DELTA_SMALL);
        deal(sender, 1000 ether);
        deal(receiver, 1000 ether);
    }

    function testFork_EndToEnd() public {
        uint16 dusdInitialCR = diamond.getAssetStruct(_dusd).initialCR;
        //sender
        //Workflow: Bridge - DepositEth
        vm.startPrank(sender);
        assertEq(reth.balanceOf(_bridgeReth), 0);
        diamond.depositEth{value: 500 ether}(_bridgeReth);
        assertEq(reth.balanceOf(_bridgeReth), reth.getRethValue(500 ether));
        assertEq(sender.balance, 1000 ether - 500 ether);
        uint256 senderEthEscrowed = diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed;
        assertApproxEqAbs(senderEthEscrowed, 500 ether, MAX_DELTA_SMALL);
        assertApproxEqAbs(diamond.getVaultStruct(VAULT.ONE).dethTotal, 500 ether, MAX_DELTA_SMALL);
        vm.stopPrank();

        //receiver
        vm.startPrank(receiver);
        assertEq(steth.balanceOf(_bridgeSteth), 0);
        diamond.depositEth{value: 500 ether}(_bridgeSteth);
        assertApproxEqAbs(steth.balanceOf(_bridgeSteth), 500 ether, MAX_DELTA_SMALL);
        assertEq(receiver.balance, 1000 ether - 500 ether);
        receiverEthEscrowed = diamond.getVaultUserStruct(VAULT.ONE, receiver).ethEscrowed;
        assertApproxEqAbs(receiverEthEscrowed, 500 ether, MAX_DELTA_SMALL);
        assertApproxEqAbs(diamond.getVaultStruct(VAULT.ONE).dethTotal, 1000 ether, MAX_DELTA_SMALL);

        //Workflow: MARKET - LimitShort
        MTypes.OrderHint[] memory orderHints = new MTypes.OrderHint[](1);
        currentPrice = diamond.getOraclePriceT(_dusd);
        assertApproxEqAbs(currentPrice.mul(100_000 ether), (uint256(100_000 ether)).div(currentEthPriceUSD), 0.00000001 ether);

        diamond.createLimitShort(_dusd, currentPrice, 100_000 ether, orderHints, shortHints, dusdInitialCR);
        receiverPostCollateral = diamond.getAssetNormalizedStruct(asset).initialCR.mul(currentPrice.mul(100_000 ether));
        receiverEthEscrowed -= receiverPostCollateral;
        assertApproxEqAbs(diamond.getVaultUserStruct(VAULT.ONE, receiver).ethEscrowed, receiverEthEscrowed, MAX_DELTA_SMALL);
        vm.stopPrank();

        //Workflow: MARKET - LimitBid
        //sender
        vm.startPrank(sender);
        shortHints[0] = diamond.getShortIdAtOracle(_dusd);
        diamond.createBid(_dusd, currentPrice, 50_000 ether, false, orderHints, shortHints);
        senderEthEscrowed -= currentPrice.mul(50_000 ether);
        assertApproxEqAbs(diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed, senderEthEscrowed, MAX_DELTA_SMALL);
        assertApproxEqAbs(diamond.getAssetUserStruct(_dusd, sender).ercEscrowed, 50_000 ether, MAX_DELTA_SMALL);
        diamond.createBid(_dusd, currentPrice, 50_000 ether, false, orderHints, shortHints);
        senderEthEscrowed -= currentPrice.mul(50_000 ether);
        assertApproxEqAbs(diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed, senderEthEscrowed, MAX_DELTA_SMALL);
        assertApproxEqAbs(diamond.getAssetUserStruct(_dusd, sender).ercEscrowed, 100_000 ether, MAX_DELTA_SMALL);
        assertEq(diamond.getShorts(_dusd).length, 0);

        STypes.ShortRecord memory receiverShort = diamond.getShortRecords(_dusd, receiver)[0];
        assertEq(receiverShort.ercDebt, 100_000 ether);
        assertEq(receiverShort.collateral, receiverPostCollateral + currentPrice.mul(100_000 ether));
        assertSR(SR.FullyFilled, receiverShort.status);

        //Workflow: VAULT - Withdraw DUSD
        assertEq(dusd.balanceOf(sender), 0);
        diamond.withdrawAsset(_dusd, 100000 ether);
        assertEq(diamond.getAssetUserStruct(_dusd, sender).ercEscrowed, 0);
        assertEq(dusd.balanceOf(sender), 100_000 ether);

        assertEq(diamond.getAssetStruct(_dusd).ercDebt, 100_000 ether);
        assertApproxEqAbs(diamond.getVaultStruct(VAULT.ONE).dethTotal, 1000 ether, MAX_DELTA_SMALL);
        vm.stopPrank();

        //receiver
        //Workflow: ShortRecord - Decrease Collateral
        vm.prank(receiver);
        diamond.decreaseCollateral(_dusd, 2, 40 ether);
        receiverEthEscrowed += 40 ether;
        receiverShort.collateral -= 40 ether;
        assertApproxEqAbs(diamond.getVaultUserStruct(VAULT.ONE, receiver).ethEscrowed, receiverEthEscrowed, MAX_DELTA_SMALL);
        assertEq(receiverShort.collateral, diamond.getShortRecords(_dusd, receiver)[0].collateral);
        vm.prank(sender);
        vm.expectRevert(Errors.SufficientCollateral.selector);
        diamond.liquidate(_dusd, receiver, 2, shortHints, 0);

        //Move fork to liquidation block
        vm.selectFork(liquidationFork);
        diamond.setOracleTimeAndPrice(_dusd, uint256(ethAggregator.latestAnswer() * ORACLE_DECIMALS).inv());
        assertLt(
            diamond.getCollateralRatio(_dusd, diamond.getShortRecord(_dusd, receiver, 2)),
            diamond.getAssetNormalizedStruct(asset).initialCR
        );

        //Workflow: Yield
        //receiver
        vm.startPrank(receiver);
        STypes.Vault memory oldVault = diamond.getVaultStruct(VAULT.ONE);
        assertEq(diamond.getVaultUserStruct(VAULT.ONE, receiver).dittoReward, 0);

        diamond.updateYield(VAULT.ONE);
        address[] memory assetArr = new address[](1);
        assetArr[0] = _dusd;
        diamond.distributeYield(assetArr);

        STypes.Vault memory newVault = diamond.getVaultStruct(VAULT.ONE);
        assertLt(oldVault.dethYieldRate, newVault.dethYieldRate);
        assertLt(oldVault.dethTotal, newVault.dethTotal);
        assertLt(oldVault.dethCollateralReward, newVault.dethCollateralReward);
        assertGt(diamond.getVaultUserStruct(VAULT.ONE, receiver).ethEscrowed, receiverEthEscrowed);
        receiverEthEscrowed = diamond.getVaultUserStruct(VAULT.ONE, receiver).ethEscrowed;

        assertGt(diamond.getVaultUserStruct(VAULT.ONE, receiver).dittoReward, 1);
        assertEq(ditto.balanceOf(receiver), 0);
        diamond.withdrawDittoReward(VAULT.ONE);
        assertEq(diamond.getVaultUserStruct(VAULT.ONE, receiver).dittoReward, 1);
        assertGt(ditto.balanceOf(receiver), 0);

        uint256 tappEscrow = diamond.getVaultUserStruct(VAULT.ONE, _diamond).ethEscrowed;
        assertGt(tappEscrow, 0);

        //Workflow: ShortRecord - Increase Collateral
        diamond.increaseCollateral(_dusd, 2, 5 ether);
        receiverEthEscrowed -= 5 ether;
        receiverShort.collateral += 5 ether;
        assertApproxEqAbs(diamond.getVaultUserStruct(VAULT.ONE, receiver).ethEscrowed, receiverEthEscrowed, MAX_DELTA_SMALL);
        assertEq(receiverShort.collateral, diamond.getShortRecords(_dusd, receiver)[0].collateral);
        vm.stopPrank();

        //sender
        //Workflow: VAULT - Deposit DUSD
        vm.startPrank(sender);

        assertEq(dusd.balanceOf(sender), 100_000 ether);
        diamond.depositAsset(_dusd, 100_000 ether);
        assertEq(diamond.getAssetUserStruct(_dusd, sender).ercEscrowed, 100_000 ether);
        assertEq(dusd.balanceOf(sender), 0);
        assertEq(diamond.getAssetStruct(_dusd).ercDebt, 100_000 ether);
        assertGt(diamond.getVaultStruct(VAULT.ONE).dethTotal, 1000 ether);

        //Workflow: Market - Limit Ask
        diamond.createAsk(_dusd, uint80(diamond.getOracleAssetPrice(_dusd)), 10_000 ether, false, orderHints);
        assertEq(diamond.getAssetUserStruct(_dusd, sender).ercEscrowed, 90_000 ether);
        assertEq(diamond.getAsks(_dusd).length, 1);
        assertEq(diamond.getAsks(_dusd)[0].ercAmount, 10_000 ether);
        vm.stopPrank();

        //receiver
        //Workflow: Market - Limit Bid
        vm.startPrank(receiver);
        diamond.createBid(_dusd, uint80(diamond.getOracleAssetPrice(_dusd)), 1_000 ether, false, orderHints, shortHints);
        uint256 bidEth = diamond.getOracleAssetPrice(_dusd).mul(1_000 ether);
        receiverEthEscrowed -= bidEth;
        senderEthEscrowed += bidEth;
        assertEq(diamond.getAsks(_dusd)[0].ercAmount, 10_000 ether - 1_000 ether);
        assertEq(diamond.getAssetUserStruct(_dusd, receiver).ercEscrowed, 1_000 ether);
        assertApproxEqAbs(diamond.getVaultUserStruct(VAULT.ONE, receiver).ethEscrowed, receiverEthEscrowed, MAX_DELTA_SMALL);
        assertApproxEqAbs(diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed, senderEthEscrowed, MAX_DELTA_SMALL);

        //Workflow: ExitShort - Escrow / Wallet / Orderbook
        assertEq(receiverShort.ercDebt, 100_000 ether);

        diamond.withdrawAsset(_dusd, 500 ether);
        assertEq(diamond.getAssetUserStruct(_dusd, receiver).ercEscrowed, 500 ether);
        diamond.exitShortErcEscrowed(_dusd, 2, 500 ether, 0);
        receiverShort.ercDebt -= 500 ether;
        assertEq(diamond.getShortRecords(_dusd, receiver)[0].ercDebt, receiverShort.ercDebt);
        assertEq(diamond.getAssetUserStruct(_dusd, receiver).ercEscrowed, 0);
        assertEq(dusd.balanceOf(receiver), 500 ether);
        diamond.exitShortWallet(_dusd, 2, 500 ether, 0);
        assertEq(dusd.balanceOf(receiver), 0);
        receiverShort.ercDebt -= 500 ether;
        assertEq(diamond.getShortRecords(_dusd, receiver)[0].ercDebt, receiverShort.ercDebt);
        diamond.exitShort(_dusd, 2, 500 ether, uint80(diamond.getOracleAssetPrice(_dusd)), shortHints, 0);
        receiverShort.ercDebt -= 500 ether;
        receiverShort.collateral -= uint80(diamond.getOracleAssetPrice(_dusd).mul(500 ether));
        senderEthEscrowed += diamond.getOracleAssetPrice(_dusd).mul(500 ether);
        assertEq(diamond.getShortRecords(_dusd, receiver)[0].ercDebt, receiverShort.ercDebt);
        assertEq(receiverShort.collateral, diamond.getShortRecords(_dusd, receiver)[0].collateral);
        assertApproxEqAbs(diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed, senderEthEscrowed, MAX_DELTA_SMALL);
        vm.stopPrank();

        //sender
        //Workflow:  Partial Liquidation
        vm.startPrank(sender);

        assertEq(diamond.getShortRecords(_dusd, receiver)[0].updatedAt, diamond.getOffsetTime());

        currentPrice = uint80(diamond.getOracleAssetPrice(_dusd));
        skip(10.2 hours);

        (uint256 liquidateGas,) = diamond.liquidate(_dusd, receiver, 2, shortHints, 0);
        receiverShort.ercDebt -= 8500 ether;
        // .00015691 accounts for gas fee
        receiverShort.collateral -= uint80(currentPrice.mul(8500 ether).mul(1.03 ether) + liquidateGas);
        tappEscrow += currentPrice.mul(8500 ether).mul(0.025 ether);
        senderEthEscrowed += (currentPrice.mul(8500 ether).mul(1.005 ether) + liquidateGas);
        assertEq(diamond.getShortRecords(_dusd, receiver)[0].ercDebt, receiverShort.ercDebt);
        assertApproxEqAbs(receiverShort.collateral, diamond.getShortRecords(_dusd, receiver)[0].collateral, MAX_DELTA_SMALL);
        assertEq(
            // _diamond is TAPP
            diamond.getVaultUserStruct(VAULT.ONE, _diamond).ethEscrowed,
            tappEscrow
        );
        assertEq(diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed, senderEthEscrowed);

        //Workflow: Secondary Liquidation
        MTypes.BatchLiquidation[] memory batchLiquidation = new MTypes.BatchLiquidation[](1);
        batchLiquidation[0] = MTypes.BatchLiquidation({shorter: receiver, shortId: 2, shortOrderId: 0});
        diamond.liquidateSecondary(_dusd, batchLiquidation, 90_000 ether, false);
        receiverShort.collateral -= uint80(diamond.getProtocolAssetPrice(_dusd).mul(90_000 ether));
        senderEthEscrowed += diamond.getProtocolAssetPrice(_dusd).mul(90_000 ether);
        receiverEthEscrowed += receiverShort.collateral;
        assertEq(diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed, senderEthEscrowed);
        assertApproxEqAbs(diamond.getVaultUserStruct(VAULT.ONE, receiver).ethEscrowed, receiverEthEscrowed, MAX_DELTA);
        receiverEthEscrowed = diamond.getVaultUserStruct(VAULT.ONE, receiver).ethEscrowed;

        assertEq(diamond.getAsks(_dusd).length, 0);
        assertEq(diamond.getBids(_dusd).length, 0);
        assertEq(diamond.getShorts(_dusd).length, 0);
        assertEq(diamond.getShortRecordCount(_dusd, receiver), 0);
        assertEq(diamond.getShortRecordCount(_dusd, sender), 0);
        assertEq(diamond.getAssetUserStruct(_dusd, sender).ercEscrowed, 0);
        assertEq(diamond.getAssetUserStruct(_dusd, receiver).ercEscrowed, 0);
        assertSR(diamond.getShortRecord(_dusd, receiver, 2).status, SR.Closed);

        vm.selectFork(bridgeFork);

        // Workflow: Bridge Reth - Withdraw
        uint256 credit = diamond.getVaultUserStruct(vault, sender).bridgeCreditReth;
        uint88 withdraw = 501 ether; // leave some for STETH withdraw
        uint256 fee = (withdraw - credit).mul(diamond.getWithdrawalFeePct(VAULT.BRIDGE_RETH, _bridgeReth, _bridgeSteth));
        diamond.withdraw(_bridgeReth, withdraw);
        senderEthEscrowed -= withdraw;
        assertEq(diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed, senderEthEscrowed);
        assertEq(reth.balanceOf(sender), reth.getRethValue(withdraw - fee));

        // Workflow: Bridge Steth - Withdraw
        withdraw = diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed;
        fee = withdraw.mul(diamond.getWithdrawalFeePct(VAULT.BRIDGE_STETH, _bridgeReth, _bridgeSteth));
        diamond.withdraw(_bridgeSteth, withdraw);
        senderEthEscrowed -= withdraw;
        assertEq(diamond.getVaultUserStruct(VAULT.ONE, sender).ethEscrowed, senderEthEscrowed);
        assertEq(steth.balanceOf(_bridgeSteth), 500 ether - withdraw + fee);
        assertApproxEqAbs(steth.balanceOf(sender), withdraw - fee, MAX_DELTA_SMALL);

        //receiver
        vm.startPrank(receiver);
        withdraw = 100 ether;
        diamond.withdraw(_bridgeSteth, withdraw);
        receiverEthEscrowed -= withdraw;
        assertEq(diamond.getVaultUserStruct(VAULT.ONE, receiver).ethEscrowed, receiverEthEscrowed);
        assertApproxEqAbs(steth.balanceOf(receiver), withdraw, MAX_DELTA_SMALL);
    }
}
