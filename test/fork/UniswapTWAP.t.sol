// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {C} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {IMockAggregatorV3} from "interfaces/IMockAggregatorV3.sol";

// import {console} from "contracts/libraries/console.sol";

contract UniswapTWAPForkTest is OBFixture {
    using U256 for uint256;

    uint256 public mainnetFork;
    address public constant USDC = C.USDC;
    address public constant WETH = C.WETH;
    uint256 public forkBlock = 17_373_211;
    uint256 public twapPrice = uint256(1902.501929 ether).inv();

    function setUp() public override {
        try vm.envString("MAINNET_RPC_URL") returns (string memory rpcUrl) {
            mainnetFork = vm.createSelectFork(rpcUrl, forkBlock);
        } catch {
            revert("env: MAINNET_RPC_URL failure");
        }
        assertEq(vm.activeFork(), mainnetFork);
        super.setUp();
    }

    function getTWAPPrice() public view returns (uint256 twapPriceInEther) {
        uint256 _twapPrice = diamond.estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 1 hours);
        twapPriceInEther = _twapPrice * (1 ether / C.DECIMAL_USDC);
    }

    function updateSavedOracle() public {
        skip(1 hours);
        fundLimitBid(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
    }

    function test_Revert_InvalidTWAPSecondsAgo() public {
        vm.expectRevert(Errors.InvalidTWAPSecondsAgo.selector);
        diamond.estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 0);
    }

    //@dev if chainlink's latest price is closer to last saved price vs TWAP
    function testFork_OraclePriceDeviationTooGreatUseChainlink() public {
        _setETHChainlinkOnly(8000 ether);

        //@dev at block height 17_373_211, TWAP WETH/USD price was ~1902 ether
        assertEq(getTWAPPrice(), 1902.501929 ether);
        uint256 chainlinkPrice = uint256(8000 ether).inv();
        assertEq(diamond.getOracleAssetPrice(_dusd), chainlinkPrice);
    }

    //@dev if TWAP's price is closer to last saved price vs chainlink latest round's
    function testFork_OraclePriceDeviationTooGreatUseTWAP() public {
        _setETHChainlinkOnly(1000 ether);

        assertEq(diamond.getOracleAssetPrice(_dusd), twapPrice);
    }

    //Circuit Breaker tests
    //@dev when chainlink price is zero, use TWAP
    function testFork_BasePriceEqZero() public {
        _setETH(0);
        assertEq(diamond.getOracleAssetPrice(_dusd), twapPrice);
    }

    function testFork_BasePriceLtZero() public {
        _setETH(-1);
        assertEq(diamond.getOracleAssetPrice(_dusd), twapPrice);
    }

    //@dev when chainlink roundId is zero, use TWAP
    function testFork_OracleRoundIdEqZero() public {
        ethAggregator = IMockAggregatorV3(_ethAggregator);
        ethAggregator.deleteRoundData();
        ethAggregator.setRoundData(0, 9000 ether / ORACLE_DECIMALS, block.timestamp, block.timestamp, 92233720368547778907);
        assertEq(diamond.getOracleAssetPrice(_dusd), twapPrice);
    }

    //@dev when chainlink data is stale use TWAP
    function testFork_OracleStaleData() public {
        skip(1682972900 seconds + 2 hours);
        assertEq(diamond.getOracleAssetPrice(_dusd), twapPrice);
    }

    //@dev when chainlink timestamp is stale use TWAP
    function testFork_OracleTimeStampEqZero() public {
        ethAggregator = IMockAggregatorV3(_ethAggregator);
        ethAggregator.setRoundData(
            92233720368547778907 wei, (8000 ether / ORACLE_DECIMALS) + 1 wei, block.timestamp, 0, 92233720368547778907 wei
        );
        assertEq(diamond.getOracleAssetPrice(_dusd), twapPrice);
    }

    //@dev when chainlink timestamp is > current block timestamp use TWAP
    function testFork_OracleTimeStampGtCurrentTime() public {
        ethAggregator = IMockAggregatorV3(_ethAggregator);
        ethAggregator.deleteRoundData();
        ethAggregator.setRoundData(0, 0, 0, block.timestamp + 1, 0);
        assertEq(diamond.getOracleAssetPrice(_dusd), twapPrice);
    }
}

contract BaseOracleChainlinkRevert is OBFixture {
    using U256 for uint256;

    uint256 public mainnetFork;
    uint256 public forkBlock = 17_373_211;
    uint256 public twapDusdPrice;

    function setUp() public virtual override {
        try vm.envString("MAINNET_RPC_URL") returns (string memory rpcUrl) {
            mainnetFork = vm.createSelectFork(rpcUrl, forkBlock);
        } catch {
            revert("env: MAINNET_RPC_URL failure");
        }
        assertEq(vm.activeFork(), mainnetFork);
        super.setUp();

        twapDusdPrice = getTWAPPrice();
        assertEq(twapDusdPrice, 1902.501929 ether);

        ethAggregator = IMockAggregatorV3(_ethAggregator);
        ethAggregator.setFail(true);
        _setETHChainlinkOnly(2000 ether);
    }

    function getTWAPPrice() public view returns (uint256 twapPriceInEther) {
        uint256 _twapPrice = diamond.estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 30 minutes);
        twapPriceInEther = _twapPrice * (1 ether / C.DECIMAL_USDC);
    }

    function testFork_BaseOracleTryCatch() public {
        assertEq(diamond.getOracleAssetPrice(_dusd), twapDusdPrice.inv());
    }
}

contract BaseOracleChainlinkRevertNonFork is OBFixture {
    using U256 for uint256;

    function setUp() public virtual override {
        super.setUp();
    }

    function testFork_BaseOracleTwapTryCatch() public {
        ethAggregator = IMockAggregatorV3(_ethAggregator);

        // Oracle will breach price check threshold, but TWAP reverts so use chainlink
        assertEq(diamond.getOracleAssetPrice(_dusd), DEFAULT_PRICE);
        _setETHChainlinkOnly(2000 ether);
        assertEq(diamond.getOracleAssetPrice(_dusd), DEFAULT_PRICE * 2);

        // Didn't deploy Uniswap mock so TWAP will revert (doesn't exist)
        ethAggregator.setFail(true);
        vm.expectRevert();
        diamond.getOracleAssetPrice(_dusd);
    }
}
