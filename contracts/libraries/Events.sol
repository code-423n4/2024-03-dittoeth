// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";

library Events {
    event CreateShortRecord(address indexed asset, address indexed user, uint16 srId);
    event DeleteShortRecord(address indexed asset, address indexed user, uint16 srId);
    event CancelOrder(address indexed asset, uint16 orderId, O indexed orderType);

    event DepositEth(address indexed bridge, address indexed user, uint256 amount);
    event Deposit(address indexed bridge, address indexed user, uint256 amount);
    event Withdraw(address indexed bridge, address indexed user, uint256 amount, uint256 fee);
    event WithdrawTapp(address indexed bridge, address indexed recipient, uint256 amount);

    event IncreaseCollateral(address indexed asset, address indexed user, uint8 srId, uint256 amount);
    event DecreaseCollateral(address indexed asset, address indexed user, uint8 srId, uint256 amount);
    event CombineShorts(address indexed asset, address indexed user, uint8[] srIds);

    event ExitShortWallet(address indexed asset, address indexed user, uint8 srId, uint256 amount);
    event ExitShortErcEscrowed(address indexed asset, address indexed user, uint8 srId, uint256 amount);
    event ExitShort(address indexed asset, address indexed user, uint8 srId, uint256 amount);

    event MatchOrder(
        address indexed asset, address indexed user, O indexed orderType, uint16 orderId, uint88 fillEth, uint88 fillErc
    );

    event CreateOrder(address indexed asset, address indexed user, O indexed orderType, uint16 orderId, uint88 ercAmount);

    event Liquidate(address indexed asset, address indexed shorter, uint8 srId, address indexed caller, uint256 amount);
    event LiquidateSecondary(address indexed asset, MTypes.BatchLiquidation[] batches, address indexed caller, bool isWallet);

    event ProposeRedemption(address indexed asset, address indexed redeemer);
    event DisputeRedemptionAll(address indexed asset, address indexed redeemer);
    event ClaimRedemption(address indexed asset, address indexed redeemer);

    event UpdateYield(uint256 indexed vault);
    event DistributeYield(uint256 indexed vault, address indexed user, uint256 yieldAmount, uint256 dittoYieldShares);
    event ClaimDittoMatchedReward(uint256 indexed vault, address indexed user);

    event ShutdownMarket(address indexed asset);
    event RedeemErc(address indexed asset, address indexed user, uint256 amtWallet, uint256 amtEscrow);

    event CreateMarket(address indexed asset, STypes.Asset assetStruct);
    event ChangeMarketSetting(address indexed asset);
    event CreateVault(address indexed deth, uint256 indexed vault);
    event ChangeVaultSetting(uint256 indexed vault);
    event CreateBridge(address indexed bridge, STypes.Bridge bridgeStruct);
    event ChangeBridgeSetting(address indexed bridge);
    event NewOwnerCandidate(address newOwnerCandidate);
    event NewAdmin(address newAdmin);

    // ERC-721
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed spender, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
}
