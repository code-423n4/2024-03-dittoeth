// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";
import {C} from "contracts/libraries/Constants.sol";
import {IAsset} from "interfaces/IAsset.sol";
import {Errors} from "contracts/libraries/Errors.sol";

library LibAsset {
    // @dev used in ExitShortWallet and MarketShutDown
    function burnMsgSenderDebt(address asset, uint88 debt) internal {
        IAsset tokenContract = IAsset(asset);
        uint256 walletBalance = tokenContract.balanceOf(msg.sender);
        if (walletBalance < debt) revert Errors.InsufficientWalletBalance();
        tokenContract.burnFrom(msg.sender, debt);
        assert(tokenContract.balanceOf(msg.sender) < walletBalance);
    }

    // default of 1.7 ether, stored in uint16 as 170
    // range of [1-10],
    // 2 decimal places, divide by 100
    // i.e. 123 -> 1.23 ether
    // @dev cRatio that a short order has to begin at
    function initialCR(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].initialCR) * 1 ether) / C.TWO_DECIMAL_PLACES;
    }

    // default of 1.5 ether, stored in uint16 as 150
    // range of [1-5],
    // 2 decimal places, divide by 100
    // i.e. 120 -> 1.2 ether
    // less than initialCR
    // @dev cRatio that a shortRecord can be liquidated at
    function primaryLiquidationCR(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].primaryLiquidationCR) * 1 ether) / C.TWO_DECIMAL_PLACES;
    }

    // default of 1.4 ether, stored in uint16 as 140
    // range of [1-5],
    // 2 decimal places, divide by 100
    // i.e. 120 -> 1.2 ether
    // @dev cRatio that allows for secondary liquidations to happen
    // @dev via wallet or ercEscrowed (vault deposited usd)
    function secondaryLiquidationCR(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].secondaryLiquidationCR) * 1 ether) / C.TWO_DECIMAL_PLACES;
    }

    // default of 1.1 ether, stored in uint8 as 110
    // range of [1-2],
    // 2 decimal places, divide by 100
    // i.e. 120 -> 1.2 ether
    // less than primaryLiquidationCR
    // @dev buffer/slippage for forcedBid price
    function forcedBidPriceBuffer(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].forcedBidPriceBuffer) * 1 ether) / C.TWO_DECIMAL_PLACES;
    }

    // default of 1.1 ether, stored in uint8 as 110
    // range of [1-2],
    // 2 decimal places, divide by 100
    // i.e. 120 -> 1.2 ether
    // @dev cRatio where a shorter loses all collateral on liquidation
    function penaltyCR(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].penaltyCR) * 1 ether) / C.TWO_DECIMAL_PLACES;
    }

    // default of .025 ether, stored in uint8 as 25
    // range of [0.1-2.5%],
    // 3 decimal places, divide by 1000
    // i.e. 1234 -> 1.234 ether
    // @dev percentage of fees given to TAPP during liquidations
    function tappFeePct(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].tappFeePct) * 1 ether) / C.THREE_DECIMAL_PLACES;
    }

    // default of .005 ether, stored in uint8 as 5
    // range of [0.1-2.5%],
    // 3 decimal places, divide by 1000
    // i.e. 1234 -> 1.234 ether
    // @dev percentage of fees given to the liquidator during liquidations
    function callerFeePct(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].callerFeePct) * 1 ether) / C.THREE_DECIMAL_PLACES;
    }

    // default of .1 ether, stored in uint8 as 10
    // range of [.01 - 2.55],
    // 2 decimal places, divide by 100
    // i.e. 125 -> 1.25 ether
    // @dev dust amount
    function minBidEth(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].minBidEth) * 1 ether) / C.TWO_DECIMAL_PLACES;
    }

    // default of .1 ether, stored in uint8 as 10
    // range of [.01 - 2.55],
    // 2 decimal places, divide by 100
    // i.e. 125 -> 1.25 ether
    // @dev dust amount
    function minAskEth(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].minAskEth) * 1 ether) / C.TWO_DECIMAL_PLACES;
    }

    // default of 2000 ether, stored in uint16 as 2000
    // range of [1 - 65,535 (uint16 max)],
    // i.e. 2000 -> 2000 ether
    // @dev min short record debt
    function minShortErc(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return uint256(s.asset[asset].minShortErc) * 1 ether;
    }

    // default of 6 hours, stored in uint8 as 6
    // range of [1 - 48],
    // i.e. 6 -> 6 hours
    // @dev primary liquidation first eligibility window
    function firstLiquidationTime(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return uint256(s.asset[asset].firstLiquidationTime) * 1 hours;
    }

    // default of 8 hours, stored in uint8 as 8
    // range of [1 - 48],
    // i.e. 8 -> 8 hours
    // @dev primary liquidation second eligibility window
    function secondLiquidationTime(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return uint256(s.asset[asset].secondLiquidationTime) * 1 hours;
    }

    // default of 12 hours, stored in uint8 as 12
    // range of [1 - 48],
    // i.e. 12 -> 12 hours
    // @dev primary liquidation time limit
    function resetLiquidationTime(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return uint256(s.asset[asset].resetLiquidationTime) * 1 hours;
    }

    // default of 1.5 ether, stored in uint8 as 150
    // range of [1-2],
    // 2 decimal places, divide by 100
    // i.e. 120 -> 1.2 ether
    // @dev cRatio where the market enters recovery mode
    function recoveryCR(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].recoveryCR) * 1 ether) / C.TWO_DECIMAL_PLACES;
    }

    // default of 2.0 ether, stored in uint8 as 20
    // range of [1-25.6],
    // 1 decimal places, divide by 10
    // i.e. 12 -> 1.2 ether
    // @dev cRatio where shorter starts to lose ditto reward efficiency
    function dittoTargetCR(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.asset[asset].dittoTargetCR) * 1 ether) / C.ONE_DECIMAL_PLACES;
    }
}
