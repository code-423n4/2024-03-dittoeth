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

    function getDethTotal(uint256 vault) external view nonReentrantView returns (uint256) {
        return vault.getDethTotal();
    }

    //@dev does not need read only re-entrancy
    function getBridges(uint256 vault) external view returns (address[] memory) {
        return s.vaultBridges[vault];
    }

    function deposit(address bridge, uint88 amount) external nonReentrant {
        if (amount < C.MIN_DEPOSIT) revert Errors.UnderMinimumDeposit();

        (uint256 vault, uint256 bridgePointer) = _getVault(bridge);
        // @dev amount after deposit might be less, if bridge takes a fee
        uint88 dethAmount = uint88(IBridge(bridge).deposit(msg.sender, amount)); // @dev(safe-cast)

        vault.addDeth(bridgePointer, dethAmount);
        maybeUpdateYield(vault, dethAmount);
        emit Events.Deposit(bridge, msg.sender, dethAmount);
    }

    function depositEth(address bridge) external payable nonReentrant {
        if (msg.value < C.MIN_DEPOSIT) revert Errors.UnderMinimumDeposit();

        (uint256 vault, uint256 bridgePointer) = _getVault(bridge);

        uint88 dethAmount = uint88(IBridge(bridge).depositEth{value: msg.value}()); // Assumes 1 ETH = 1 DETH
        vault.addDeth(bridgePointer, dethAmount);
        maybeUpdateYield(vault, dethAmount);
        emit Events.DepositEth(bridge, msg.sender, dethAmount);
    }

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

    function withdrawTapp(address bridge, uint88 dethAmount) external onlyDAO {
        if (dethAmount == 0) revert Errors.ParameterIsZero();

        (uint256 vault,) = _getVault(bridge);
        uint88 ethAmount = _ethConversion(vault, dethAmount);

        s.vaultUser[vault][address(this)].ethEscrowed -= dethAmount;
        s.vault[vault].dethTotal -= dethAmount;

        IBridge(bridge).withdraw(msg.sender, ethAmount);
        emit Events.WithdrawTapp(bridge, msg.sender, dethAmount);
    }

    function maybeUpdateYield(uint256 vault, uint88 amount) private {
        uint88 dethTotal = s.vault[vault].dethTotal;
        if (dethTotal > C.BRIDGE_YIELD_UPDATE_THRESHOLD && amount.div(dethTotal) > C.BRIDGE_YIELD_PERCENT_THRESHOLD) {
            // Update yield for "large" bridge deposits
            vault.updateYield();
        }
    }

    //@dev Checks for invalid bridge input
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
