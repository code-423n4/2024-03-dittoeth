// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {IBridge} from "contracts/interfaces/IBridge.sol";

import {STypes} from "contracts/libraries/DataTypes.sol";
import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";
import {C} from "contracts/libraries/Constants.sol";

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

// import {console} from "contracts/libraries/console.sol";

library LibVault {
    using U256 for uint256;
    using U88 for uint88;
    using {dethTithePercent} for uint256;

    // default of .1 ether, stored in uint16 as 10_00
    // range of [0-100],
    // i.e. 12.34% as 12_34 / 10_000 -> 0.1234 ether
    // @dev percentage of yield given to TAPP
    function dethTithePercent(uint256 vault) internal view returns (uint256) {
        AppStorage storage s = appStorage();

        return (uint256(s.vault[vault].dethTithePercent + s.vault[vault].dethTitheMod) * 1 ether) / C.FOUR_DECIMAL_PLACES;
    }

    // default of 19 ether, stored in uint16 as 19
    // range of [0-100],
    // i.e. 19 -> 0.19 ether
    // @dev per second rate of ditto tokens released to shorters
    // @dev 19 per second -> 5_991_840 per year
    function dittoShorterRate(uint256 vault) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.vault[vault].dittoShorterRate) * 1 ether) / C.TWO_DECIMAL_PLACES;
    }

    // default of 19 ether, stored in uint16 as 19
    // range of [0-100],
    // i.e. 19 -> 0.19 ether
    // @dev per second rate of ditto tokens released to qualifying matched orders
    // @dev 19 per second -> 5_991_840 per year
    function dittoMatchedRate(uint256 vault) internal view returns (uint256) {
        AppStorage storage s = appStorage();
        return (uint256(s.vault[vault].dittoMatchedRate) * 1 ether) / C.TWO_DECIMAL_PLACES;
    }

    // Loops through each bridge in the vault and totals present value
    function getDethTotal(uint256 vault) internal view returns (uint256 dethTotal) {
        AppStorage storage s = appStorage();
        address[] storage bridges = s.vaultBridges[vault];
        uint256 bridgeCount = bridges.length;

        for (uint256 i; i < bridgeCount;) {
            dethTotal += IBridge(bridges[i]).getDethValue();
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Updates the vault yield rate from staking rewards earned by bridge contracts holding LSD
     * @dev Does not distribute yield to any individual owner of shortRecords
     *
     * @param vault The vault that will be impacted
     */
    function updateYield(uint256 vault) internal {
        AppStorage storage s = appStorage();

        STypes.Vault storage Vault = s.vault[vault];
        STypes.VaultUser storage TAPP = s.vaultUser[vault][address(this)];
        // Retrieve vault variables
        uint88 dethTotalNew = uint88(getDethTotal(vault)); // @dev(safe-cast)
        uint88 dethTotal = Vault.dethTotal;
        uint88 dethCollateral = Vault.dethCollateral;
        uint88 dethTreasury = TAPP.ethEscrowed;

        // Pass yield if > 0
        if (dethTotalNew <= dethTotal) return;
        uint88 yield = dethTotalNew - dethTotal;

        // If no short records, yield goes to treasury
        if (dethCollateral == 0) {
            TAPP.ethEscrowed += yield;
            Vault.dethTotal = dethTotalNew;
            return;
        }

        // Assign yield to dethTreasury
        uint88 dethTreasuryReward = yield.mul(dethTreasury).divU88(dethTotal);
        yield -= dethTreasuryReward;
        // Assign tithe of the remaining yield to treasuryF
        uint88 tithe = yield.mulU88(vault.dethTithePercent());
        yield -= tithe;
        // Calculate change in yield rate
        uint80 dethYieldRate = yield.divU80(dethCollateral);
        if (dethYieldRate == 0) return;
        // Realize new totals if yield rate increases after rounding
        TAPP.ethEscrowed += dethTreasuryReward + tithe;
        Vault.dethTotal = dethTotalNew;
        Vault.dethYieldRate += dethYieldRate;
        Vault.dethCollateralReward += yield;
    }
}
