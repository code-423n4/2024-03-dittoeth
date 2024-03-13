// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IDiamond} from "interfaces/IDiamond.sol";
import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";
import {C} from "contracts/libraries/Constants.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {Errors} from "contracts/libraries/Errors.sol";

// import {console} from "contracts/libraries/console.sol";

library LibOracle {
    using U256 for uint256;

    function getOraclePrice(address asset) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        AggregatorV3Interface baseOracle = AggregatorV3Interface(s.baseOracle);
        uint256 protocolPrice = getPrice(asset);

        AggregatorV3Interface oracle = AggregatorV3Interface(s.asset[asset].oracle);
        if (address(oracle) == address(0)) revert Errors.InvalidAsset();

        try baseOracle.latestRoundData() returns (uint80 baseRoundID, int256 basePrice, uint256, uint256 baseTimeStamp, uint80) {
            if (oracle == baseOracle) {
                //@dev multiply base oracle by 10**10 to give it 18 decimals of precision
                uint256 basePriceInEth = basePrice > 0 ? uint256(basePrice * C.BASE_ORACLE_DECIMALS).inv() : 0;
                basePriceInEth = baseOracleCircuitBreaker(protocolPrice, baseRoundID, basePrice, baseTimeStamp, basePriceInEth);
                return basePriceInEth;
            } else {
                // prettier-ignore
                (
                    uint80 roundID,
                    int256 price,
                    /*uint256 startedAt*/
                    ,
                    uint256 timeStamp,
                    /*uint80 answeredInRound*/
                ) = oracle.latestRoundData();
                uint256 priceInEth = uint256(price).div(uint256(basePrice));
                oracleCircuitBreaker(roundID, baseRoundID, price, basePrice, timeStamp, baseTimeStamp);
                return priceInEth;
            }
        } catch {
            if (oracle == baseOracle) {
                return twapCircuitBreaker();
            } else {
                // prettier-ignore
                (
                    uint80 roundID,
                    int256 price,
                    /*uint256 startedAt*/
                    ,
                    uint256 timeStamp,
                    /*uint80 answeredInRound*/
                ) = oracle.latestRoundData();
                if (roundID == 0 || price == 0 || timeStamp > block.timestamp) revert Errors.InvalidPrice();

                uint256 twapInv = twapCircuitBreaker();
                uint256 priceInEth = uint256(price * C.BASE_ORACLE_DECIMALS).mul(twapInv);
                return priceInEth;
            }
        }
    }

    function baseOracleCircuitBreaker(
        uint256 protocolPrice,
        uint80 roundId,
        int256 chainlinkPrice,
        uint256 timeStamp,
        uint256 chainlinkPriceInEth
    ) private view returns (uint256 _protocolPrice) {
        bool invalidFetchData = roundId == 0 || timeStamp == 0 || timeStamp > block.timestamp || chainlinkPrice <= 0
            || block.timestamp > 2 hours + timeStamp;
        uint256 chainlinkDiff =
            chainlinkPriceInEth > protocolPrice ? chainlinkPriceInEth - protocolPrice : protocolPrice - chainlinkPriceInEth;
        bool priceDeviation = protocolPrice > 0 && chainlinkDiff.div(protocolPrice) > 0.5 ether;

        //@dev if there is issue with chainlink, get twap price. Verify twap and compare with chainlink
        if (invalidFetchData) {
            return twapCircuitBreaker();
        } else if (priceDeviation) {
            // Check valid twap price
            try IDiamond(payable(address(this))).estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 30 minutes) returns (uint256 twapPrice)
            {
                if (twapPrice == 0) {
                    return chainlinkPriceInEth;
                }

                uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);
                uint256 twapPriceInEth = twapPriceNormalized.inv();
                uint256 twapDiff = twapPriceInEth > protocolPrice ? twapPriceInEth - protocolPrice : protocolPrice - twapPriceInEth;

                // Save the price that is closest to saved oracle price
                if (chainlinkDiff <= twapDiff) {
                    return chainlinkPriceInEth;
                } else {
                    // Check valid twap liquidity
                    IERC20 weth = IERC20(C.WETH);
                    uint256 wethBal = weth.balanceOf(C.USDC_WETH);
                    if (wethBal < 100 ether) {
                        return chainlinkPriceInEth;
                    }
                    return twapPriceInEth;
                }
            } catch {
                return chainlinkPriceInEth;
            }
        } else {
            return chainlinkPriceInEth;
        }
    }

    function oracleCircuitBreaker(
        uint80 roundId,
        uint80 baseRoundId,
        int256 chainlinkPrice,
        int256 baseChainlinkPrice,
        uint256 timeStamp,
        uint256 baseTimeStamp
    ) private view {
        bool invalidFetchData = roundId == 0 || timeStamp == 0 || timeStamp > block.timestamp || chainlinkPrice <= 0
            || baseRoundId == 0 || baseTimeStamp == 0 || baseTimeStamp > block.timestamp || baseChainlinkPrice <= 0;

        if (invalidFetchData) revert Errors.InvalidPrice();
    }

    function twapCircuitBreaker() private view returns (uint256 twapPriceInEth) {
        // Check valid price
        uint256 twapPrice = IDiamond(payable(address(this))).estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 30 minutes);
        if (twapPrice == 0) revert Errors.InvalidTwapPrice();

        // Check valid liquidity
        IERC20 weth = IERC20(C.WETH);
        uint256 wethBal = weth.balanceOf(C.USDC_WETH);
        if (wethBal < 100 ether) revert Errors.InsufficientEthInLiquidityPool();

        uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);
        return twapPriceNormalized.inv();
    }

    /* 
    @dev C.HEAD to marks the start/end of the linked list, so the only properties needed are id/nextId/prevId.
    Helper methods are used to set the values of oraclePrice and oracleTime since they are set to different properties
    */
    function setPriceAndTime(address asset, uint256 oraclePrice, uint32 oracleTime) internal {
        AppStorage storage s = appStorage();
        s.bids[asset][C.HEAD].ercAmount = uint80(oraclePrice);
        s.bids[asset][C.HEAD].creationTime = oracleTime;
    }

    //@dev Intentionally using creationTime for oracleTime.
    function getTime(address asset) internal view returns (uint256 creationTime) {
        AppStorage storage s = appStorage();
        return s.bids[asset][C.HEAD].creationTime;
    }

    //@dev Intentionally using ercAmount for oraclePrice. Storing as price may lead to bugs in the match algos.
    function getPrice(address asset) internal view returns (uint80 oraclePrice) {
        AppStorage storage s = appStorage();
        return uint80(s.bids[asset][C.HEAD].ercAmount);
    }

    //@dev allows caller to save gas since reading spot price costs ~16K
    function getSavedOrSpotOraclePrice(address asset) internal view returns (uint256) {
        if (LibOrders.getOffsetTime() - getTime(asset) < 15 minutes) {
            return getPrice(asset);
        } else {
            return getOraclePrice(asset);
        }
    }
}
