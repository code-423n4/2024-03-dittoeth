// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {C, VAULT} from "contracts/libraries/Constants.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {console} from "contracts/libraries/console.sol";

contract YieldTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    bool private constant BID_FIRST = true;
    bool private constant SHORT_FIRST = false;
    bool public distributed = false;

    uint256 public skipTime = C.MIN_DURATION + 1;
    uint256 public yieldEligibleTime = C.YIELD_DELAY_SECONDS + 1;

    function setUp() public virtual override {
        super.setUp();

        // Fund addresses
        for (uint160 i; i < users.length; i++) {
            depositUsd(users[i], DEFAULT_AMOUNT.mulU88(4000 ether));

            deal(users[i], 250 ether);
            deal(_reth, users[i], 250 ether);
            deal(_steth, users[i], 500 ether);

            vm.startPrank(users[i], users[i]);
            reth.approve(_bridgeReth, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
            steth.approve(_bridgeSteth, 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);

            diamond.depositEth{value: 250 ether}(_bridgeReth);
            diamond.deposit(_bridgeReth, 250 ether);
            diamond.deposit(_bridgeSteth, 500 ether);
            vm.stopPrank();
        }
    }

    function generateYield(uint256 amount) internal {
        uint256 startingAmt = bridgeSteth.getDethValue();
        uint256 endingAmt = startingAmt + amount;
        deal(_steth, _bridgeSteth, endingAmt);
        diamond.updateYield(vault);
    }

    function generateYield() internal {
        reth.submitBalances(100 ether, 80 ether);
        deal(_steth, _bridgeSteth, 2500 ether);
        updateYield();
    }

    function updateYield() internal {
        uint256 dethTotal = diamond.getVaultStruct(vault).dethTotal;
        uint256 dethTreasury = diamond.getVaultUserStruct(vault, tapp).ethEscrowed;
        uint256 dethYieldRate = diamond.getVaultStruct(vault).dethYieldRate;
        uint256 dethCollateral = diamond.getVaultStruct(vault).dethCollateral;

        diamond.updateYield(vault);

        uint256 yield = diamond.getVaultStruct(vault).dethTotal - dethTotal;
        uint256 treasuryD = diamond.getVaultUserStruct(vault, tapp).ethEscrowed - dethTreasury;
        uint256 yieldRateD = diamond.getVaultStruct(vault).dethYieldRate - dethYieldRate;
        assertEq(diamond.getVaultStruct(vault).dethTotal, 5000 ether);
        // Can be different bc of truncating
        assertApproxEqAbs(treasuryD + dethCollateral.mul(yieldRateD), yield, MAX_DELTA);
    }

    function distributeYield(address _addr) internal returns (uint256 reward) {
        //@dev skip bc yield can only be distributed after certain time
        skip(yieldEligibleTime);
        address[] memory assets = new address[](1);
        assets[0] = asset;
        uint256 ethEscrowed = diamond.getVaultUserStruct(vault, _addr).ethEscrowed;

        vm.prank(_addr);
        diamond.distributeYield(assets);
        reward = diamond.getVaultUserStruct(vault, _addr).ethEscrowed - ethEscrowed;
    }

    function claimDittoMatchedReward(address _addr) internal {
        vm.prank(_addr);
        diamond.claimDittoMatchedReward(vault);
    }

    function withdrawDittoReward(address _addr) internal {
        vm.prank(_addr);
        diamond.withdrawDittoReward(vault);
    }

    function test_view_getUndistributedYield() public {
        assertEq(diamond.getUndistributedYield(vault), 0);
        generateYield();
        assertEq(diamond.getUndistributedYield(vault), 0);

        uint256 UNDISTRIBUTED_YIELD = 10 ether;
        uint256 startingAmt = bridgeSteth.getDethValue();
        uint256 endingAmt = startingAmt + UNDISTRIBUTED_YIELD;
        deal(_steth, _bridgeSteth, endingAmt);

        assertEq(diamond.getUndistributedYield(vault), UNDISTRIBUTED_YIELD);
    }

    function test_view_getYield() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);

        skipTimeAndSetEth({skipTime: skipTime, ethPrice: 4000 ether});

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        skip(yieldEligibleTime);
        generateYield(10 ether);

        assertEq(diamond.getYield(asset, sender), 0);
        assertEq(diamond.getYield(asset, receiver), 9 ether);
        uint256 matchedTime = diamond.getOffsetTime() - yieldEligibleTime;
        uint256 dittoMatchedReward = (matchedTime / 1 days * 1 days).mul(diamond.dittoMatchedRate(vault)) - 1;
        assertEq(diamond.getDittoMatchedReward(vault, receiver), dittoMatchedReward);
        assertEq(diamond.getDittoReward(vault, receiver), 0);

        distributeYield(receiver);
        vm.prank(receiver);
        diamond.claimDittoMatchedReward(vault);

        assertEq(diamond.getYield(asset, receiver), 0);
        assertEq(diamond.getDittoMatchedReward(vault, receiver), 0);
        uint256 dittoShorterReward = diamond.getOffsetTime().mul(diamond.dittoShorterRate(vault)) - 1;
        assertEq(diamond.getDittoReward(vault, receiver), dittoMatchedReward + dittoShorterReward);
    }

    function test_DistributeYieldSameAsset() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        skip(yieldEligibleTime);
        generateYield(1 ether);

        address[] memory assets = new address[](2);
        assets[0] = asset;
        assets[1] = asset;
        uint256 ethEscrowed = diamond.getVaultUserStruct(vault, receiver).ethEscrowed;

        vm.prank(receiver);
        diamond.distributeYield(assets);
        uint256 ethEscrowed2 = diamond.getVaultUserStruct(vault, receiver).ethEscrowed;
        assertApproxEqAbs(ethEscrowed2 - ethEscrowed, 900000000000000000, MAX_DELTA);
    }

    function test_view_getTithe() public {
        assertEq(diamond.getTithe(vault), 0.1 ether);
    }

    function exitShortWalletAsserts() public {
        // Exit Short Partial from Wallet
        changePrank(_diamond);
        token.mint(sender, DEFAULT_AMOUNT);
        changePrank(sender);
        diamond.exitShortWallet(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, 0);
        assertEq(diamond.getVaultStruct(vault).dethCollateral, DEFAULT_AMOUNT.mulU88(0.0015 ether)); // 0.00025*6
        assertEq(diamond.getAssetStruct(asset).dethCollateral, DEFAULT_AMOUNT.mulU88(0.0015 ether)); // 0.00025*6
        assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT / 2);
        // Exit Short Full from Wallet
        diamond.exitShortWallet(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, 0);
        test_CanInitializeState();
    }

    function exitShortEscrowAsserts() public {
        // Exit Short Partial from Escrow
        diamond.exitShortErcEscrowed(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, 0);
        assertEq(diamond.getVaultStruct(vault).dethCollateral, DEFAULT_AMOUNT.mulU88(0.0015 ether)); // 0.00025*6
        assertEq(diamond.getAssetStruct(asset).dethCollateral, DEFAULT_AMOUNT.mulU88(0.0015 ether)); // 0.00025*6
        assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT / 2);
        // Exit Short Full from Escrow
        diamond.exitShortErcEscrowed(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, 0);
        test_CanInitializeState();
    }

    function exitShortAsserts(uint256 order) public {
        // Exit Short Partial
        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
        if (order == 0) {
            assertEq(diamond.getVaultStruct(vault).dethCollateral, DEFAULT_AMOUNT.mulU88(0.001375 ether)); // 0.00025*6 - 0.00025/2
            assertEq(diamond.getAssetStruct(asset).dethCollateral, DEFAULT_AMOUNT.mulU88(0.001375 ether));
            assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT / 2);
            // Exit Short Full
            exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
        } else if (order == 1) {
            assertEq(diamond.getVaultStruct(vault).dethCollateral, DEFAULT_AMOUNT.mulU88(0.002125 ether)); // 0.00025*6 - 0.00025/2 + 0.00025/2*6
            assertEq(diamond.getAssetStruct(asset).dethCollateral, DEFAULT_AMOUNT.mulU88(0.002125 ether));
            assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT / 2);
            // Exit Short Full
            exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
            // Exit leftover short
            createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
            exitShort(C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, DEFAULT_PRICE);
        } else {
            assertEq(diamond.getVaultStruct(vault).dethCollateral, DEFAULT_AMOUNT.mulU88(0.002125 ether)); // 0.00025*6 - 0.00025/2 + 0.00025/2*6
            assertEq(diamond.getAssetStruct(asset).dethCollateral, DEFAULT_AMOUNT.mulU88(0.002125 ether));
            assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT / 2);
            // Exit Short Full
            exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
            // Exit leftover short
            createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
            exitShort(C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, DEFAULT_PRICE);
        }
        test_CanInitializeState();
    }

    function liquidateWalletAsserts() public {
        changePrank(_diamond);
        token.mint(receiver, DEFAULT_AMOUNT);
        _setETH(1000 ether);
        vm.stopPrank();
        liquidateWallet(sender, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, receiver);
        _setETH(4000 ether);
        test_CanInitializeState();
        vm.startPrank(sender);
    }

    function liquidateEscrowAsserts() public {
        vm.stopPrank();
        _setETH(1000 ether);
        liquidateErcEscrowed(sender, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, receiver);
        _setETH(4000 ether);
        test_CanInitializeState();
        vm.startPrank(sender);
    }

    function liquidateAsserts(uint256 order) public {
        changePrank(owner);
        testFacet.setprimaryLiquidationCRT(asset, 2550);
        changePrank(receiver);
        // Liquidation Partial
        uint256 tappFee = 0.025 ether;
        uint256 ethFilledTotal;

        if (order == 0) {
            (uint256 gas, uint256 ethFilled) = diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
            ethFilledTotal += ethFilled;
            uint256 ethUsed = DEFAULT_AMOUNT.mulU88(0.00137125 ether) - gas; // 0.00025*6 - 0.00025/2 - 0.00025/2*.025 - 0.00025/2*.005
            assertEq(diamond.getVaultStruct(vault).dethCollateral, ethUsed);
            assertEq(diamond.getAssetStruct(asset).dethCollateral, ethUsed);
            assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT / 2);
            // Liquidation Full
            createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
            (, ethFilled) = diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
            ethFilledTotal += ethFilled;
        } else if (order == 1) {
            (uint256 gas, uint256 ethFilled) = diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
            ethFilledTotal += ethFilled;
            uint256 ethUsed = DEFAULT_AMOUNT.mulU88(0.00212125 ether) - gas; // 0.00025*6 - 0.00025/2 - 0.00025/2*.025 - 0.00025/2*.005 + 0.00025/2*6
            assertEq(diamond.getVaultStruct(vault).dethCollateral, ethUsed);
            assertEq(diamond.getAssetStruct(asset).dethCollateral, ethUsed);
            assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT / 2);
            // Liquidation Full
            changePrank(sender);
            createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
            changePrank(receiver);
            (, ethFilled) = diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
            ethFilledTotal += ethFilled;
            // Exit leftover shorts
            createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
            changePrank(sender);
            exitShort(C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
            exitShort(C.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
        } else {
            (uint256 gas, uint256 ethFilled) = diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
            ethFilledTotal += ethFilled;
            uint256 ethUsed = DEFAULT_AMOUNT.mulU88(0.00212125 ether) - gas; // 0.00025*6 - 0.00025/2 - 0.00025/2*.025 - 0.00025/2*.005 + 0.00025/2*6
            assertEq(diamond.getVaultStruct(vault).dethCollateral, ethUsed);
            assertEq(diamond.getAssetStruct(asset).dethCollateral, ethUsed);
            assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt, DEFAULT_AMOUNT / 2);
            // Liquidation Full
            changePrank(sender);
            createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
            changePrank(receiver);
            (, ethFilled) = diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
            ethFilledTotal += ethFilled;
            // Exit leftover shorts
            createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
            changePrank(sender);
            exitShort(C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
            exitShort(C.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT / 2, DEFAULT_PRICE);
        }
        assertEq(diamond.getDethTotal(vault), 4000 ether);
        assertEq(diamond.getVaultStruct(vault).dethTotal, 4000 ether);
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, ethFilledTotal.mul(tappFee));
        assertEq(diamond.getVaultStruct(vault).dethCollateral, 0);
        assertEq(diamond.getAssetStruct(asset).dethCollateral, 0);
    }

    function oneYieldDistribution(uint80 bidPrice, uint88 bidERC, uint80 shortPrice, uint88 shortERC, bool bidFirst) public {
        address sharesUser;
        uint256 executionPrice;
        uint256 shares;

        if (bidFirst) {
            sharesUser = sender;
            vm.prank(sender);
            createLimitBid(bidPrice, bidERC);
            skipTimeAndSetEth({skipTime: skipTime, ethPrice: 4000 ether});
            vm.prank(receiver);
            createLimitShort(shortPrice, shortERC);
            executionPrice = bidPrice;
            shares = shortERC < bidERC ? shortERC.mul(bidPrice) * (skipTime / 1 days) : bidERC.mul(bidPrice) * (skipTime / 1 days);
        } else {
            sharesUser = receiver;
            vm.prank(receiver);
            createLimitShort(shortPrice, shortERC);
            skipTimeAndSetEth({skipTime: skipTime, ethPrice: 4000 ether});
            vm.prank(sender);
            createLimitBid(bidPrice, bidERC);
            executionPrice = shortPrice;
            shares = shortERC < bidERC
                ? shortERC.mul(shortPrice).mul(5 ether) * (skipTime / 1 days)
                : bidERC.mul(shortPrice).mul(5 ether) * (skipTime / 1 days);
        }

        {
            skipTime += yieldEligibleTime;
            uint256 dethTotal = diamond.getDethTotal(vault);
            generateYield();
            uint256 dethReward = diamond.getDethTotal(vault) - dethTotal;
            uint256 dethCollateral = shortERC < bidERC
                ? shortERC.mul(executionPrice) + shortERC.mul(shortPrice).mul(5 ether)
                : bidERC.mul(executionPrice) + bidERC.mul(shortPrice).mul(5 ether);
            uint256 dethTreasuryTithe = dethReward.mul(diamond.getTithe(vault));
            uint256 dethCollateralReward = dethReward - dethTreasuryTithe;
            uint256 dethYieldRate = dethCollateralReward.div(dethCollateral);
            assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, dethTreasuryTithe, "1");
            assertEq(diamond.getVaultStruct(vault).dethCollateral, dethCollateral, "2");
            assertEq(diamond.getAssetStruct(asset).dethCollateral, dethCollateral);
            assertEq(diamond.getVaultStruct(vault).dethYieldRate, dethYieldRate, "3");
            assertEq(diamond.getVaultStruct(vault).dethCollateralReward, dethCollateralReward, "4");
            assertEq(diamond.getVaultStruct(vault).dittoMatchedShares, shares, "5");
            uint256 dethUserReward = distributeYield(receiver);
            vm.prank(receiver);
            diamond.withdrawDittoReward(vault);
            uint256 mReward = (skipTime + 1).mul(diamond.dittoShorterRate(vault));
            uint256 userReward = dethUserReward.mul(mReward).div(dethCollateralReward) - 1;
            assertEq(ditto.balanceOf(receiver), userReward, "6");
        }

        {
            uint256 uReward = (skipTime / 1 days * 1 days).mul(diamond.dittoMatchedRate(vault));
            uint256 uShares = diamond.getVaultUserStruct(vault, sharesUser).dittoMatchedShares;
            uint256 totalShares = diamond.getVaultStruct(vault).dittoMatchedShares;
            uint256 dittoPrev = ditto.balanceOf(sharesUser);
            uint256 userReward =
                dittoPrev == 0 ? (uShares - 1).mul(uReward).div(totalShares) - 1 : (uShares - 1).mul(uReward).div(totalShares);
            claimDittoMatchedReward(sharesUser);
            withdrawDittoReward(sharesUser);
            assertEq(ditto.balanceOf(sharesUser) - dittoPrev, userReward, "7");
        }
    }

    function test_TitheReverts() public {
        vm.prank(owner);
        vm.expectRevert(Errors.InvalidTithe.selector);
        diamond.setTithe(vault, 33_34);
    }

    function test_YieldEmptyVault() public {
        diamond.updateYield(100);
        assertEq(diamond.getVaultStruct(100).dethTotal, 0);
        assertEq(diamond.getVaultStruct(100).dethYieldRate, 0);
        assertEq(diamond.getVaultStruct(100).dethCollateralReward, 0);
    }

    function test_NoYieldEarlyReturn() public {
        uint256 dethTotal = diamond.getDethTotal(vault);
        diamond.updateYield(vault);
        assertEq(diamond.getDethTotal(vault), dethTotal);

        // Grab state before
        uint256 dethYieldRate = diamond.getVaultStruct(vault).dethYieldRate;
        uint256 dethCollateralReward = diamond.getVaultStruct(vault).dethCollateralReward;

        deal(_steth, _bridgeSteth, 1999 ether); // Prev balance was 2000
        diamond.updateYield(vault);
        assertEq(diamond.getDethTotal(vault), dethTotal - 1 ether); // bridge actual
        // Assert no change
        assertEq(diamond.getVaultStruct(vault).dethTotal, dethTotal);
        assertEq(diamond.getVaultStruct(vault).dethYieldRate, dethYieldRate);
        assertEq(diamond.getVaultStruct(vault).dethCollateralReward, dethCollateralReward);
    }

    function test_LittleYieldEarlyReturn() public {
        uint256 dethTotal = diamond.getDethTotal(vault);
        diamond.updateYield(vault);
        assertEq(diamond.getDethTotal(vault), dethTotal);

        // create SR so yield doesn't get sent to TAPP
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        // Grab state before
        dethTotal = diamond.getDethTotal(vault);
        uint256 dethYieldRate = diamond.getVaultStruct(vault).dethYieldRate;
        uint256 dethCollateralReward = diamond.getVaultStruct(vault).dethCollateralReward;

        generateYield(1 wei);
        assertEq(diamond.getUndistributedYield(vault), 1 wei);
        // Assert no change
        assertEq(diamond.getVaultStruct(vault).dethTotal, dethTotal);
        assertEq(diamond.getVaultStruct(vault).dethYieldRate, dethYieldRate);
        assertEq(diamond.getVaultStruct(vault).dethCollateralReward, dethCollateralReward);
    }

    function test_CanInitializeState() public {
        assertEq(diamond.getDethTotal(vault), 4000 ether);
        assertEq(diamond.getVaultStruct(vault).dethTotal, 4000 ether);
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 0);
        assertEq(diamond.getVaultStruct(vault).dethCollateral, 0);
        assertEq(diamond.getAssetStruct(asset).dethCollateral, 0);
        assertEq(diamond.getVaultStruct(vault).dethYieldRate, 0);
        assertEq(diamond.getVaultUserStruct(vault, sender).dittoMatchedShares, 0);
        assertEq(diamond.getVaultUserStruct(vault, sender).dittoReward, 0);
        assertEq(ditto.balanceOf(sender), 0);
        assertEq(reth.getExchangeRate(), 1 ether);
    }

    function test_Cancels() public {
        vm.startPrank(sender);
        // Cancel Bid
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        cancelBid(100);
        test_CanInitializeState();
        // Cancel Short
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        cancelShort(101);
        test_CanInitializeState();
    }

    function test_ExitShortSecondary() public {
        vm.startPrank(sender);
        // Exit Short Wallet Bid-Ask
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortWalletAsserts();
        // Exit Short Wallet Ask-Bid
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortWalletAsserts();
        // Exit Short Escrow Bid-Ask
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortEscrowAsserts();
        // Exit Short Escrow Ask-Bid
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortEscrowAsserts();
    }

    function test_ExitShortPrimaryWithAsk() public {
        vm.startPrank(sender);
        // Exit Short Bid-Ask-Ask
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortAsserts(0);
        // Exit Short Ask-Bid-Ask
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortAsserts(0);
    }

    function test_ExitShortPrimaryWithShort1() public {
        vm.startPrank(sender);
        // Exit Short Bid-Ask-Short
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortAsserts(1);
    }

    function test_ExitShortPrimaryWithShort2() public {
        vm.startPrank(sender);
        // Exit Short Ask-Bid-Short
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        exitShortAsserts(2);
    }

    function test_ExitShortYieldDisbursement() public {
        // Create shorts and generate yield
        fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT * 6, extra);
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT * 3, sender);
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 101
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 102
        generateYield(DEFAULT_AMOUNT);
        distributeYield(sender);
        setETH(4000 ether);

        // Setup different exit shorts for receiver
        vm.prank(_diamond);
        token.mint(receiver, DEFAULT_AMOUNT);
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT * 2, extra);

        // Exit Short wallet
        exitShortWallet(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, receiver); // partial
        exitShortWallet(C.SHORT_STARTING_ID, DEFAULT_AMOUNT / 2, receiver); // full

        // Exit Short ercEscrowed
        exitShortErcEscrowed(C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT / 2, receiver); // partial
        exitShortErcEscrowed(C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT / 2, receiver); // full

        // Exit Short primary
        exitShort(C.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT / 2, DEFAULT_PRICE, receiver); // partial
        exitShort(C.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT / 2, DEFAULT_PRICE, receiver); // full

        // Exit sender short
        exitShortErcEscrowed(C.SHORT_STARTING_ID, DEFAULT_AMOUNT * 2, sender);
        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);

        // Compare Exit Short disbursements (receiver) with distribute yield (sender)
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, diamond.getVaultUserStruct(vault, receiver).ethEscrowed);
    }

    function test_LiquidationSecondary() public {
        vm.startPrank(sender);
        // Liquidation Wallet Bid-Ask
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        liquidateWalletAsserts();
        // Liquidation Wallet Ask-Bid
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        liquidateWalletAsserts();
        // Liquidation Escrow Bid-Ask
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        liquidateEscrowAsserts();
        // Liquidation Escrow Ask-Bid
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        liquidateEscrowAsserts();
    }

    function test_PrimaryLiquidationWithAsk1() public {
        vm.startPrank(sender);
        // Liquidation Bid-Ask-Ask
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
        liquidateAsserts(0);
    }

    function test_PrimaryLiquidationWithAsk2() public {
        vm.startPrank(sender);
        // Liquidation Ask-Bid-Ask
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
        liquidateAsserts(0);
    }

    function test_PrimaryLiquidationWithShort1() public {
        vm.startPrank(sender);
        // Liquidation Bid-Ask-Short
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
        liquidateAsserts(1);
    }

    function test_PrimaryLiquidationWithShort2() public {
        vm.startPrank(sender);
        // Liquidation Ask-Bid-Short
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT / 2);
        liquidateAsserts(2);
    }

    function test_LiquidationYieldDisbursement() public {
        // Create shorts and generate yield
        fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT * 7, extra);
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, extra2); // 100
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); // 100
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); // 101
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, sender); // 102
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 100
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 101
        fundLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver); // 102
        generateYield(DEFAULT_AMOUNT);

        // Setup different liquidations for receiver
        vm.prank(_diamond);
        token.mint(extra, DEFAULT_AMOUNT * 2);

        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        _setETH(800 ether); // c-ratio = 1.2
        vm.startPrank(extra);
        //@dev skip time to get yield
        skip(C.YIELD_DELAY_SECONDS + 1);
        vm.stopPrank();
        liquidate(extra2, C.SHORT_STARTING_ID, extra); // normlaize gas for remaining liquidations

        // Liquidation wallet
        liquidateWallet(receiver, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, extra); // full

        // Liquidation ercEscrowed
        liquidateErcEscrowed(receiver, C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, extra); // full

        // Liquidation primary
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);
        liquidate(receiver, C.SHORT_STARTING_ID + 2, extra); // partial
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);
        liquidate(receiver, C.SHORT_STARTING_ID + 2, extra); // full

        // Distribute yield and then exit sender short
        distributeYield(sender);
        _setETH(800 ether); // prevent stale oracle
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);
        liquidate(sender, C.SHORT_STARTING_ID, extra); // partial
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);
        liquidate(sender, C.SHORT_STARTING_ID, extra); // partial
        liquidateWallet(sender, C.SHORT_STARTING_ID + 1, DEFAULT_AMOUNT, extra);
        liquidateErcEscrowed(sender, C.SHORT_STARTING_ID + 2, DEFAULT_AMOUNT, extra);

        // Compare Liquidation disbursements (receiver) with distribute yield (sender)
        assertApproxEqAbs(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed,
            diamond.getVaultUserStruct(vault, receiver).ethEscrowed,
            MAX_DELTA
        );
    }

    function test_CanYieldDistributeInitialState() public {
        generateYield();
        assertEq(diamond.getDethTotal(vault), 5000 ether); // 4000/.8
        assertEq(diamond.getVaultStruct(vault).dethTotal, 5000 ether);
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 1000 ether); // 0 + 4000/4000*1000/10 + 4000/4000*1000*9/10
        assertEq(diamond.getVaultStruct(vault).dethCollateral, 0);
        assertEq(diamond.getAssetStruct(asset).dethCollateral, 0);
        assertEq(diamond.getVaultStruct(vault).dethYieldRate, 0);
    }

    function test_CanInitializeStateUnmatchedShort() public {
        vm.prank(sender);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        assertEq(diamond.getDethTotal(vault), 4000 ether);
        assertEq(diamond.getVaultStruct(vault).dethTotal, 4000 ether);
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 0);
        assertEq(diamond.getVaultStruct(vault).dethCollateral, 0);
        assertEq(diamond.getAssetStruct(asset).dethCollateral, 0);
        assertEq(diamond.getVaultStruct(vault).dethYieldRate, 0);
    }

    function test_CanInitializeStateMatchedBid() public {
        vm.prank(sender);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        vm.prank(receiver);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
        test_CanInitializeState();
    }

    function test_CanYieldDistributeWithUnmatchedShort() public {
        vm.prank(sender);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        generateYield();
        assertEq(diamond.getDethTotal(vault), 5000 ether); // 4000/.8
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 1000 ether);
        assertEq(diamond.getVaultStruct(vault).dethCollateral, 0);
        assertEq(diamond.getAssetStruct(asset).dethCollateral, 0);
        assertEq(diamond.getVaultStruct(vault).dethYieldRate, 0);
    }

    function test_CanYieldDistributeWithMatchedShortFullBidShort() public {
        oneYieldDistribution(DEFAULT_PRICE, 200000 ether, DEFAULT_PRICE, 400000 ether, BID_FIRST);
    }

    function test_CanYieldDistributeWithMatchedShortFullShortBid() public {
        oneYieldDistribution(DEFAULT_PRICE, 200000 ether, DEFAULT_PRICE, 400000 ether, SHORT_FIRST);
    }

    function test_CanYieldDistributeWithMatchedShortFullBidShortDiffPrice() public {
        oneYieldDistribution(DEFAULT_PRICE + 1, 200000 ether, DEFAULT_PRICE, 400000 ether, BID_FIRST);
    }

    function test_CanYieldDistributeWithMatchedShortFullShortBidDiffPrice() public {
        oneYieldDistribution(DEFAULT_PRICE + 1, 200000 ether, DEFAULT_PRICE, 400000 ether, SHORT_FIRST);
    }

    function test_CanYieldDistributeWithMatchedShortPartialBidShort() public {
        oneYieldDistribution(DEFAULT_PRICE, 400000 ether, DEFAULT_PRICE, 720000 ether, BID_FIRST);
    }

    function test_CanYieldDistributeWithMatchedShortPartialShortBid() public {
        oneYieldDistribution(DEFAULT_PRICE, 400000 ether, DEFAULT_PRICE, 720000 ether, SHORT_FIRST);
    }

    function test_CanYieldDistributeWithMatchedShortPartialBidShortDiffPrice() public {
        oneYieldDistribution(DEFAULT_PRICE + 1, 400000 ether, DEFAULT_PRICE, 720000 ether, BID_FIRST);
    }

    function test_CanYieldDistributeWithMatchedShortPartialShortBidDiffPrice() public {
        oneYieldDistribution(DEFAULT_PRICE + 1, 400000 ether, DEFAULT_PRICE, 720000 ether, SHORT_FIRST);
    }

    function test_CanYieldDistributeWithMatchedShortExactBidShort() public {
        oneYieldDistribution(DEFAULT_PRICE, 600000 ether, DEFAULT_PRICE, 600000 ether, BID_FIRST);
    }

    function test_CanYieldDistributeWithMatchedShortExactShortBid() public {
        oneYieldDistribution(DEFAULT_PRICE, 600000 ether, DEFAULT_PRICE, 600000 ether, SHORT_FIRST);
    }

    function test_CanYieldDistributeWithMatchedShortExactBidShortDiffPrice() public {
        oneYieldDistribution(DEFAULT_PRICE + 1, 600000 ether, DEFAULT_PRICE, 600000 ether, BID_FIRST);
    }

    function test_CanYieldDistributeWithMatchedShortExactShortBidDiffPrice() public {
        oneYieldDistribution(DEFAULT_PRICE + 1, 600000 ether, DEFAULT_PRICE, 600000 ether, SHORT_FIRST);
    }

    function test_CanYieldDistributeWith2ShortersAnd2Distributions() public {
        vm.prank(extra);
        createLimitBid(DEFAULT_PRICE, 400000 ether); // 100
        // First Short First Shorter
        vm.prank(sender);
        createLimitShort(DEFAULT_PRICE, 200000 ether); // 50
        // First Short Second Shorter
        vm.prank(receiver);
        createLimitShort(DEFAULT_PRICE, 200000 ether); // 50

        if (!distributed) {
            skip(9000001);
        } else {
            skip(9000001 - skipTime * 2);
        }

        generateYield(1000 ether);
        rewind(yieldEligibleTime);
        uint256 senderReward = distributeYield(sender);
        withdrawDittoReward(sender);
        assertEq(senderReward, 450 ether, "1"); // 0.9(1000)/2
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1200 ether, "2"); // 1000 - 50*5 + 450
        assertEq(ditto.balanceOf(sender), 4500000, "3");
        assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).dethYieldRate, 900 ether / 600, "4"); // 0.9(1000) / (300 + 300)
        assertEq(getShortRecord(receiver, C.SHORT_STARTING_ID).dethYieldRate, 0, "5");

        skip(26460000); // match yield distribution to make calcs easier
        generateYield(3000 ether);
        rewind(yieldEligibleTime);
        senderReward = distributeYield(sender);
        withdrawDittoReward(sender);
        rewind(yieldEligibleTime);
        uint256 receiverReward = distributeYield(receiver);
        withdrawDittoReward(receiver);
        // Vault Totals
        assertEq(diamond.getDethTotal(vault), 4000 ether + 4000 ether);
        assertEq(diamond.getVaultStruct(vault).dethTotal, 4000 ether + 4000 ether);
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 454 ether); // 0.1 + 0.1/(4000+1)*1 + (4001-0.1)/(4000+1)*1/10
        assertEq(diamond.getVaultStruct(vault).dethCollateral, 600 ether);
        assertEq(diamond.getAssetStruct(asset).dethCollateral, 600 ether);
        assertEq(diamond.getVaultStruct(vault).dethYieldRate, 3546 ether / 600); // 900 + (3000 - (454-100))

        // User totals
        assertEq(senderReward, 1323 ether, "11"); // 3546 / 2 - 450
        assertEq(receiverReward, 1773 ether, "12"); // 3546 / 2
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 2523 ether, "13"); // 1000-50*5+1773
        assertEq(
            diamond.getVaultUserStruct(vault, receiver).ethEscrowed, diamond.getVaultUserStruct(vault, sender).ethEscrowed, "14"
        );
        assertEq(ditto.balanceOf(sender), 17730000, "15");
        assertEq(ditto.balanceOf(sender), ditto.balanceOf(receiver), "16");
        assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).dethYieldRate, 3546 ether / 600, "17");
        assertEq(
            getShortRecord(sender, C.SHORT_STARTING_ID).dethYieldRate,
            getShortRecord(receiver, C.SHORT_STARTING_ID).dethYieldRate,
            "18"
        );
    }

    function test_DittoMatchedRewardDistribution() public {
        // r matches after 14 days + 1 seconds
        vm.startPrank(receiver);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        skipTimeAndSetEth({skipTime: skipTime, ethPrice: 4000 ether});
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
        vm.stopPrank();

        // s matches half after 14 days + 1 seconds, cancels half, matches half over 0 seconds
        vm.startPrank(sender);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        skipTimeAndSetEth({skipTime: skipTime, ethPrice: 4000 ether});
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.6 ether));
        cancelBid(100);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.4 ether));
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(0.4 ether));
        vm.stopPrank();

        // Check DittoMatchedReward Points
        uint256 matched1 = DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE);
        uint256 matched2 = DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE).mul(0.6 ether);
        uint256 shares1 = matched1 * (skipTime / 1 days);
        uint256 shares2 = matched2 * (skipTime / 1 days);
        assertEq(diamond.getVaultUserStruct(vault, receiver).dittoMatchedShares, shares1, "shares1");
        assertEq(diamond.getVaultUserStruct(vault, sender).dittoMatchedShares, shares2, "shares2"); // 0.6 ether * (skipTime + 1), // add 1 for each extra skip

        // Generate yield and check that state was returned to normal
        distributed = true;
        test_CanYieldDistributeWith2ShortersAnd2Distributions();

        // Check reward claims from matching
        uint256 totalReward = (diamond.getOffsetTime() / 1 days * 1 days).mul(diamond.dittoMatchedRate(vault));
        uint256 balance1 = ditto.balanceOf(receiver);
        uint256 balance2 = ditto.balanceOf(sender);

        claimDittoMatchedReward(receiver);
        withdrawDittoReward(receiver);
        // First ditto reward claim happened in nested test, don't need to sub 1 again here
        uint256 reward1 = (shares1 - 1).mul(totalReward).div(shares1 + shares2);
        assertEq(ditto.balanceOf(receiver), reward1 + balance1, "yield1");

        claimDittoMatchedReward(sender);
        withdrawDittoReward(sender);
        // First ditto reward claim happened in nested test, don't need to sub 1 again here
        uint256 reward2 = (shares2 - 1).mul(totalReward - reward1).div(shares2 + 1);
        assertEq(ditto.balanceOf(sender), reward2 + balance2, "yield2");
    }

    function test_DittoMatchedRate() public {
        // r matches after 14 days + 1 seconds
        vm.startPrank(receiver);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        skip(skipTime);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);

        // reward 1 day later should be more than original reward
        assertEq(diamond.getVaultStruct(vault).dittoMatchedTime, 0);
        skip(1 days);
        diamond.claimDittoMatchedReward(vault);

        uint256 dittoMatchedTime = ((skipTime - 1) + 1 days) / 1 days;
        assertEq(diamond.getVaultStruct(vault).dittoMatchedTime, dittoMatchedTime);
    }

    function test_MatchedOrderNoShares() public {
        vm.startPrank(receiver);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT);
        createLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);
        assertEq(diamond.getVaultUserStruct(vault, receiver).dittoMatchedShares, 0);
    }

    function test_ShortRecordFacetYield() public {
        // create first shorts
        fundLimitBid(DEFAULT_PRICE, 320000 ether, receiver); // 800
        fundLimitShort(DEFAULT_PRICE, 80000 ether, sender); // 20*6 = 120
        fundLimitShort(DEFAULT_PRICE, 80000 ether, extra); // 20*6 = 120
        fundLimitShort(DEFAULT_PRICE, 80000 ether, extra2); // 20*6 = 120
        fundLimitShort(DEFAULT_PRICE, 160000 ether, receiver); // 20*6 = 120

        generateYield();

        // receiver gets other half of short filled, provides fill for sender's second short
        fundLimitBid(DEFAULT_PRICE, 160000 ether, receiver); // 120 + 20*6 = 240
        // sender second short, combined
        fundLimitShort(DEFAULT_PRICE, 80000 ether, sender); // 120 + 20*6 = 240
        vm.prank(sender);
        combineShorts({id1: C.SHORT_STARTING_ID, id2: C.SHORT_STARTING_ID + 1});
        // extra increases collateral
        vm.prank(extra);
        diamond.increaseCollateral(asset, C.SHORT_STARTING_ID, 120 ether); // 120 + 120 = 240
        // extra2 increases and then decreases collateral
        vm.prank(extra2);
        diamond.increaseCollateral(asset, C.SHORT_STARTING_ID, 170 ether);
        skip(yieldEligibleTime);
        vm.prank(extra2);
        diamond.decreaseCollateral(asset, C.SHORT_STARTING_ID, 50 ether); // 120 + 170 - 50 = 240

        uint256 reward1 = distributeYield(receiver);
        uint256 reward2 = distributeYield(sender);
        uint256 reward3 = distributeYield(extra);
        uint256 reward4 = distributeYield(extra2);

        assertEq(reward1, reward2);
        assertEq(reward1, reward3);
        assertGt(reward1, reward4);

        assertApproxEqAbs(
            diamond.getVaultUserStruct(vault, extra).ethEscrowed, diamond.getVaultUserStruct(vault, extra2).ethEscrowed, MAX_DELTA
        );
    }

    function test_CanYieldDistributeManyShorts() public {
        //@dev force the createLimitShort and createBid to default to internal loop
        MTypes.OrderHint[] memory orderHintArray;
        for (uint160 i; i < users.length - 1; i++) {
            for (uint160 num = 1; num <= 50; num++) {
                orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitShort, 1);
                vm.prank(users[i]);
                diamond.createLimitShort(asset, DEFAULT_PRICE, 8000 ether, orderHintArray, shortHintArrayStorage, initialCR); // 2*5 = 10
                orderHintArray = diamond.getHintArray(asset, DEFAULT_PRICE, O.LimitBid, 1);
                vm.prank(users[i + 1]);
                diamond.createBid(asset, DEFAULT_PRICE, 40000 ether, C.LIMIT_ORDER, orderHintArray, shortHintArrayStorage); // 10
            }
        }
        generateYield();
        distributeYield(receiver);
        distributeYield(sender);
        distributeYield(extra);
        assertEq(diamond.getDethTotal(vault), 5000 ether);
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 100 ether); // 0 + (1000)/10
        assertEq(diamond.getVaultStruct(vault).dethCollateral, 1800 ether); // 12 * 150
        assertEq(diamond.getAssetStruct(asset).dethCollateral, 1800 ether);
        assertEq(diamond.getVaultStruct(vault).dethYieldRate, 900 ether / 1800); // (1000)*9/10
    }

    ///////////YIELD_DELAY_SECONDS Tests///////////
    function setUpShortAndCheckInitialEscrowed() public returns (uint256 collateral, uint256 unlockedCollateral) {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        collateral = getShortRecord(sender, C.SHORT_STARTING_ID).collateral;
        unlockedCollateral = collateral - DEFAULT_PRICE.mulU80(DEFAULT_AMOUNT);
        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether);
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 0);
        return (collateral, unlockedCollateral);
    }

    //Test distributeYield for flashloan scenarios
    function test_CantDistributeYieldBeforeDelayInterval() public {
        setUpShortAndCheckInitialEscrowed();
        vm.startPrank(sender);
        generateYield(1 ether);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        vm.expectRevert(Errors.NoYield.selector);
        diamond.distributeYield(assets);

        skip(yieldEligibleTime);
        diamond.distributeYield(assets);
    }

    function test_CantDistributeYieldBeforeDelayIntervalCombineShorts() public {
        setUpShortAndCheckInitialEscrowed();

        generateYield(1 ether);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        skip(yieldEligibleTime);
        //@dev setETH to prevent stale oracle revert
        setETH(4000 ether);
        //combine shorts to reset the updatedAt
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        vm.startPrank(sender);
        combineShorts({id1: C.SHORT_STARTING_ID, id2: C.SHORT_STARTING_ID + 1});
        assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).updatedAt, diamond.getOffsetTime());
        vm.expectRevert(Errors.NoYield.selector);
        diamond.distributeYield(assets);

        //try again
        skip(yieldEligibleTime);
        diamond.distributeYield(assets);
    }

    function test_CantDistributeYieldBeforeDelayIntervalIncreaseCollateral() public {
        setUpShortAndCheckInitialEscrowed();

        vm.startPrank(sender);
        generateYield(1 ether);

        address[] memory assets = new address[](1);
        assets[0] = asset;
        skip(yieldEligibleTime);

        //increase Collateral to reset the updatedAt
        increaseCollateral(C.SHORT_STARTING_ID, 0.0001 ether);
        assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).updatedAt, diamond.getOffsetTime());
        vm.expectRevert(Errors.NoYield.selector);
        diamond.distributeYield(assets);

        //try again
        skip(yieldEligibleTime);
        diamond.distributeYield(assets);
    }

    //Test disburseCollateral for flashloan scenarios
    function checkTappDidNotReceiveYield() public {
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 0);
    }

    function checkTappReceivedYield() public {
        assertGt(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, 0);
    }

    function test_DisburseCollateralBeforeDelayIntervalExitShort() public {
        (, uint256 unlockedCollateral) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);

        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + unlockedCollateral);
        checkTappReceivedYield();
    }

    function test_DisburseCollateralAfterDelayIntervalExitShort() public {
        (, uint256 unlockedCollateral) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);
        skip(yieldEligibleTime);
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);

        assertGt(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + unlockedCollateral);
        checkTappDidNotReceiveYield();
    }

    function test_DisburseCollateralBeforeDelayIntervalPartialExitShort() public {
        setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);
        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);

        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether);
        checkTappReceivedYield();
    }

    function test_DisburseCollateralAfterDelayIntervalPartialExitShort() public {
        setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);
        skip(yieldEligibleTime);
        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT / 2, extra);
        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);

        assertGt(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether);
        checkTappDidNotReceiveYield();
    }

    function test_DisburseCollateralBeforeDelayIntervalExitShortWallet() public {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);
        // Prepare exit from wallet
        vm.prank(_diamond);
        token.mint(sender, DEFAULT_AMOUNT);
        vm.prank(sender);
        token.increaseAllowance(_diamond, DEFAULT_AMOUNT);
        exitShortWallet(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);

        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + collateral);
        checkTappReceivedYield();
    }

    function test_DisburseCollateralAfterDelayIntervalExitShortWallet() public {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);
        skip(yieldEligibleTime);
        // Prepare exit from wallet
        vm.prank(_diamond);
        token.mint(sender, DEFAULT_AMOUNT);
        vm.prank(sender);
        token.increaseAllowance(_diamond, DEFAULT_AMOUNT);
        exitShortWallet(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);

        assertGt(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + collateral);
        checkTappDidNotReceiveYield();
    }

    function test_DisburseCollateralBeforeDelayIntervalExitShortErcEscrowed() public {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);

        depositUsd(sender, DEFAULT_AMOUNT);
        exitShortErcEscrowed(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);

        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + collateral);
        checkTappReceivedYield();
    }

    function test_DisburseCollateralAfterDelayIntervalExitShortErcEscrowed() public {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);
        skip(yieldEligibleTime);

        depositUsd(sender, DEFAULT_AMOUNT);
        exitShortErcEscrowed(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, sender);

        assertGt(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + collateral);
        checkTappDidNotReceiveYield();
    }

    function test_DisburseCollateralBeforeDelayIntervalDecreaseCollateral() public {
        setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(10 ether);
        vm.prank(sender);
        decreaseCollateral(C.SHORT_STARTING_ID, 1 wei);

        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + 1 wei);
        checkTappReceivedYield();
    }

    function test_DisburseCollateralAfterDelayIntervalDecreaseCollateral() public {
        setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(10 ether);
        skip(yieldEligibleTime);
        vm.prank(sender);
        decreaseCollateral(C.SHORT_STARTING_ID, 1 wei);

        assertGt(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + 1 wei);
        checkTappDidNotReceiveYield();
    }

    //@dev shorter liquidated by primary liquidation will always get yield via disburse
    function test_CantDisburseCollateralBeforeDelayIntervalPrimaryLiquidateShorterGetsYield() public {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);

        fundLimitAsk(DEFAULT_PRICE, DEFAULT_AMOUNT, extra);
        setETH(2666 ether);
        //@dev skip time to get yield
        skip(C.YIELD_DELAY_SECONDS + 1);
        vm.prank(extra);
        (uint256 gas, uint256 ethFilled) = diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);

        uint256 tappFeePct = diamond.getAssetNormalizedStruct(asset).tappFeePct;
        uint256 callerFeePct = diamond.getAssetNormalizedStruct(asset).callerFeePct;
        uint256 tappFee = tappFeePct.mul(ethFilled);
        uint256 callerFee = callerFeePct.mul(ethFilled);

        assertGt(
            diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + (collateral - ethFilled - gas - tappFee - callerFee)
        );
        assertEq(diamond.getVaultUserStruct(vault, tapp).ethEscrowed, tappFee);
    }

    function test_CantDisburseCollateralBeforeDelayIntervalLiquidateWalletTappGetsYield() public {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);

        setETH(750 ether);
        uint256 ercDebtAtOraclePrice = getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt.mul(diamond.getOracleAssetPrice(asset));
        vm.prank(_diamond);
        token.mint(extra, DEFAULT_AMOUNT);
        liquidateWallet(sender, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, extra);

        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + (collateral - ercDebtAtOraclePrice));
        checkTappReceivedYield();
    }

    function test_CantDisburseCollateralBeforeDelayIntervalLiquidateWalletShorterGetsYield() public {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);

        setETH(750 ether);

        uint256 ercDebtAtOraclePrice = getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt.mul(diamond.getOracleAssetPrice(asset));
        vm.prank(_diamond);
        token.mint(extra, DEFAULT_AMOUNT);
        skip(yieldEligibleTime);
        liquidateWallet(sender, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, extra);

        assertGt(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + (collateral - ercDebtAtOraclePrice));
        checkTappDidNotReceiveYield();
    }

    function test_CantDisburseCollateralBeforeDelayIntervalLiquidateErcEscrowedTappGetsYield() public {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);

        setETH(750 ether);
        uint256 ercDebtAtOraclePrice = getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt.mul(diamond.getOracleAssetPrice(asset));

        liquidateErcEscrowed(sender, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, extra);

        assertEq(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + (collateral - ercDebtAtOraclePrice));
        checkTappReceivedYield();
    }

    function test_CantDisburseCollateralBeforeDelayIntervalLiquidateErcEscrowedShorterGetsYield() public {
        (uint256 collateral,) = setUpShortAndCheckInitialEscrowed();

        vm.prank(owner);
        diamond.setTithe(vault, 0);
        generateYield(1 ether);

        setETH(750 ether);
        skip(yieldEligibleTime);
        uint256 ercDebtAtOraclePrice = getShortRecord(sender, C.SHORT_STARTING_ID).ercDebt.mul(diamond.getOracleAssetPrice(asset));

        liquidateErcEscrowed(sender, C.SHORT_STARTING_ID, DEFAULT_AMOUNT, extra);

        assertGt(diamond.getVaultUserStruct(vault, sender).ethEscrowed, 1000 ether + (collateral - ercDebtAtOraclePrice));
        checkTappDidNotReceiveYield();
    }

    function test_DittoRewardPenalty() public {
        // Create shortRecords: receiver, sender, extra, extra2
        vm.prank(receiver);
        createLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT * 4);
        vm.prank(receiver);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        vm.prank(sender);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        vm.prank(extra);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);
        vm.prank(extra2);
        createLimitShort(DEFAULT_PRICE, DEFAULT_AMOUNT);

        // Modify this shortRecord before time skip
        vm.prank(sender);
        diamond.increaseCollateral(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE) * 6);

        generateYield(1 ether);
        // Prepare distributeYield
        skip(yieldEligibleTime);
        address[] memory assets = new address[](1);
        assets[0] = asset;

        // Base Case
        STypes.ShortRecord memory short = getShortRecord(receiver, C.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 6 ether);
        vm.prank(receiver);
        diamond.distributeYield(assets);
        // Double CR through increase
        short = getShortRecord(sender, C.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 12 ether);
        vm.prank(sender);
        diamond.distributeYield(assets);
        // Double CR through oracle price change
        _setETH(8000 ether);
        short = getShortRecord(extra, C.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 12 ether);
        vm.prank(extra);
        diamond.distributeYield(assets);
        // Halve doubled CR though decrease
        vm.prank(extra2);
        diamond.decreaseCollateral(asset, C.SHORT_STARTING_ID, DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE) * 3);
        short = getShortRecord(extra2, C.SHORT_STARTING_ID);
        assertEq(diamond.getCollateralRatio(asset, short), 6 ether);
        vm.prank(extra2);
        diamond.distributeYield(assets);

        // Check absolute ditto reward for base case
        uint256 dittoRewardShortersTotal = (yieldEligibleTime + 1).mul(diamond.dittoShorterRate(vault));
        uint256 dittoRewardBaseCase = dittoRewardShortersTotal / 5 - 1;
        uint256 dittoRewardPenalized = dittoRewardShortersTotal / 10 - 1;
        assertEq(diamond.getDittoReward(vault, receiver), dittoRewardBaseCase);
        assertApproxEqAbs(diamond.getDittoReward(vault, extra), dittoRewardPenalized, 1);
        // short1 = short2 bc increasing collateral doesnt affect relative ditto reward
        assertEq(diamond.getDittoReward(vault, receiver), diamond.getDittoReward(vault, sender));
        // short3 = short4 bc decreasing collateral doesnt affect relative ditto reward
        assertEq(diamond.getDittoReward(vault, extra), diamond.getDittoReward(vault, extra2));
    }

    //checking tithe after dethTitheMod has changed
    function test_CanYieldDistributeAfterTitheChange() public {
        assertEq(diamond.getTithe(vault), 0.1 ether);
        uint80 savedPrice = uint80(diamond.getProtocolAssetPrice(asset));
        uint80 askPrice = uint80(savedPrice.mul(0.96 ether));
        uint80 bidPrice = uint80(savedPrice.mul(0.97 ether));
        //Cause tithe to change
        fundLimitBidOpt(bidPrice, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(askPrice, DEFAULT_AMOUNT, sender);

        assertEq(diamond.getTithe(vault), 0.775 ether);
        oneYieldDistribution(DEFAULT_PRICE, 200000 ether, DEFAULT_PRICE, 400000 ether, BID_FIRST);

        //change back to normal because orders were matched "not at discount"
        assertEq(diamond.getTithe(vault), 0.1 ether);
    }
}
