// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";
import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {STypes} from "contracts/libraries/DataTypes.sol";

// import {console} from "contracts/libraries/console.sol";

library LibSRRecovery {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    function checkRecoveryModeViolation(address asset, uint256 shortRecordCR, uint256 oraclePrice)
        internal
        view
        returns (bool recoveryViolation)
    {
        AppStorage storage s = appStorage();

        uint256 recoveryCR = LibAsset.recoveryCR(asset);
        if (shortRecordCR < recoveryCR) {
            // Only check asset CR if low enough
            STypes.Asset storage Asset = s.asset[asset];
            if (Asset.ercDebt > 0) {
                // If Asset.ercDebt == 0 then assetCR is NA
                uint256 assetCR = Asset.dethCollateral.div(oraclePrice.mul(Asset.ercDebt));
                if (assetCR < recoveryCR) {
                    // Market is in recovery mode and shortRecord CR too low
                    return true;
                }
            }
        }
    }
}
