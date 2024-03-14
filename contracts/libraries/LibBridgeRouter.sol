// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {IBridge} from "contracts/interfaces/IBridge.sol";

import {STypes} from "contracts/libraries/DataTypes.sol";
import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";
import {OracleLibrary} from "contracts/libraries/UniswapOracleLibrary.sol";
import {C, VAULT} from "contracts/libraries/Constants.sol";
import {Errors} from "contracts/libraries/Errors.sol";

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

// import {console} from "contracts/libraries/console.sol";

library LibBridgeRouter {
    using U256 for uint256;
    using U88 for uint88;

    // Credit user account with dETH and bridge credit if applicable
    function addDeth(uint256 vault, uint256 bridgePointer, uint88 amount) internal {
        AppStorage storage s = appStorage();
        STypes.VaultUser storage VaultUser = s.vaultUser[vault][msg.sender];

        if (vault == VAULT.ONE) {
            // Only VAULT.ONE has mixed LST
            if (bridgePointer == VAULT.BRIDGE_RETH) {
                VaultUser.bridgeCreditReth += amount;
            } else {
                VaultUser.bridgeCreditSteth += amount;
            }
        }

        VaultUser.ethEscrowed += amount;
        s.vault[vault].dethTotal += amount;
    }

    // Determine how much dETH is NOT covered by bridge credits during withdrawal
    function assessDeth(uint256 vault, uint256 bridgePointer, uint88 amount, address rethBridge, address stethBridge)
        internal
        returns (uint88)
    {
        AppStorage storage s = appStorage();
        STypes.VaultUser storage VaultUser = s.vaultUser[vault][msg.sender];

        uint88 creditReth;
        uint88 creditSteth;
        if (bridgePointer == VAULT.BRIDGE_RETH) {
            // Withdraw RETH
            creditReth = VaultUser.bridgeCreditReth;
            if (creditReth >= amount) {
                VaultUser.bridgeCreditReth -= amount;
                return 0;
            }

            VaultUser.bridgeCreditReth = 0;
            amount -= creditReth;
            creditSteth = VaultUser.bridgeCreditSteth;
            if (creditSteth < C.ROUNDING_ZERO) {
                // Valid withdraw when no STETH credits
                return amount;
            } else {
                if (IBridge(stethBridge).getDethValue() < C.ROUNDING_ZERO) {
                    // Can withdraw RETH using STETH credit when STETH bridge is empty
                    if (creditSteth >= amount) {
                        VaultUser.bridgeCreditSteth -= amount;
                        return 0;
                    } else {
                        VaultUser.bridgeCreditSteth = 0;
                        return amount - creditSteth;
                    }
                } else {
                    // Must use available bridge credits on withdrawal
                    // @dev Prevents abusing bridge for arbitrage
                    revert Errors.MustUseExistingBridgeCredit();
                }
            }
        } else {
            // Withdraw STETH
            creditSteth = VaultUser.bridgeCreditSteth;
            if (creditSteth >= amount) {
                VaultUser.bridgeCreditSteth -= amount;
                return 0;
            }

            VaultUser.bridgeCreditSteth = 0;
            amount -= creditSteth;
            creditReth = VaultUser.bridgeCreditReth;
            if (creditReth < C.ROUNDING_ZERO) {
                // Valid withdraw when no RETH credits
                return amount;
            } else {
                if (IBridge(rethBridge).getDethValue() < C.ROUNDING_ZERO) {
                    // Can withdraw STETH using RETH credit when RETH bridge is empty
                    if (creditReth >= amount) {
                        VaultUser.bridgeCreditReth -= amount;
                        return 0;
                    } else {
                        VaultUser.bridgeCreditReth = 0;
                        return amount - creditReth;
                    }
                } else {
                    // Must use available bridge credits on withdrawal
                    // @dev Prevents abusing bridge for arbitrage
                    revert Errors.MustUseExistingBridgeCredit();
                }
            }
        }
    }

    // Bridge fees exist only to prevent free arbitrage, fee charged is the premium/discount differential
    // @dev Only applicable to VAULT.ONE which has mixed LST
    function withdrawalFeePct(uint256 bridgePointer, address rethBridge, address stethBridge) internal view returns (uint256 fee) {
        IBridge bridgeReth = IBridge(rethBridge);
        IBridge bridgeSteth = IBridge(stethBridge);

        // Calculate rETH market premium/discount (factor)
        uint256 unitRethTWAP = OracleLibrary.estimateTWAP(1 ether, 30 minutes, VAULT.RETH_WETH, VAULT.RETH, C.WETH);
        uint256 unitRethOracle = bridgeReth.getUnitDethValue();
        uint256 factorReth = unitRethTWAP.div(unitRethOracle);
        // Calculate stETH market premium/discount (factor)
        uint256 unitWstethTWAP = OracleLibrary.estimateTWAP(1 ether, 30 minutes, VAULT.WSTETH_WETH, VAULT.WSTETH, C.WETH);
        uint256 unitWstethOracle = bridgeSteth.getUnitDethValue();
        uint256 factorSteth = unitWstethTWAP.div(unitWstethOracle);
        if (factorReth > factorSteth) {
            // rETH market premium relative to stETH
            if (bridgePointer == VAULT.BRIDGE_RETH) {
                // Only charge fee if withdrawing rETH
                return factorReth.div(factorSteth) - 1 ether;
            }
        } else if (factorSteth > factorReth) {
            // stETH market premium relative to rETH
            if (bridgePointer == VAULT.BRIDGE_STETH) {
                // Only charge fee if withdrawing stETH
                return factorSteth.div(factorReth) - 1 ether;
            }
        } else {
            // Withdrawing less premium LST or premiums are equivalent
            return 0;
        }
    }

    // @dev Only relevant to NFT SR that is being transferred, used to deter workarounds to the bridge credit system
    function transferBridgeCredit(address asset, address from, address to, uint88 collateral) internal {
        AppStorage storage s = appStorage();

        STypes.Asset storage Asset = s.asset[asset];
        uint256 vault = Asset.vault;

        if (vault == VAULT.ONE) {
            STypes.VaultUser storage VaultUserFrom = s.vaultUser[vault][from];
            uint88 creditReth = VaultUserFrom.bridgeCreditReth;
            uint88 creditSteth = VaultUserFrom.bridgeCreditSteth;
            STypes.VaultUser storage VaultUserTo = s.vaultUser[vault][to];

            if (creditReth < C.ROUNDING_ZERO && creditSteth < C.ROUNDING_ZERO) {
                // No bridge credits
                return;
            }

            if (creditReth > C.ROUNDING_ZERO && creditSteth < C.ROUNDING_ZERO) {
                // Only creditReth
                if (creditReth > collateral) {
                    VaultUserFrom.bridgeCreditReth -= collateral;
                    VaultUserTo.bridgeCreditReth += collateral;
                } else {
                    VaultUserFrom.bridgeCreditReth = 0;
                    VaultUserTo.bridgeCreditReth += creditReth;
                }
            } else if (creditReth < C.ROUNDING_ZERO && creditSteth > C.ROUNDING_ZERO) {
                // Only creditSteth
                if (creditSteth > collateral) {
                    VaultUserFrom.bridgeCreditSteth -= collateral;
                    VaultUserTo.bridgeCreditSteth += collateral;
                } else {
                    VaultUserFrom.bridgeCreditSteth = 0;
                    VaultUserTo.bridgeCreditSteth += creditSteth;
                }
            } else {
                // Both creditReth and creditSteth
                uint88 creditTotal = creditReth + creditSteth;
                if (creditTotal > collateral) {
                    creditReth = creditReth.divU88(creditTotal).mulU88(collateral);
                    creditSteth = creditSteth.divU88(creditTotal).mulU88(collateral);
                    VaultUserFrom.bridgeCreditReth -= creditReth;
                    VaultUserFrom.bridgeCreditSteth -= creditSteth;
                } else {
                    VaultUserFrom.bridgeCreditReth = 0;
                    VaultUserFrom.bridgeCreditSteth = 0;
                }
                VaultUserTo.bridgeCreditReth += creditReth;
                VaultUserTo.bridgeCreditSteth += creditSteth;
            }
        }
    }

    // Update user account upon dETH withdrawal
    function removeDeth(uint256 vault, uint88 amount, uint88 fee) internal {
        AppStorage storage s = appStorage();
        s.vaultUser[vault][msg.sender].ethEscrowed -= (amount + fee);
        s.vault[vault].dethTotal -= amount;
    }
}
