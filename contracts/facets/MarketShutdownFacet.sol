// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U96, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {F, STypes} from "contracts/libraries/DataTypes.sol";
import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";

// import {console} from "contracts/libraries/console.sol";

contract MarketShutdownFacet is Modifiers {
    using U256 for uint256;
    using U96 for uint96;
    using U88 for uint88;
    using U80 for uint80;
    using {LibAsset.burnMsgSenderDebt} for address;

    /**
     * @notice Freezes the market permanently when c-ratio threshold reached
     * @dev Market is closed and shorters lose access to their positions
     * @dev Excess collateral when c-ratio > 1 sent to TAPP
     *
     * @param asset The market that will be impacted
     */
    function shutdownMarket(address asset) external onlyAdminOrDAO onlyValidAsset(asset) isNotFrozen(asset) nonReentrant {
        STypes.Asset storage Asset = s.asset[asset];

        uint256 oraclePrice = LibOracle.getOraclePrice(asset);
        uint256 cRatio = Asset.dethCollateral.div(oraclePrice.mul(Asset.ercDebt));
        if (cRatio > LibAsset.penaltyCR(asset)) {
            revert Errors.SufficientCollateral();
        } else {
            LibOracle.setPriceAndTime(asset, oraclePrice, LibOrders.getOffsetTime());
            uint256 vault = Asset.vault;
            uint88 assetDethCollateral = Asset.dethCollateral;
            s.vault[vault].dethCollateral -= assetDethCollateral;
            Asset.frozen = F.Permanent;
            if (cRatio > 1 ether) {
                // More than enough collateral to redeem ERC 1:1, send extras to TAPP
                uint88 excessDeth = assetDethCollateral - assetDethCollateral.divU88(cRatio);
                s.vaultUser[vault][address(this)].ethEscrowed += excessDeth;
                // Reduces c-ratio to 1
                Asset.dethCollateral -= excessDeth;
            }
        }
        emit Events.ShutdownMarket(asset);
    }

    /**
     * @notice Allows user to redeem erc from their wallet and/or escrow at the oracle price of market shutdown
     * @dev Market must be permanently frozen, redemptions drawn from the combined collateral of all short records
     *
     * @param asset The market that will be impacted
     */
    function redeemErc(address asset, uint88 amtWallet, uint88 amtEscrow) external isPermanentlyFrozen(asset) nonReentrant {
        STypes.Asset storage Asset = s.asset[asset];

        if (amtWallet > 0) {
            asset.burnMsgSenderDebt(amtWallet);
        }

        if (amtEscrow > 0) {
            s.assetUser[asset][msg.sender].ercEscrowed -= amtEscrow;
        }

        uint88 amtErc = amtWallet + amtEscrow;
        // Discount redemption when asset is undercollateralized
        uint88 amtDeth = amtErc.mul(Asset.dethCollateral).divU88(Asset.ercDebt);
        s.vaultUser[Asset.vault][msg.sender].ethEscrowed += amtDeth;
        emit Events.RedeemErc(asset, msg.sender, amtWallet, amtEscrow);
    }
}
