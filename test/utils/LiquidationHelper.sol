// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {U256, U128, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {C} from "contracts/libraries/Constants.sol";
import {STypes, O} from "contracts/libraries/DataTypes.sol";
import {VAULT} from "contracts/libraries/Constants.sol";

import {OBFixture} from "test/utils/OBFixture.sol";
import {TestTypes} from "test/utils/TestTypes.sol";

// import {console} from "contracts/libraries/console.sol";

contract LiquidationHelper is OBFixture {
    using U256 for uint256;
    using U128 for uint128;
    using U88 for uint88;
    using U80 for uint80;

    bool public constant WALLET = true;
    bool public constant ERC_ESCROWED = false;

    struct LiquidationStruct {
        uint256 ercDebtMatched;
        uint256 ercDebtSocialized;
        uint256 ercDebtRate;
        uint256 ethDebt;
        uint256 cRatio;
        uint256 bidPrice;
        uint256 ethFilled;
        uint256 ethOffered;
        uint256 ethLeft;
        uint256 gasFee;
        uint256 tappFee;
        uint256 callerFee;
    }

    function setUp() public virtual override {
        super.setUp();
    }

    function simulateLiquidation(
        TestTypes.StorageUser memory r,
        TestTypes.StorageUser memory s,
        int256 ethPrice,
        address liquidator,
        address shorter,
        uint16 shortOrderId
    ) public returns (LiquidationStruct memory) {
        LiquidationStruct memory m;
        _setETH(ethPrice);
        STypes.ShortRecord memory short = getShortRecord(s.addr, C.SHORT_STARTING_ID);
        STypes.Order[] memory asks = getAsks();
        uint256 receiverErcOnBook = 0;
        for (uint256 i = 0; i < asks.length; i++) {
            if ((asks[i].addr == r.addr && (asks[i].orderType == O.LimitAsk))) {
                receiverErcOnBook += asks[i].ercAmount;
            }
        }

        uint256 tappFeePct = diamond.getAssetNormalizedStruct(asset).tappFeePct;
        uint256 callerFeePct = diamond.getAssetNormalizedStruct(asset).callerFeePct;

        m.ercDebtMatched = min(receiverErcOnBook, short.ercDebt);
        m.cRatio = diamond.getCollateralRatio(asset, short);
        m.bidPrice = diamond.getOracleAssetPrice(asset).mul(diamond.getAssetNormalizedStruct(asset).forcedBidPriceBuffer);
        m.ethOffered = short.ercDebt.mul(m.bidPrice).mul(1 ether + tappFeePct + callerFeePct);

        uint256 tappPlusCollateral = diamond.getVaultUserStruct(VAULT.ONE, tapp).ethEscrowed + short.collateral;
        if (tappPlusCollateral < m.ethOffered) {
            m.ercDebtSocialized = short.ercDebt - tappPlusCollateral.div(m.bidPrice.mul(1 ether + tappFeePct + callerFeePct));
            m.ercDebtRate += m.ercDebtSocialized.div(diamond.getAssetStruct(asset).ercDebt - short.ercDebt);
        }

        vm.startPrank(liquidator);
        (m.gasFee, m.ethFilled) = diamond.liquidate(asset, shorter, C.SHORT_STARTING_ID, shortHintArrayStorage, shortOrderId);
        m.tappFee = m.ethFilled.mul(tappFeePct);
        m.callerFee = m.ethFilled.mul(callerFeePct);

        return (m);
    }

    function prepareAsk(uint80 askPrice, uint88 askAmount) public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        fundLimitAskOpt(askPrice, askAmount, receiver);
        //check initial short info
        assertEq(getShortRecordCount(sender), 1);
        assertEq(getShortRecord(sender, C.SHORT_STARTING_ID).collateral, DEFAULT_AMOUNT.mulU88(DEFAULT_PRICE) * 6);

        initialAssertStruct();
    }

    function prepareShort(uint88 askAmount, int256 ethPrice) public {
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitShortOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);
        r.ercEscrowed = DEFAULT_AMOUNT; //from first bid and short match
        assertStruct(receiver, r);

        // @dev need to set ethPrice. If created after, the short might get skipped over.
        _setETH(ethPrice);
        uint80 askPrice = uint80(diamond.getOracleAssetPrice(asset));
        fundLimitShortOpt(askPrice, askAmount, extra);

        // @dev confirming short id to use in liquidate()
        STypes.Order[] memory shorts = getShorts();
        assertEq(shorts[0].id, 101);

        //check initial short info
        STypes.ShortRecord memory shortRecord = getShortRecord(sender, C.SHORT_STARTING_ID);
        assertEq(getShortRecordCount(sender), 1);
        assertEq(shortRecord.collateral, DEFAULT_PRICE.mul(DEFAULT_AMOUNT) * 6);
        skip(1);

        initialAssertStruct();
    }

    function checkShortsAndAssetBalance(
        address _shorter,
        uint256 _shortLen,
        uint256 _collateral,
        uint256 _ercDebt,
        uint256 _ercDebtAsset,
        uint256 _ercDebtRateAsset,
        uint256 _ercAsset
    ) public {
        STypes.ShortRecord memory shortRecord = getShortRecord(_shorter, C.SHORT_STARTING_ID);
        assertEq(getShortRecordCount(_shorter), _shortLen);

        if (getShortRecordCount(_shorter) > 0) {
            assertEq(shortRecord.collateral, _collateral);
            assertEq(shortRecord.ercDebt, _ercDebt);
        }

        assertEq(diamond.getAssetStruct(asset).ercDebt, _ercDebtAsset);
        assertEq(diamond.getAssetStruct(asset).ercDebtRate, _ercDebtRateAsset);
        assertEq(getTotalErc(), _ercAsset);
    }

    function initialAssertStruct() public {
        r.ethEscrowed = 0;
        r.ercEscrowed = DEFAULT_AMOUNT; //from first bid and short match
        assertStruct(receiver, r);
        s.ethEscrowed = 0;
        s.ercEscrowed = 0;
        assertStruct(sender, s);
        e.ethEscrowed = 0;
        e.ercEscrowed = 0;
        assertStruct(extra, e);
        t.ethEscrowed = 0;
        t.ercEscrowed = 0;
        assertStruct(tapp, t);
    }

    //testing max function
    bool internal constant INCREASE_LIQUIDATION_LIMIT = true;
    bool internal constant DECREASE_LIQUIDATION_LIMIT = false;
    bool internal constant SHORTER = true;
    bool internal constant TAPP = false;

    function createShortsAndChangeforcedBidPriceBuffer(bool changeLL) public returns (uint256) {
        prepareAsk(DEFAULT_PRICE, DEFAULT_AMOUNT);

        uint256 forcedBidPriceBuffer = diamond.getAssetNormalizedStruct(asset).forcedBidPriceBuffer;
        assertEq(forcedBidPriceBuffer, 1.1 ether);

        //change forcedBidPriceBuffer to 1.2 ether
        vm.prank(owner);
        if (changeLL) {
            testFacet.setforcedBidPriceBufferT(asset, 120);
        } else {
            testFacet.setforcedBidPriceBufferT(asset, 100);
        }

        return diamond.getAssetNormalizedStruct(asset).forcedBidPriceBuffer;
    }

    function confirmBuyer(bool buyer) public {
        int256 ethPrice;
        depositEth(tapp, FUNDED_TAPP);
        if (buyer) {
            ethPrice = 2666 ether;
        } else {
            ethPrice = 730 ether;
        }

        LiquidationStruct memory m = simulateLiquidation(r, s, ethPrice, receiver, sender, 0);

        // @dev tapp ethEscrowed differs depending on if it was used to pay for forcedBid
        if (buyer) {
            assertEq(diamond.getVaultUserStruct(VAULT.ONE, tapp).ethEscrowed, FUNDED_TAPP + m.tappFee);
        } else {
            uint256 shorterCollateral = DEFAULT_AMOUNT.mul(DEFAULT_PRICE).mul(6 ether);
            assertEq(
                diamond.getVaultUserStruct(VAULT.ONE, tapp).ethEscrowed,
                FUNDED_TAPP + shorterCollateral - m.ethFilled - m.callerFee - m.gasFee
            );
        }
    }
}
