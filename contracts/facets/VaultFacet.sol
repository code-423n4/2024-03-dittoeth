// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {IAsset as IERC20} from "interfaces/IAsset.sol";

import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {STypes} from "contracts/libraries/DataTypes.sol";

// import {console} from "contracts/libraries/console.sol";

/**
 * @title VaultFacet
 *
 * @notice Contract that owns all of the ETH and ERC20 tokens for the entire network
 */
contract VaultFacet is Modifiers {
    using U256 for uint256;

    address private immutable dethOne;

    constructor(address _deth) {
        dethOne = _deth;
    }

    /**
     * @notice Deposit ERC20 token into market system
     * @dev If frozen, prevent asset deposit
     * No event needed. Use the transfer event emitted in burnFrom
     * @param asset Asset address
     * @param amount Deposit amount
     */
    function depositAsset(address asset, uint104 amount) external onlyValidAsset(asset) isNotFrozen(asset) nonReentrant {
        if (amount == 0) revert Errors.PriceOrAmountIs0();

        IERC20(asset).burnFrom(msg.sender, amount);
        s.assetUser[asset][msg.sender].ercEscrowed += amount;
    }

    /**
     * @notice Withdraw ERC20 token from market system
     *
     * @param asset Asset address
     * @param amount Withdrawal amount
     */
    function withdrawAsset(address asset, uint104 amount) external onlyValidAsset(asset) nonReentrant {
        if (amount == 0) revert Errors.PriceOrAmountIs0();

        STypes.AssetUser storage AssetUser = s.assetUser[asset][msg.sender];
        if (amount > AssetUser.ercEscrowed) revert Errors.InsufficientERCEscrowed();

        AssetUser.ercEscrowed -= amount;
        IERC20(asset).mint(msg.sender, amount);
    }
}
