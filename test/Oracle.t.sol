// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U80, U88} from "contracts/libraries/PRBMathHelper.sol";
import {C} from "contracts/libraries/Constants.sol";
import {OBFixture} from "test/utils/OBFixture.sol";

// import {console} from "contracts/libraries/console.sol";

contract OracleTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function setUp() public override {
        super.setUp();
    }

    function test_GetBaseAssetPrice() public {
        assertEq(DEFAULT_PRICE, diamond.getOracleAssetPrice(asset));

        _setETH(3999 ether);
        assertEq(U256.inv(3999 ether), diamond.getOracleAssetPrice(asset));
    }

    //Test oracleprice updates
    function test_OraclePriceUpdateOneHour() public {
        //initial check
        assertEq(testFacet.getOracleTimeT(asset), 0);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(testFacet.getOracleTimeT(asset), 0); //unchanged

        skip(1 hours - 1 seconds); //1 second already skipped in OBFixture
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        assertEq(testFacet.getOracleTimeT(asset), 3600); //updated
    }

    // @dev triggering forcedBid, which has a fifteen minute update
    function test_OraclePriceUpdateFifteenMinutesExitShort() public {
        //initial check
        assertEq(testFacet.getOracleTimeT(asset), 0);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        assertEq(testFacet.getOracleTimeT(asset), 0); //unchanged

        skip(14 minutes);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver); //ask for exitShort
        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
        assertEq(testFacet.getOracleTimeT(asset), 0); //unchanged

        skip(59 seconds); //1 second already skipped in OBFixture
        exitShort(C.SHORT_STARTING_ID, DEFAULT_AMOUNT, DEFAULT_PRICE, sender);
        assertEq(testFacet.getOracleTimeT(asset), 15 minutes); //updated
    }

    // @dev triggering forcedBid, which has a fifteen minute update
    function test_OraclePriceUpdateFifteenMinutesLiquidation() public {
        //initial check
        assertEq(testFacet.getOracleTimeT(asset), 0);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), sender);
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver);
        assertEq(testFacet.getOracleTimeT(asset), 0); //unchanged

        // liquidation set up
        _setETH(2666 ether); //set to liquidation

        //use fundLimitAsk to provide seller for Liquidation and to update the 10 hr time skip
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT.mulU88(2 ether), receiver); //ask for liquidation

        // @dev 1 second already skipped in OBFixture
        skip(15 minutes - 1 seconds);
        diamond.liquidate(asset, sender, C.SHORT_STARTING_ID, shortHintArrayStorage, 0);
        assertEq(testFacet.getOracleTimeT(asset), 15 minutes); //updated
    }

    //HELPERS
    bool public constant SHORT = true;
    bool public constant BID = false;
    // @dev > or < .5%
    int256 public constant GT_THRESHOLD = 4010 ether;
    int256 public constant LT_THRESHOLD = 3990 ether;

    function matchOrderAndUpdateOracle(bool firstOrder, int256 ethPrice) public {
        // @dev match at price higher than .5% of SAVED oracle
        uint80 oraclePrice5pctHigherTheshold = DEFAULT_PRICE.mulU80(1.005 ether);

        // @dev create order to be matched
        if (firstOrder) {
            fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        }
        // @dev bid price must be gt short price to match.
        // @dev make bid price gt 1.05x the saved Oracle to force oracle update
        else {
            fundLimitBidOpt(oraclePrice5pctHigherTheshold + 1 wei, DEFAULT_AMOUNT, receiver);
        }

        if (firstOrder) {
            checkSavedOracleTimeAndPrice({oracleTime: 0, oraclePrice: DEFAULT_PRICE});
        } else {
            checkSavedOracleTimeAndPrice({oracleTime: 0, oraclePrice: DEFAULT_PRICE});
        }
        // @dev mock block time progression. Already skipped 1 second in OBFixture
        skip(2 minutes - 1 seconds);

        //Update roundData without setting saved oracle
        ethAggregator.setRoundData(
            92233720368547778907 wei, ethPrice / ORACLE_DECIMALS, block.timestamp, block.timestamp, 92233720368547778907 wei
        );

        uint256 newOracleSpotPrice = uint256(ethPrice).inv();

        // @dev update on match from incomingBid
        if (firstOrder) {
            fundLimitBidOpt(oraclePrice5pctHigherTheshold + 1 wei, DEFAULT_AMOUNT, receiver);
        } else {
            fundLimitShortOpt(oraclePrice5pctHigherTheshold + 1 wei, DEFAULT_AMOUNT, sender);
        }

        // @dev oracleTime and price should have updated
        checkSavedOracleTimeAndPrice({oracleTime: 2 minutes, oraclePrice: newOracleSpotPrice});
    }

    function checkSavedOracleTimeAndPrice(uint256 oracleTime, uint256 oraclePrice) public {
        assertEq(testFacet.getOracleTimeT(asset), oracleTime);
        assertEq(testFacet.getOraclePriceT(asset), oraclePrice);
    }

    //Testing updateOracleAndStartingShortViaThreshold
    //Test when price is within threshold
    function test_NoUpdateIncomingBidPriceWithinThreshold() public {
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        checkSavedOracleTimeAndPrice({oracleTime: 0, oraclePrice: DEFAULT_PRICE});
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        checkSavedOracleTimeAndPrice({oracleTime: 0, oraclePrice: DEFAULT_PRICE}); //no change!
    }

    function test_NoUpdateIncomingShortPriceWithinThreshold() public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        checkSavedOracleTimeAndPrice({oracleTime: 0, oraclePrice: DEFAULT_PRICE});
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        checkSavedOracleTimeAndPrice({oracleTime: 0, oraclePrice: DEFAULT_PRICE}); //no change!
    }

    //Testing Order Price < saved oracle price
    function test_UpdateViaThresholdIncomingBidOrderPriceLtOracle() public {
        matchOrderAndUpdateOracle({firstOrder: SHORT, ethPrice: LT_THRESHOLD});
    }

    function test_UpdateViaThresholdIncomingShortOrderPriceLtOracle() public {
        matchOrderAndUpdateOracle({firstOrder: BID, ethPrice: LT_THRESHOLD});
    }

    //Testing Order Price > saved oracle price
    function test_UpdateViaThresholdIncomingBidOrderPriceGtOracle() public {
        matchOrderAndUpdateOracle({firstOrder: SHORT, ethPrice: GT_THRESHOLD});
    }

    function test_UpdateViaThresholdIncomingShortOrderPriceGtOracle() public {
        matchOrderAndUpdateOracle({firstOrder: BID, ethPrice: GT_THRESHOLD});
    }
}
