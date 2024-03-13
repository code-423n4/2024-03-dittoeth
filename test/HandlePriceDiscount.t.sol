// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {C, VAULT} from "contracts/libraries/Constants.sol";
import {STypes, MTypes, O} from "contracts/libraries/DataTypes.sol";
import {DiscountLevels} from "test/utils/TestTypes.sol";
import {OBFixture} from "test/utils/OBFixture.sol";
import {console} from "contracts/libraries/console.sol";

contract HandlePriceDiscountTest is OBFixture {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    bool SAME_PRICE = true;
    bool DIFFERENT_PRICE = false;
    uint88 amount = DEFAULT_AMOUNT * 2;

    function setUpPricesIncomingAsk(DiscountLevels discountLevel, bool samePrice)
        public
        view
        returns (uint80 askPrice, uint80 bidPrice)
    {
        uint80 savedPrice = uint80(diamond.getProtocolAssetPrice(asset));
        uint256 askMultiplier;
        uint256 bidMultiplier;

        // @dev system matches based on price of order on ob (in these cases, the bid's price)
        if (discountLevel == DiscountLevels.Gte1) {
            if (samePrice) {
                bidMultiplier = askMultiplier = 0.99 ether;
            } else {
                askMultiplier = 0.98 ether;
                bidMultiplier = 0.99 ether;
            }
        } else if (discountLevel == DiscountLevels.Gte2) {
            if (samePrice) {
                bidMultiplier = askMultiplier = 0.98 ether;
            } else {
                askMultiplier = 0.97 ether;
                bidMultiplier = 0.98 ether;
            }
        } else if (discountLevel == DiscountLevels.Gte3) {
            if (samePrice) {
                bidMultiplier = askMultiplier = 0.97 ether;
            } else {
                askMultiplier = 0.96 ether;
                bidMultiplier = 0.97 ether;
            }
        } else if (discountLevel == DiscountLevels.Gte4) {
            if (samePrice) {
                bidMultiplier = askMultiplier = 0.96 ether;
            } else {
                askMultiplier = 0.95 ether;
                bidMultiplier = 0.96 ether;
            }
        }

        askPrice = uint80(savedPrice.mul(askMultiplier));
        bidPrice = uint80(savedPrice.mul(bidMultiplier));
    }

    function setUpPricesIncomingBid(DiscountLevels discountLevel, bool samePrice)
        public
        view
        returns (uint80 askPrice, uint80 bidPrice)
    {
        uint80 savedPrice = uint80(diamond.getProtocolAssetPrice(asset));
        uint256 askMultiplier;
        uint256 bidMultiplier;
        // @dev system matches based on price of order on ob (in these cases, the ask's price)
        if (discountLevel == DiscountLevels.Gte1) {
            if (samePrice) {
                bidMultiplier = askMultiplier = 0.99 ether;
            } else {
                askMultiplier = 0.99 ether;
                bidMultiplier = 1 ether;
            }
        } else if (discountLevel == DiscountLevels.Gte2) {
            if (samePrice) {
                bidMultiplier = askMultiplier = 0.98 ether;
            } else {
                askMultiplier = 0.98 ether;
                bidMultiplier = 0.99 ether;
            }
        } else if (discountLevel == DiscountLevels.Gte3) {
            if (samePrice) {
                bidMultiplier = askMultiplier = 0.97 ether;
            } else {
                askMultiplier = 0.97 ether;
                bidMultiplier = 0.98 ether;
            }
        } else if (discountLevel == DiscountLevels.Gte4) {
            if (samePrice) {
                bidMultiplier = askMultiplier = 0.96 ether;
            } else {
                askMultiplier = 0.96 ether;
                bidMultiplier = 0.97 ether;
            }
        }

        askPrice = uint80(savedPrice.mul(askMultiplier));
        bidPrice = uint80(savedPrice.mul(bidMultiplier));
    }

    // @dev handleDiscount: isDiscounted = match price < 1% of the saved oracle price
    function test_handleDiscount_IsNotDiscountAndTitheWasNotChanged() public {
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        // @dev unchanged from deployment
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);
        assertEq(diamond.getTithe(vault), 0.1 ether);
    }

    //IncomingAsk
    function test_handleDiscount_IsDiscounted_Gt1Pct_IncomingAsk_SamePrice() public {
        (uint80 askPrice, uint80 bidPrice) = setUpPricesIncomingAsk({discountLevel: DiscountLevels.Gte1, samePrice: SAME_PRICE});

        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitBidOpt(bidPrice, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(askPrice / 2, DEFAULT_AMOUNT, receiver); //don't match
        fundLimitAskOpt(askPrice, amount, sender);
        assertEq(getBids().length, 1);
        assertEq(getBids()[0].price, askPrice / 2);

        // @dev tithe increased bc match price was gt 1% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 22_50);
        assertEq(diamond.getTithe(vault), 0.325 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt1Pct_IncomingAsk_DifferentPrice() public {
        (uint80 askPrice, uint80 bidPrice) =
            setUpPricesIncomingAsk({discountLevel: DiscountLevels.Gte1, samePrice: DIFFERENT_PRICE});

        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitBidOpt(bidPrice, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(askPrice / 2, DEFAULT_AMOUNT, receiver); //don't match
        fundLimitAskOpt(askPrice, amount, sender);
        assertEq(getBids().length, 1);
        assertEq(getBids()[0].price, askPrice / 2);

        // @dev tithe increased bc match price was gt 1% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 22_50);
        assertEq(diamond.getTithe(vault), 0.325 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt2Pct_IncomingAsk_SamePrice() public {
        (uint80 askPrice, uint80 bidPrice) = setUpPricesIncomingAsk({discountLevel: DiscountLevels.Gte2, samePrice: SAME_PRICE});
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitBidOpt(bidPrice, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(askPrice / 2, DEFAULT_AMOUNT, receiver); //don't match
        fundLimitAskOpt(askPrice, amount, sender);
        assertEq(getBids().length, 1);
        assertEq(getBids()[0].price, askPrice / 2);

        // @dev tithe increased bc match price was gt 2% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 45_00);
        assertEq(diamond.getTithe(vault), 0.55 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt2Pct_IncomingAsk_DifferentPrice() public {
        (uint80 askPrice, uint80 bidPrice) =
            setUpPricesIncomingAsk({discountLevel: DiscountLevels.Gte2, samePrice: DIFFERENT_PRICE});
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitBidOpt(bidPrice, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(askPrice / 2, DEFAULT_AMOUNT, receiver); //don't match
        fundLimitAskOpt(askPrice, amount, sender);
        assertEq(getBids().length, 1);
        assertEq(getBids()[0].price, askPrice / 2);

        // @dev tithe increased bc match price was gt 2% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 45_00);
        assertEq(diamond.getTithe(vault), 0.55 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt3Pct_IncomingAsk_SamePrice() public {
        (uint80 askPrice, uint80 bidPrice) = setUpPricesIncomingAsk({discountLevel: DiscountLevels.Gte3, samePrice: SAME_PRICE});

        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitBidOpt(bidPrice, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(askPrice / 2, DEFAULT_AMOUNT, receiver); //don't match
        fundLimitAskOpt(askPrice, amount, sender);
        assertEq(getBids().length, 1);
        assertEq(getBids()[0].price, askPrice / 2);

        // @dev tithe increased bc match price was gt 3% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 67_50);
        assertEq(diamond.getTithe(vault), 0.775 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt3Pct_IncomingAsk_DifferentPrice() public {
        (uint80 askPrice, uint80 bidPrice) =
            setUpPricesIncomingAsk({discountLevel: DiscountLevels.Gte3, samePrice: DIFFERENT_PRICE});

        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitBidOpt(bidPrice, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(askPrice / 2, DEFAULT_AMOUNT, receiver); //don't match
        fundLimitAskOpt(askPrice, amount, sender);
        assertEq(getBids().length, 1);
        assertEq(getBids()[0].price, askPrice / 2);

        // @dev tithe increased bc match price was gt 3% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 6750);
        assertEq(diamond.getTithe(vault), 0.775 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt4Pct_IncomingAsk_SamePrice() public {
        (uint80 askPrice, uint80 bidPrice) = setUpPricesIncomingAsk({discountLevel: DiscountLevels.Gte4, samePrice: SAME_PRICE});

        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitBidOpt(bidPrice, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(askPrice / 2, DEFAULT_AMOUNT, receiver); //don't match
        fundLimitAskOpt(askPrice, amount, sender);
        assertEq(getBids().length, 1);
        assertEq(getBids()[0].price, askPrice / 2);

        // @dev tithe increased bc match price was gt 4% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 90_00);
        assertEq(diamond.getTithe(vault), 1 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt4Pct_IncomingAsk_DifferentPrice() public {
        (uint80 askPrice, uint80 bidPrice) =
            setUpPricesIncomingAsk({discountLevel: DiscountLevels.Gte4, samePrice: DIFFERENT_PRICE});

        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitBidOpt(bidPrice, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(askPrice / 2, DEFAULT_AMOUNT, receiver); //don't match
        fundLimitAskOpt(askPrice, amount, sender);
        assertEq(getBids().length, 1);
        assertEq(getBids()[0].price, askPrice / 2);

        // @dev tithe increased bc match price was gt 4% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 90_00);
        assertEq(diamond.getTithe(vault), 1 ether);
    }

    function test_handleDiscount_IsDiscounted_HugeDiscount_IncomingAsk_SamePrice() public {
        uint80 savedPrice = uint80(diamond.getProtocolAssetPrice(asset));
        // @dev 80% discount
        uint80 askPrice = uint80(savedPrice.mul(0.2 ether));
        uint80 bidPrice = uint80(savedPrice.mul(0.2 ether));

        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitBidOpt(bidPrice, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(askPrice / 2, DEFAULT_AMOUNT, receiver); //don't match
        fundLimitAskOpt(askPrice, amount, sender);
        assertEq(getBids().length, 1);
        assertEq(getBids()[0].price, askPrice / 2);

        // @dev tithe increased bc match price was gt 4% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 90_00);
        assertEq(diamond.getTithe(vault), 1 ether);
    }

    function test_handleDiscount_IsDiscounted_HugeDiscount_IncomingAsk_DifferentPrice() public {
        uint80 savedPrice = uint80(diamond.getProtocolAssetPrice(asset));
        // @dev 80% discount
        uint80 askPrice = uint80(savedPrice.mul(0.2 ether));
        uint80 bidPrice = uint80(savedPrice.mul(0.25 ether));

        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitBidOpt(bidPrice, DEFAULT_AMOUNT, receiver);
        fundLimitBidOpt(askPrice / 2, DEFAULT_AMOUNT, receiver); //don't match
        fundLimitAskOpt(askPrice, amount, sender);
        assertEq(getBids().length, 1);
        assertEq(getBids()[0].price, askPrice / 2);

        // @dev tithe increased bc match price was gt 4% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 90_00);
        assertEq(diamond.getTithe(vault), 1 ether);
    }

    //IncomingBid
    function test_handleDiscount_IsDiscounted_Gt1Pct_IncomingBid_SamePrice() public {
        (uint80 askPrice, uint80 bidPrice) = setUpPricesIncomingBid({discountLevel: DiscountLevels.Gte1, samePrice: SAME_PRICE});
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitAskOpt(askPrice, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(bidPrice * 2, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(bidPrice, amount, receiver);
        assertEq(getAsks().length, 1);
        assertEq(getAsks()[0].price, bidPrice * 2);

        // @dev tithe increased bc match price was gt 1% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 22_50);
        assertEq(diamond.getTithe(vault), 0.325 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt1Pct_IncomingBid_DifferentPrice() public {
        (uint80 askPrice, uint80 bidPrice) =
            setUpPricesIncomingBid({discountLevel: DiscountLevels.Gte1, samePrice: DIFFERENT_PRICE});
        // uint80 lowerPrice = 0.0002475 ether;
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitAskOpt(askPrice, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(bidPrice * 2, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(bidPrice, amount, receiver);
        assertEq(getAsks().length, 1);
        assertEq(getAsks()[0].price, bidPrice * 2);

        // @dev tithe increased bc match price was gt 1% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 22_50);
        assertEq(diamond.getTithe(vault), 0.325 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt2Pct_IncomingBid_SamePrice() public {
        (uint80 askPrice, uint80 bidPrice) = setUpPricesIncomingBid({discountLevel: DiscountLevels.Gte2, samePrice: SAME_PRICE});
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitAskOpt(askPrice, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(bidPrice * 2, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(bidPrice, amount, receiver);
        assertEq(getAsks().length, 1);
        assertEq(getAsks()[0].price, bidPrice * 2);

        // @dev tithe increased bc match price was gt 2% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 45_00);
        assertEq(diamond.getTithe(vault), 0.55 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt2Pct_IncomingBid_DifferentPrice() public {
        (uint80 askPrice, uint80 bidPrice) =
            setUpPricesIncomingBid({discountLevel: DiscountLevels.Gte2, samePrice: DIFFERENT_PRICE});
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitAskOpt(askPrice, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(bidPrice * 2, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(bidPrice, amount, receiver);
        assertEq(getAsks().length, 1);
        assertEq(getAsks()[0].price, bidPrice * 2);

        // @dev tithe increased bc match price was gt 2% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 45_00);
        assertEq(diamond.getTithe(vault), 0.55 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt3Pct_IncomingBid_SamePrice() public {
        (uint80 askPrice, uint80 bidPrice) = setUpPricesIncomingBid({discountLevel: DiscountLevels.Gte3, samePrice: SAME_PRICE});
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitAskOpt(askPrice, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(bidPrice * 2, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(bidPrice, amount, receiver);
        assertEq(getAsks().length, 1);
        assertEq(getAsks()[0].price, bidPrice * 2);

        // @dev tithe increased bc match price was gt 3% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 67_50);
        assertEq(diamond.getTithe(vault), 0.775 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt3Pct_IncomingBid_DifferentPrice() public {
        (uint80 askPrice, uint80 bidPrice) =
            setUpPricesIncomingBid({discountLevel: DiscountLevels.Gte3, samePrice: DIFFERENT_PRICE});
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitAskOpt(askPrice, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(bidPrice * 2, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(bidPrice, amount, receiver);
        assertEq(getAsks().length, 1);
        assertEq(getAsks()[0].price, bidPrice * 2);

        // @dev tithe increased bc match price was gt 3% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 67_50);
        assertEq(diamond.getTithe(vault), 0.775 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt4Pct_IncomingBid_SamePrice() public {
        (uint80 askPrice, uint80 bidPrice) = setUpPricesIncomingBid({discountLevel: DiscountLevels.Gte4, samePrice: SAME_PRICE});
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitAskOpt(askPrice, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(bidPrice * 2, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(bidPrice, amount, receiver);
        assertEq(getAsks().length, 1);
        assertEq(getAsks()[0].price, bidPrice * 2);

        // @dev tithe increased bc match price was gt 4% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 90_00);
        assertEq(diamond.getTithe(vault), 1 ether);
    }

    function test_handleDiscount_IsDiscounted_Gt4Pct_IncomingBid_DifferentPrice() public {
        (uint80 askPrice, uint80 bidPrice) =
            setUpPricesIncomingBid({discountLevel: DiscountLevels.Gte4, samePrice: DIFFERENT_PRICE});
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitAskOpt(askPrice, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(bidPrice * 2, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(bidPrice, amount, receiver);
        assertEq(getAsks().length, 1);
        assertEq(getAsks()[0].price, bidPrice * 2);

        // @dev tithe increased bc match price was gt 4% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 90_00);
        assertEq(diamond.getTithe(vault), 1 ether);
    }

    function test_handleDiscount_IsDiscounted_HugeDiscount_IncomingBid_SamePrice() public {
        uint80 savedPrice = uint80(diamond.getProtocolAssetPrice(asset));
        // @dev 80% discount
        uint80 askPrice = uint80(savedPrice.mul(0.2 ether));
        uint80 bidPrice = uint80(savedPrice.mul(0.2 ether));

        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitAskOpt(askPrice, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(bidPrice * 2, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(bidPrice, amount, receiver);
        assertEq(getAsks().length, 1);
        assertEq(getAsks()[0].price, bidPrice * 2);

        // @dev tithe increased bc match price was gt 4% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 90_00);
        assertEq(diamond.getTithe(vault), 1 ether);
    }

    function test_handleDiscount_IsDiscounted_HugeDiscount_IncomingBid_DifferentPrice() public {
        uint80 savedPrice = uint80(diamond.getProtocolAssetPrice(asset));
        // @dev 80% discount
        uint80 askPrice = uint80(savedPrice.mul(0.2 ether));
        uint80 bidPrice = uint80(savedPrice);

        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitAskOpt(askPrice, DEFAULT_AMOUNT, sender);
        fundLimitAskOpt(bidPrice * 2, DEFAULT_AMOUNT, sender);
        fundLimitBidOpt(bidPrice, amount, receiver);
        assertEq(getAsks().length, 1);
        assertEq(getAsks()[0].price, bidPrice * 2);

        // @dev tithe increased bc match price was gt 4% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 90_00);
        assertEq(diamond.getTithe(vault), 1 ether);
    }

    //reset tithe

    function test_handleDiscount_WasDiscountedButIsNoLonger() public {
        // @dev .00025 * .99 =  0.0002475
        uint80 lowerPrice = 0.0002475 ether;
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        // @dev trading at discount
        fundLimitBidOpt(lowerPrice, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(lowerPrice, DEFAULT_AMOUNT, sender);

        // @dev tithe increased bc match price was gt 1% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 22_50);
        assertEq(diamond.getTithe(vault), 0.325 ether);

        // @dev trading at even deeper discount
        lowerPrice = 0.00024 ether;
        fundLimitBidOpt(lowerPrice, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(lowerPrice, DEFAULT_AMOUNT, sender);

        // @dev tithe increased bc match price was gt 1% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 90_00);
        assertEq(diamond.getTithe(vault), 1 ether);

        // @dev trading at oracle
        fundLimitBidOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(DEFAULT_PRICE, DEFAULT_AMOUNT, sender);

        // @dev tithe back to normal
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);
        assertEq(diamond.getTithe(vault), 0.1 ether);
    }

    // call setTithe while discount is still occurring
    function test_handleDiscount_SetTitheDuringDiscountPeriod() public {
        (uint80 askPrice, uint80 bidPrice) =
            setUpPricesIncomingAsk({discountLevel: DiscountLevels.Gte3, samePrice: DIFFERENT_PRICE});
        assertEq(diamond.getTithe(vault), 0.1 ether);
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 0);

        fundLimitBidOpt(bidPrice, DEFAULT_AMOUNT, receiver);
        fundLimitAskOpt(askPrice, DEFAULT_AMOUNT, sender);

        // @dev tithe increased bc match price was gt 3% less than the saved oracle
        assertEq(diamond.getVaultStruct(vault).dethTithePercent, 10_00);
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 67_50);
        assertEq(diamond.getTithe(vault), 0.775 ether);
        vm.prank(owner);
        // @dev 10_00 is the valye set in DeployHelper (Currently)
        diamond.setTithe(vault, 10_00);

        // @dev make sure dethTitheMod is unchanged
        assertEq(diamond.getVaultStruct(vault).dethTitheMod, 67_50);
        assertEq(diamond.getTithe(vault), 0.775 ether);
    }
}
