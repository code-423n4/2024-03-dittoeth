// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {ISwapRouter} from "contracts/interfaces/ISwapRouter.sol";
import {IWETH} from "contracts/interfaces/IWETH.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {Vm} from "forge-std/Vm.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {ForkHelper} from "test/fork/ForkHelper.sol";
import {C, VAULT} from "contracts/libraries/Constants.sol";

import {console} from "contracts/libraries/console.sol";

contract BridgeRouterTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;

    function setUp() public virtual override {
        super.setUp();

        for (uint160 i; i < users.length; i++) {
            vm.startPrank(users[i]);
            reth.approve(_bridgeReth, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            steth.approve(_bridgeSteth, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            vm.stopPrank();
        }
    }

    function test_GetBaseCollateral() public {
        assertEq(bridgeSteth.getBaseCollateral(), _steth);
        assertEq(
            bridgeReth.getBaseCollateral(),
            rocketStorage.getAddress(keccak256(abi.encodePacked("contract.address", "rocketTokenRETH")))
        );
    }

    function test_BridgeDeposit() public {
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0 ether);
        assertEq(diamond.getVaultUserStruct(vault, receiver).ethEscrowed, 0 ether);
        assertEq(diamond.getVaultStruct(vault).dethTotal, 0 ether);
        assertEq(diamond.getDethTotal(vault), 0 ether);

        deal(sender, 10000 ether);
        deal(_reth, sender, 10000 ether);
        deal(_steth, sender, 10000 ether);

        vm.startPrank(sender);

        uint88 deposit1 = 1000 ether;
        diamond.depositEth{value: deposit1}(_bridgeReth);
        diamond.deposit(_bridgeReth, deposit1);
        diamond.deposit(_bridgeSteth, deposit1);

        s.ethEscrowed = deposit1 * 3;
        assertStruct(sender, s);
        assertStruct(receiver, r);

        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditReth, deposit1 * 2);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditSteth, deposit1);

        assertEq(diamond.getVaultStruct(vault).dethTotal, deposit1 * 3);
        assertEq(diamond.getDethTotal(vault), deposit1 * 3);
        assertEq(bridgeReth.getDethValue(), deposit1 * 2);
        assertEq(bridgeSteth.getDethValue(), deposit1);

        uint88 deposit2 = 1 ether;
        diamond.depositEth{value: deposit2}(_bridgeReth);
        diamond.deposit(_bridgeReth, deposit2);
        diamond.deposit(_bridgeSteth, deposit2);

        vm.stopPrank();

        s.ethEscrowed += deposit2 * 3;
        assertStruct(sender, s);
        assertStruct(receiver, r);

        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditReth, deposit1 * 2 + deposit2 * 2);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditSteth, deposit1 + deposit2);

        assertEq(diamond.getVaultStruct(vault).dethTotal, deposit1 * 3 + deposit2 * 3);
        assertEq(diamond.getDethTotal(vault), deposit1 * 3 + deposit2 * 3);
        assertEq(bridgeReth.getDethValue(), deposit1 * 2 + deposit2 * 2);
        assertEq(bridgeSteth.getDethValue(), deposit1 + deposit2);

        vm.deal(receiver, 10000 ether);
        deal(_reth, receiver, 10000 ether);
        deal(_steth, receiver, 10000 ether);

        vm.startPrank(receiver);

        diamond.depositEth{value: deposit1}(_bridgeReth);
        diamond.deposit(_bridgeReth, deposit1);
        diamond.deposit(_bridgeSteth, deposit1);

        assertStruct(sender, s);
        r.ethEscrowed = deposit1 * 3;
        assertStruct(receiver, r);

        assertEq(diamond.getVaultUserStruct(vault, receiver).bridgeCreditReth, deposit1 * 2);
        assertEq(diamond.getVaultUserStruct(vault, receiver).bridgeCreditSteth, deposit1);

        assertEq(diamond.getVaultStruct(vault).dethTotal, deposit1 * 6 + deposit2 * 3);
        assertEq(diamond.getDethTotal(vault), deposit1 * 6 + deposit2 * 3);
        assertEq(bridgeReth.getDethValue(), deposit1 * 4 + deposit2 * 2);
        assertEq(bridgeSteth.getDethValue(), deposit1 * 2 + deposit2);
    }

    function test_BridgeDepositUpdateYield() public {
        // Fund sender to deposit into bridges
        deal(sender, 1000 ether);
        deal(_reth, sender, 1000 ether);
        deal(_steth, sender, 1000 ether);
        // Seed bridges to set up yield updates
        vm.startPrank(sender);
        diamond.deposit(_bridgeReth, 500 ether);
        diamond.deposit(_bridgeSteth, 500 ether);
        assertEq(diamond.getVaultStruct(vault).dethTotal, 1000 ether);
        assertEq(diamond.getDethTotal(vault), 1000 ether);

        // Update Yield with ETH-RETH deposit
        deal(_steth, _bridgeSteth, 1000 ether); // Mimics 500 ether of yield
        diamond.depositEth{value: 500 ether}(_bridgeReth);
        // With updateYield the totals increase by 1000 instead of just 500
        assertEq(diamond.getVaultStruct(vault).dethTotal, 2000 ether);
        assertEq(diamond.getDethTotal(vault), 2000 ether);

        // Update Yield with ETH-STETH deposit
        deal(_steth, _bridgeSteth, 1500 ether); // Mimics 500 ether of yield
        diamond.depositEth{value: 500 ether}(_bridgeSteth);
        // With updateYield the totals increase by 1000 instead of just 500
        assertEq(diamond.getVaultStruct(vault).dethTotal, 3000 ether);
        assertEq(diamond.getDethTotal(vault), 3000 ether);

        // Update Yield with RETH deposit
        deal(_steth, _bridgeSteth, 2500 ether); // Mimics 500 ether of yield
        diamond.deposit(_bridgeReth, 500 ether);
        // With updateYield the totals increase by 1000 instead of just 500
        assertEq(diamond.getVaultStruct(vault).dethTotal, 4000 ether);
        assertEq(diamond.getDethTotal(vault), 4000 ether);

        // Update Yield with STETH deposit
        deal(_steth, _bridgeSteth, 3000 ether); // Mimics 500 ether of yield
        diamond.deposit(_bridgeSteth, 500 ether);
        // With updateYield the totals increase by 1000 instead of just 500
        assertEq(diamond.getVaultStruct(vault).dethTotal, 5000 ether);
        assertEq(diamond.getDethTotal(vault), 5000 ether);
    }

    function test_BridgeDepositNoUpdateYieldPercent() public {
        // Fund sender to deposit into bridges
        deal(sender, 1000 ether);
        deal(_reth, sender, 1000 ether);
        deal(_steth, sender, 1000 ether);
        // Seed bridges to set up yield updates
        vm.startPrank(sender);
        diamond.deposit(_bridgeReth, 500 ether);
        diamond.deposit(_bridgeSteth, 500 ether);
        assertEq(diamond.getVaultStruct(vault).dethTotal, 1000 ether);
        assertEq(diamond.getDethTotal(vault), 1000 ether);

        // Update Yield with ETH-RETH deposit
        deal(_steth, _bridgeSteth, 1000 ether); // Mimics 500 ether of yield
        diamond.depositEth{value: 1 ether}(_bridgeReth);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(vault).dethTotal, 1001 ether);
        assertEq(diamond.getDethTotal(vault), 1501 ether);

        // Update Yield with ETH-STETH deposit
        deal(_steth, _bridgeSteth, 1500 ether); // Mimics 500 ether of yield
        diamond.depositEth{value: 1 ether}(_bridgeSteth);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(vault).dethTotal, 1002 ether);
        assertEq(diamond.getDethTotal(vault), 2002 ether);

        // Update Yield with RETH deposit
        deal(_steth, _bridgeSteth, 2001 ether); // Mimics 500 ether of yield
        diamond.deposit(_bridgeReth, 1 ether);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(vault).dethTotal, 1003 ether);
        assertEq(diamond.getDethTotal(vault), 2503 ether);

        // Update Yield with STETH deposit
        deal(_steth, _bridgeSteth, 2501 ether); // Mimics 500 ether of yield
        diamond.deposit(_bridgeSteth, 1 ether);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(vault).dethTotal, 1004 ether);
        assertEq(diamond.getDethTotal(vault), 3004 ether);
    }

    function test_BridgeDepositNoUpdateYieldAmount() public {
        // Fund sender to deposit into bridges
        deal(sender, 1000 ether);
        deal(_reth, sender, 1000 ether);
        deal(_steth, sender, 1000 ether);
        // Seed bridges to set up yield updates
        vm.startPrank(sender);
        assertEq(diamond.getVaultStruct(vault).dethTotal, 0 ether);
        assertEq(diamond.getDethTotal(vault), 0 ether);

        // Update Yield with ETH-RETH deposit
        deal(_steth, _bridgeSteth, 100 ether); // Mimics 100 ether of yield
        diamond.depositEth{value: 100 ether}(_bridgeReth);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(vault).dethTotal, 100 ether);
        assertEq(diamond.getDethTotal(vault), 200 ether);

        // Update Yield with ETH-STETH deposit
        deal(_steth, _bridgeSteth, 200 ether); // Mimics 100 ether of yield
        diamond.depositEth{value: 100 ether}(_bridgeSteth);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(vault).dethTotal, 200 ether);
        assertEq(diamond.getDethTotal(vault), 400 ether);

        // Update Yield with RETH deposit
        deal(_steth, _bridgeSteth, 400 ether); // Mimics 100 ether of yield
        diamond.deposit(_bridgeReth, 100 ether);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(vault).dethTotal, 300 ether);
        assertEq(diamond.getDethTotal(vault), 600 ether);

        // Update Yield with STETH deposit
        deal(_steth, _bridgeSteth, 500 ether); // Mimics 100 ether of yield
        diamond.deposit(_bridgeSteth, 100 ether);
        // Without updateYield the total only sees the deposit amount
        assertEq(diamond.getVaultStruct(vault).dethTotal, 400 ether);
        assertEq(diamond.getDethTotal(vault), 800 ether);
    }

    // Bridge Withdrawals
    function bridgeWithdrawSetup() public {
        deal(_reth, sender, 100 ether);
        deal(_steth, sender, 100 ether);

        vm.startPrank(sender);

        diamond.deposit(_bridgeReth, 100 ether);
        diamond.deposit(_bridgeSteth, 100 ether);
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 200 ether);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditReth, 100 ether);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditSteth, 100 ether);
        assertEq(diamond.getVaultStruct(vault).dethTotal, 200 ether);
    }

    function test_BridgeWithdrawWithinCredit() public {
        bridgeWithdrawSetup();

        uint88 withdrawAmount = 50 ether;
        diamond.withdraw(_bridgeReth, withdrawAmount);
        diamond.withdraw(_bridgeSteth, withdrawAmount);

        uint256 totalWithdrawn = withdrawAmount * 2;

        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, totalWithdrawn);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditReth, 50 ether);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditSteth, 50 ether);
        assertEq(diamond.getVaultStruct(vault).dethTotal, totalWithdrawn);
        assertEq(bridgeSteth.getDethValue(), withdrawAmount);
        assertEq(steth.balanceOf(sender), withdrawAmount);
        assertEq(bridgeReth.getDethValue(), withdrawAmount);
        assertEq(reth.balanceOf(sender), withdrawAmount);
    }

    function test_BridgeWithdrawRethPastCreditWithStethCreditLeftover() public {
        bridgeWithdrawSetup();
        // Generate yield and remove STETH bridge balance
        deal(_steth, _bridgeSteth, 0 ether); // Remove 100 ether
        deal(_reth, _bridgeReth, 300 ether); // Add 200 ether (yield)
        diamond.updateYield(vault); // Realize yield
        diamond.setEthEscrowed(sender, 300 ether); // send yield to sender

        // Withdraw RETH using both RETH and STETH credit
        uint88 withdrawAmount = 150 ether;
        diamond.withdraw(_bridgeReth, withdrawAmount);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditReth, 0 ether);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditSteth, 50 ether);

        uint256 feeReth = 0; // Enough STETH credit to cover the difference
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 300 ether - withdrawAmount);
        assertEq(diamond.getVaultStruct(vault).dethTotal, 300 ether - withdrawAmount + feeReth);
        assertEq(bridgeSteth.getDethValue(), 0);
        assertEq(steth.balanceOf(sender), 0);
        assertEq(bridgeReth.getDethValue(), 300 ether - withdrawAmount + feeReth);
        assertEq(reth.balanceOf(sender), withdrawAmount - feeReth);
    }

    function test_BridgeWithdrawRethPastCreditRevert() public {
        bridgeWithdrawSetup();
        // Withdraw RETH past credit balance
        uint88 withdrawAmount = 100 ether + 1 wei;
        vm.expectRevert(Errors.MustUseExistingBridgeCredit.selector);
        diamond.withdraw(_bridgeReth, withdrawAmount);
    }

    function test_BridgeWithdrawStethPastCreditWithStethCreditLeftover() public {
        bridgeWithdrawSetup();
        // Generate yield and remove RETH bridge balance
        deal(_steth, _bridgeSteth, 300 ether); // Add 200 ether (yield)
        deal(_reth, _bridgeReth, 0 ether); // Remove 100 ether
        diamond.updateYield(vault); // Realize yield
        diamond.setEthEscrowed(sender, 300 ether); // send yield to sender

        // Withdraw STETH using both RETH and STETH credit
        uint88 withdrawAmount = 150 ether;
        diamond.withdraw(_bridgeSteth, withdrawAmount);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditReth, 50 ether);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditSteth, 0 ether);

        uint256 feeSteth = 0; // Enough STETH credit to cover the difference
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 300 ether - withdrawAmount);
        assertEq(diamond.getVaultStruct(vault).dethTotal, 300 ether - withdrawAmount + feeSteth);
        assertEq(bridgeSteth.getDethValue(), 300 ether - withdrawAmount + feeSteth);
        assertEq(steth.balanceOf(sender), withdrawAmount - feeSteth);
        assertEq(bridgeReth.getDethValue(), 0);
        assertEq(reth.balanceOf(sender), 0);
    }

    function test_BridgeWithdrawStethPastCreditRevert() public {
        bridgeWithdrawSetup();
        // Withdraw STETH past credit balance
        uint88 withdrawAmount = 100 ether + 1 wei;
        vm.expectRevert(Errors.MustUseExistingBridgeCredit.selector);
        diamond.withdraw(_bridgeSteth, withdrawAmount);
    }

    function test_BridgeWithdrawTapp() public {
        bridgeWithdrawSetup();

        // Generate Yield to TAPP
        deal(_steth, _bridgeSteth, 200 ether); // Mimics 100 ether of yield
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 0);
        diamond.updateYield(vault); // All yield goes to TAPP bc no shorts
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 100 ether);

        // DAO withdraws STETH from TAPP balance
        assertEq(steth.balanceOf(owner), 0);
        vm.startPrank(owner);
        diamond.withdrawTapp(_bridgeSteth, 100 ether);
        assertEq(steth.balanceOf(owner), 100 ether);
    }

    function test_BridgeWithdrawNegativeYieldWithinCredit() public {
        bridgeWithdrawSetup();
        // Negative Yield
        reth.submitBalances(50 ether, 100 ether);
        deal(_steth, _bridgeSteth, 50 ether);
        assertEq(bridgeReth.getDethValue(), 50 ether);
        assertEq(bridgeSteth.getDethValue(), 50 ether);

        uint88 withdrawAmount = 50 ether;
        diamond.withdraw(_bridgeSteth, withdrawAmount);
        diamond.withdraw(_bridgeReth, withdrawAmount);

        uint256 totalWithdrawn = withdrawAmount * 2;
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, totalWithdrawn, "1");
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 0);
        assertEq(diamond.getVaultStruct(vault).dethTotal, totalWithdrawn, "2");
        assertEq(bridgeSteth.getDethValue(), 25 ether, "3");
        assertEq(steth.balanceOf(sender), 25 ether, "4");
        assertEq(bridgeReth.getDethValue(), 25 ether, "5");
        assertEq(reth.balanceOf(sender), 50 ether, "6");
    }

    // @dev Just a simple check for overflow in the function _ethConversion()
    function test_BridgeWithdrawNegativeYieldLargeAmount() public {
        uint88 amount = 10000000 ether;
        deal(_steth, sender, amount);

        vm.startPrank(sender);

        diamond.deposit(_bridgeSteth, amount);
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, amount);
        assertEq(diamond.getVaultStruct(vault).dethTotal, amount);
        // Negative Yield
        deal(_steth, _bridgeSteth, amount - 1 wei);
        assertEq(bridgeSteth.getDethValue(), amount - 1 wei);

        uint88 withdrawAmount = amount;
        diamond.withdraw(_bridgeSteth, withdrawAmount);
    }

    function test_DepositToRocketPoolMsgValue() public {
        deal(_reth, sender, 100 ether);
        vm.startPrank(sender);

        uint88 sentAmount = 100 ether;

        uint256 rethBalance1 = reth.balanceOf(_bridgeReth);
        diamond.deposit(_bridgeReth, sentAmount);
        uint256 rethBalance2 = reth.balanceOf(_bridgeReth);
        assertGt(rethBalance2, rethBalance1);
        uint256 dethValue = reth.getEthValue(rethBalance2 - rethBalance1);
        assertEq(sentAmount, dethValue);
    }
}

