// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {F} from "contracts/libraries/DataTypes.sol";

enum PrimaryScenarios {
    CRatioBetween110And200,
    CRatioBelow110,
    CRatioBelow110BlackSwan
}
// @dev only used for testing

enum SecondaryScenarios {
    CRatioBetween110And150,
    CRatioBetween100And110,
    CRatioBelow100
}
// @dev only used for testing

enum SecondaryType {
    LiquidateErcEscrowed,
    LiquidateWallet
}

enum DiscountLevels {
    Gte1,
    Gte2,
    Gte3,
    Gte4
}

library TestTypes {
    struct StorageUser {
        address addr;
        uint256 ethEscrowed;
        uint256 ercEscrowed;
    }

    struct AssetNormalizedStruct {
        F frozen;
        uint16 orderId;
        uint256 initialCR;
        uint256 primaryLiquidationCR;
        uint256 secondaryLiquidationCR;
        uint256 forcedBidPriceBuffer;
        uint256 penaltyCR;
        uint256 tappFeePct;
        uint256 callerFeePct;
        uint16 startingShortId;
        uint256 minBidEth;
        uint256 minAskEth;
        uint256 minShortErc;
        uint256 recoveryCR;
        uint256 dittoTargetCR;
        uint8 assetId;
    }

    struct BridgeNormalizedStruct {
        uint256 withdrawalFee;
    }

    struct MockOracleData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }
}
