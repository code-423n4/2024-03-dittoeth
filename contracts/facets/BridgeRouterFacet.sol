// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {IBridge} from "contracts/interfaces/IBridge.sol";

import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {LibBridge} from "contracts/libraries/LibBridge.sol";
import {LibBridgeRouter} from "contracts/libraries/LibBridgeRouter.sol";
import {LibVault} from "contracts/libraries/LibVault.sol";
import {C, VAULT} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract BridgeRouterFacet is Modifiers {
    using U256 for uint256;
    using U88 for uint88;
    using LibBridge for uint256;
    using LibBridge for address;
    using LibBridgeRouter for uint256;
    using LibVault for uint256;

    address private immutable rethBridge;
    address private immutable stethBridge;

    constructor(address _rethBridge, address _stethBridge) {
        rethBridge = _rethBridge;
        stethBridge = _stethBridge;
    }

    /**
     * @notice Returns the present value of all bridges within a given vault
     *
     * @param vault The vault being queried
     *
     */
    function getDethTotal(uint256 vault) external view nonReentrantView returns (uint256) {
        return vault.getDethTotal();
    }

    /**
     * @notice Returns an array of the bridge addresses of the vault
     * @dev does not need read only reentrancy
     *
     * @param vault The vault being queried
     *
     */
    function getBridges(uint256 vault) external view returns (address[] memory) {
        return s.vaultBridges[vault];
    }

    /**
     * @notice Deposit LST into the protocol
     * @dev User receives equivalent value in dETH, and withdrawal credit if applicable
     *
     * @param bridge The address of the bridge corresponding to the LST deposited
     * @param amount The quantity of LST to deposit
     *
     */
    function deposit(address bridge, uint88 amount) external nonReentrant {
        if (amount < C.MIN_DEPOSIT) revert Errors.UnderMinimumDeposit();

        (uint256 vault, uint256 bridgePointer) = _getVault(bridge);
        // @dev amount after deposit might be less, if bridge takes a fee
        uint88 dethAmount = uint88(IBridge(bridge).deposit(msg.sender, amount)); // @dev(safe-cast)

        vault.addDeth(bridgePointer, dethAmount);
        maybeUpdateYield(vault, dethAmount);
        emit Events.Deposit(bridge, msg.sender, dethAmount);
    }

    /**
     * @notice Deposit ETH into the protocol
     * @dev User receives equivalent value in dETH at a 1:1 ratio, and withdrawal credit if applicable
     *
     * @param bridge The address of the bridge corresponding to the LST deposited (via ETH exchange)
     *
     */
    function depositEth(address bridge) external payable nonReentrant {
        if (msg.value < C.MIN_DEPOSIT) revert Errors.UnderMinimumDeposit();

        (uint256 vault, uint256 bridgePointer) = _getVault(bridge);

        uint88 dethAmount = uint88(IBridge(bridge).depositEth{value: msg.value}()); // Assumes 1 ETH = 1 DETH
        vault.addDeth(bridgePointer, dethAmount);
        maybeUpdateYield(vault, dethAmount);
        emit Events.DepositEth(bridge, msg.sender, dethAmount);
    }

    /**
     * @notice Withdraw LST out of the protocol
     * @dev Withdrawal credit only applicable for vaults holding multiple unique LST
     *
     * @param bridge The address of the bridge corresponding to the LST being withdrawn
     * @param dethAmount The quantity of dETH to withdraw
     *
     */
    function withdraw(address bridge, uint88 dethAmount) external nonReentrant {
        if (dethAmount == 0) revert Errors.ParameterIsZero();

        (uint256 vault, uint256 bridgePointer) = _getVault(bridge);

        uint88 fee;
        if (vault == VAULT.ONE) {
            uint88 dethAssessable = vault.assessDeth(bridgePointer, dethAmount, rethBridge, stethBridge);
            if (dethAssessable > 0) {
                uint256 withdrawalFeePct = LibBridgeRouter.withdrawalFeePct(bridgePointer, rethBridge, stethBridge);
                if (withdrawalFeePct > 0) {
                    fee = dethAssessable.mulU88(withdrawalFeePct);
                    dethAmount -= fee;
                    s.vaultUser[vault][address(this)].ethEscrowed += fee;
                }
            }
        }

        uint88 ethAmount = _ethConversion(vault, dethAmount);
        vault.removeDeth(dethAmount, fee);
        IBridge(bridge).withdraw(msg.sender, ethAmount);
        emit Events.Withdraw(bridge, msg.sender, dethAmount, fee);
    }

    /**
     * @notice Withdraw LST out of the protocol
     * @dev Only callable by DAO, takes from TAPP balance
     *
     * @param bridge The address of the bridge corresponding to the LST being withdrawn
     * @param dethAmount The quantity of dETH to withdraw
     *
     */
    function withdrawTapp(address bridge, uint88 dethAmount) external onlyDAO {
        if (dethAmount == 0) revert Errors.ParameterIsZero();

        (uint256 vault,) = _getVault(bridge);
        uint88 ethAmount = _ethConversion(vault, dethAmount);

        s.vaultUser[vault][address(this)].ethEscrowed -= dethAmount;
        s.vault[vault].dethTotal -= dethAmount;

        IBridge(bridge).withdraw(msg.sender, ethAmount);
        emit Events.WithdrawTapp(bridge, msg.sender, dethAmount);
    }

    // Automatically updates the vault yield rate when bridge deposits are sufficiently large
    // @dev Deters attempts to take advantage of long delays between updates to the yield rate, by creating large temporary positions
    function maybeUpdateYield(uint256 vault, uint88 amount) private {
        uint88 dethTotal = s.vault[vault].dethTotal;
        if (dethTotal > C.BRIDGE_YIELD_UPDATE_THRESHOLD && amount.div(dethTotal) > C.BRIDGE_YIELD_PERCENT_THRESHOLD) {
            vault.updateYield();
        }
    }

    // Checks for invalid bridge input
    function _getVault(address bridge) private view returns (uint256 vault, uint256 bridgePointer) {
        if (bridge == rethBridge) {
            vault = VAULT.ONE;
        } else if (bridge == stethBridge) {
            vault = VAULT.ONE;
            bridgePointer = VAULT.BRIDGE_STETH;
        } else {
            vault = s.bridge[bridge].vault;
            if (vault == 0) revert Errors.InvalidBridge();
        }
    }

    // Accounting for situations when the vault (via bridges) experiences loss in value
    function _ethConversion(uint256 vault, uint88 amount) private view returns (uint88) {
        uint256 dethTotalNew = vault.getDethTotal();
        uint88 dethTotal = s.vault[vault].dethTotal;

        if (dethTotalNew >= dethTotal) {
            // when yield is positive 1 deth = 1 eth
            return amount;
        } else {
            // negative yield means 1 deth < 1 eth
            // @dev don't use mulU88 in rare case of overflow
            return amount.mul(dethTotalNew).divU88(dethTotal);
        }
    }
}