contract BridgeRouterForkTest is ForkHelper {
    using U256 for uint256;
    using U88 for uint88;

    uint88 initialDeposit;
    uint88 bridgeCreditReth;
    uint88 bridgeCreditSteth;
    address public constant UNIV3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    function setUp() public virtual override {
        forkBlock = bridgeBlock;
        super.setUp();

        initialDeposit = 100 ether;
        deal(sender, initialDeposit);

        // Confirm rETH has market premium relative to stETH
        assertGt(diamond.getWithdrawalFeePct(VAULT.BRIDGE_RETH, _bridgeReth, _bridgeSteth), 0);
        assertEq(diamond.getWithdrawalFeePct(VAULT.BRIDGE_STETH, _bridgeReth, _bridgeSteth), 0);
    }

    function bridgeWithdrawSetup() public {
        vm.startPrank(sender);
        // Just give rETH bc deposit pool is full in this block
        deal(_reth, sender, initialDeposit);
        reth.approve(_bridgeReth, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

        diamond.deposit(_bridgeReth, initialDeposit);
        // Get stETH the "real" way
        diamond.depositEth{value: initialDeposit}(_bridgeSteth);

        bridgeCreditReth = initialDeposit.mulU88(bridgeReth.getUnitDethValue()) + 1 wei; // rounding
        bridgeCreditSteth = initialDeposit - 1 wei; // rounding
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, bridgeCreditReth + bridgeCreditSteth);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditReth, bridgeCreditReth);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditSteth, bridgeCreditSteth);
        assertEq(diamond.getVaultStruct(vault).dethTotal, bridgeCreditReth + bridgeCreditSteth);
    }

    function zeroBridge(uint256 bridgeToZero) public {
        if (bridgeToZero == VAULT.BRIDGE_RETH) {
            diamond.setEthEscrowed(extra, bridgeCreditReth);
            diamond.setBridgeCredit(extra, bridgeCreditReth, 0);
            vm.startPrank(extra);
            diamond.withdraw(_bridgeReth, bridgeCreditReth);
            vm.startPrank(sender);
        } else {
            diamond.setEthEscrowed(extra, bridgeCreditSteth);
            diamond.setBridgeCredit(extra, 0, bridgeCreditSteth);
            vm.startPrank(extra);
            diamond.withdraw(_bridgeSteth, bridgeCreditSteth);
            vm.startPrank(sender);
        }
    }

    function generateYield(uint256 bridge, uint256 amount) public returns (uint88) {
        if (bridge == VAULT.BRIDGE_RETH) {
            uint88 senderAmt = uint88(initialDeposit + amount);
            uint256 senderAmtInReth = reth.getRethValue(senderAmt);
            deal(_reth, _bridgeReth, senderAmtInReth);
            diamond.updateYield(vault);
            diamond.setEthEscrowed(sender, senderAmt); // send yield to sender
            return senderAmt;
        } else {
            // Fake yield with deposit from extra
            // @dev can't use vm.deal with rebasing token
            deal(extra, amount);
            vm.stopPrank();
            vm.startPrank(extra);
            diamond.depositEth{value: amount}(_bridgeSteth);
            vm.startPrank(sender);
            // Send fake yield to sender
            uint88 senderAmt = uint88(bridgeCreditSteth + amount - 1 wei); // Account for rounding
            diamond.setEthEscrowed(sender, senderAmt);
            return senderAmt;
        }
    }

    function checkAsserts(uint256 bridge, uint256 assessableAmt, uint256 senderAmt) public {
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditReth, 0 ether);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditSteth, 0 ether);
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0);
        uint256 feeP = diamond.getWithdrawalFeePct(bridge, _bridgeReth, _bridgeSteth);
        uint256 fee = feeP.mul(assessableAmt);
        uint256 withdrawAmt = senderAmt - fee;
        assertEq(diamond.getVaultStruct(vault).dethTotal, fee);
        assertGt(assessableAmt, fee);
        if (bridge == VAULT.BRIDGE_RETH) {
            assertApproxEqAbs(bridgeReth.getDethValue(), fee, MAX_DELTA_SMALL);
            assertApproxEqAbs(reth.balanceOf(sender), reth.getRethValue(withdrawAmt), MAX_DELTA_SMALL);
        } else {
            assertApproxEqAbs(bridgeSteth.getDethValue(), fee, MAX_DELTA_SMALL);
            assertApproxEqAbs(steth.balanceOf(sender), withdrawAmt, MAX_DELTA_SMALL);
        }
    }

    function fakeStethPremium() public {
        ISwapRouter v3router = ISwapRouter(UNIV3_ROUTER);

        IWETH weth = IWETH(C.WETH);
        IERC20 wstETH = IERC20(VAULT.WSTETH);

        uint24 fee = 100;

        uint256 amount = 9000 ether;
        // Fund WETH
        deal(extra, amount);
        vm.startPrank(extra);
        weth.deposit{value: amount}();
        weth.approve(UNIV3_ROUTER, type(uint256).max);
        // Swap to increase stETH premium
        uint256 _before = wstETH.balanceOf(extra);
        v3router.exactInput(
            ISwapRouter.ExactInputParams({
                path: abi.encodePacked(C.WETH, fee, VAULT.WSTETH),
                recipient: extra,
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: 0
            })
        );
        uint256 _after = wstETH.balanceOf(extra);
        assertGt(_after, _before);

        skip(30 minutes); // Update TWAP
        // Confirm stETH has market premium relative to rETH
        assertEq(diamond.getWithdrawalFeePct(VAULT.BRIDGE_RETH, _bridgeReth, _bridgeSteth), 0);
        assertGt(diamond.getWithdrawalFeePct(VAULT.BRIDGE_STETH, _bridgeReth, _bridgeSteth), 0);
    }

    /// rETH Premium
    function testFork_BridgeWithdrawRethPastCredit() public {
        bridgeWithdrawSetup();
        // Use STETH credit
        diamond.withdraw(_bridgeSteth, bridgeCreditSteth);
        // Generate yield
        uint88 senderAmt = generateYield(VAULT.BRIDGE_RETH, 200 ether);
        // Withdraw RETH using just RETH credit
        diamond.withdraw(_bridgeReth, senderAmt);
        // Check Asserts
        uint256 assessableAmt = senderAmt - bridgeCreditReth;
        checkAsserts(VAULT.BRIDGE_RETH, assessableAmt, senderAmt);
    }

    function testFork_BridgeWithdrawRethPastCreditWithStethCreditNoLeftover() public {
        bridgeWithdrawSetup();
        // Artificially zero out stEth bridge balance
        zeroBridge(VAULT.BRIDGE_STETH);
        // Generate yield
        uint88 senderAmt = generateYield(VAULT.BRIDGE_RETH, 200 ether);
        // Withdraw RETH using both RETH and STETH credit
        diamond.withdraw(_bridgeReth, senderAmt);
        // Check Asserts
        uint256 assessableAmt = senderAmt - bridgeCreditReth - bridgeCreditSteth;
        checkAsserts(VAULT.BRIDGE_RETH, assessableAmt, senderAmt);
    }

    function testFork_BridgeWithdrawStethPastCredit() public {
        bridgeWithdrawSetup();
        // Use RETH credit
        diamond.withdraw(_bridgeReth, bridgeCreditReth);
        // Generate Yield
        uint88 senderAmt = generateYield(VAULT.BRIDGE_STETH, 200 ether);
        // Withdraw STETH using just STETH credit
        diamond.withdraw(_bridgeSteth, senderAmt);
        // Check Asserts
        uint256 assessableAmt = senderAmt - bridgeCreditSteth;
        checkAsserts(VAULT.BRIDGE_STETH, assessableAmt, senderAmt);
    }

    function testFork_BridgeWithdrawStethPastCreditWithRethCreditNoLeftover() public {
        bridgeWithdrawSetup();
        // Artificially zero out rETH bridge balance
        zeroBridge(VAULT.BRIDGE_RETH);
        // Generate Yield
        uint88 senderAmt = generateYield(VAULT.BRIDGE_STETH, 200 ether);
        // Withdraw STETH using both RETH and STETH credit
        diamond.withdraw(_bridgeSteth, senderAmt);
        // Check Asserts
        uint256 assessableAmt = senderAmt - bridgeCreditSteth - bridgeCreditReth;
        checkAsserts(VAULT.BRIDGE_STETH, assessableAmt, senderAmt);
    }

    function testFork_BridgeWithdrawRethPastCreditNegativeYield() public {
        bridgeWithdrawSetup();
        // Use STETH credit
        diamond.withdraw(_bridgeSteth, bridgeCreditSteth);
        assertEq(diamond.getVaultUserStruct(vault, sender).bridgeCreditSteth, 0 ether);
        // Generate Yield
        uint88 senderAmt = generateYield(VAULT.BRIDGE_RETH, 200 ether); // 300 ether total
        // Negative Yield
        uint256 negYieldAmt = reth.getRethValue(150 ether); // -150 ether of slashing
        deal(_reth, _bridgeReth, negYieldAmt);
        uint256 negYieldFactor = (bridgeReth.getDethValue()).div(senderAmt);
        // Withdraw RETH past credit
        diamond.withdraw(_bridgeReth, senderAmt);
        // Check Asserts
        uint256 assessableAmt = senderAmt - bridgeCreditReth;
        uint256 feeP = diamond.getWithdrawalFeePct(VAULT.BRIDGE_RETH, _bridgeReth, _bridgeSteth);
        uint256 fee = feeP.mul(assessableAmt);
        uint256 withdrawAmtInEth = (senderAmt - fee).mul(negYieldFactor);
        uint256 withdrawAmtInReth = reth.getRethValue(withdrawAmtInEth);
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0, "1");
        assertEq(diamond.getVaultStruct(vault).dethTotal, fee, "2");
        assertApproxEqAbs(bridgeSteth.getDethValue(), 0, MAX_DELTA_SMALL, "3");
        assertApproxEqAbs(steth.balanceOf(sender), initialDeposit, MAX_DELTA_SMALL, "4");
        assertApproxEqAbs(bridgeReth.getDethValue(), fee.mul(negYieldFactor), MAX_DELTA_SMALL, "5");
        assertApproxEqAbs(reth.balanceOf(sender), withdrawAmtInReth, MAX_DELTA, "6");
    }

    function testFork_BridgeWithdrawStethPastCreditNegativeYield() public {
        bridgeWithdrawSetup();
        // Generate Yield
        uint88 senderAmt = generateYield(VAULT.BRIDGE_STETH, 200 ether); // 300 ether total
        senderAmt += bridgeCreditReth;
        diamond.setEthEscrowed(sender, senderAmt);
        // Negative Yield
        deal(_reth, _bridgeReth, 0); // -100 ether of slashing
        diamond.updateYield(vault); // Realize slashing
        uint256 negYieldFactor = (bridgeSteth.getDethValue()).div(senderAmt);
        // Withdraw STETH past credit
        diamond.withdraw(_bridgeSteth, senderAmt);
        // Check Asserts
        uint256 assessableAmt = senderAmt - bridgeCreditReth - bridgeCreditSteth;
        uint256 feeP = diamond.getWithdrawalFeePct(VAULT.BRIDGE_STETH, _bridgeReth, _bridgeSteth);
        uint256 fee = feeP.mul(assessableAmt);
        uint256 withdrawAmtInEth = (senderAmt - fee).mul(negYieldFactor);
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 0, "1");
        assertEq(diamond.getVaultStruct(vault).dethTotal, fee, "2");
        assertApproxEqAbs(bridgeSteth.getDethValue(), fee.mul(negYieldFactor), MAX_DELTA, "3");
        assertApproxEqAbs(steth.balanceOf(sender), withdrawAmtInEth, MAX_DELTA, "4");
        assertApproxEqAbs(bridgeReth.getDethValue(), 0, MAX_DELTA_SMALL, "5");
        assertApproxEqAbs(reth.balanceOf(sender), 0, MAX_DELTA, "6");
    }

    /// stETH Premium
    function testFork_BridgeWithdrawRethPastCredit_StethPremium() public {
        fakeStethPremium();
        testFork_BridgeWithdrawRethPastCredit();
    }

    function testFork_BridgeWithdrawRethPastCreditWithStethCreditNoLeftover_StethPremium() public {
        fakeStethPremium();
        testFork_BridgeWithdrawRethPastCreditWithStethCreditNoLeftover();
    }

    function testFork_BridgeWithdrawStethPastCredit_StethPremium() public {
        fakeStethPremium();
        testFork_BridgeWithdrawStethPastCredit();
    }

    function testFork_BridgeWithdrawStethPastCreditWithRethCreditNoLeftover_StethPremium() public {
        fakeStethPremium();
        testFork_BridgeWithdrawStethPastCreditWithRethCreditNoLeftover();
    }

    function testFork_BridgeWithdrawRethPastCreditNegativeYield_StethPremium() public {
        fakeStethPremium();
        testFork_BridgeWithdrawRethPastCreditNegativeYield();
    }

    function testFork_BridgeWithdrawStethPastCreditNegativeYield_StethPremium() public {
        fakeStethPremium();
        testFork_BridgeWithdrawStethPastCreditNegativeYield();
    }
}
