// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {Modifiers} from "contracts/libraries/AppStorage.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {Events} from "contracts/libraries/Events.sol";
import {STypes, MTypes} from "contracts/libraries/DataTypes.sol";
import {LibDiamond} from "contracts/libraries/LibDiamond.sol";
import {LibOrders} from "contracts/libraries/LibOrders.sol";
import {LibOracle} from "contracts/libraries/LibOracle.sol";
import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";
import {LibAsset} from "contracts/libraries/LibAsset.sol";
import {C} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

contract OwnerFacet is Modifiers {
    using U256 for uint256;

    /**
     * @notice Initialize data for newly deployed market
     * @dev Single use only
     *
     * @param asset The market that will be impacted
     * @param a The market settings
     */

    /*
     * @param oracle The oracle for the asset
     * @param initialCR initialCR value of the new market
     * @param primaryLiquidationCR Liquidation ratio (PenaltyCR) value of the new market
     * @param secondaryLiquidationCR CRatio threshold for secondary liquidations
     * @param forcedBidPriceBuffer Liquidation limit value of the new market
     * @param penaltyCR Lowest threshold for shortRecord to not lose collateral during liquidation
     * @param tappFeePct Primary liquidation fee sent to TAPP out of shorter collateral
     * @param callerFeePct Primary liquidation fee sent to liquidator out of shorter collateral
     * @param minBidEth Minimum bid dust amount
     * @param minAskEth Minimum ask dust amount
     * @param minShortErc Minimum short record debt amount
     * @param recoveryCR CRatio threshold for recovery mode of the entire market
     * @param dittoTargetCR Cratio where shorter starts to receive less ditto reward per collateral
    */

    function createMarket(address asset, STypes.Asset memory a) external onlyDAO {
        STypes.Asset storage Asset = s.asset[asset];
        // can check non-zero ORDER_ID to prevent creating same asset
        if (Asset.orderIdCounter != 0) revert Errors.MarketAlreadyCreated();

        Asset.vault = a.vault;
        _setAssetOracle(asset, a.oracle);

        Asset.assetId = uint8(s.assets.length);
        s.assetMapping[Asset.assetId] = asset;
        s.assets.push(asset);

        STypes.Order memory headOrder;
        headOrder.prevId = C.HEAD;
        headOrder.id = C.HEAD;
        headOrder.nextId = C.TAIL;
        //@dev parts of OB depend on having sell's HEAD's price and creationTime = 0
        s.asks[asset][C.HEAD] = s.shorts[asset][C.HEAD] = headOrder;

        //@dev Using Bid's HEAD's order contain oracle data
        headOrder.creationTime = LibOrders.getOffsetTime();
        headOrder.ercAmount = uint80(LibOracle.getOraclePrice(asset));
        s.bids[asset][C.HEAD] = headOrder;

        //@dev hardcoded value
        Asset.orderIdCounter = C.STARTING_ID; // 100
        Asset.startingShortId = C.HEAD;

        //@dev comment with initial values
        _setInitialCR(asset, a.initialCR); // 170 -> 1.7 ether
        _setPrimaryLiquidationCR(asset, a.primaryLiquidationCR); // 150 -> 1.5 ether
        _setSecondaryLiquidationCR(asset, a.secondaryLiquidationCR); // 140 -> 1.4 ether
        _setForcedBidPriceBuffer(asset, a.forcedBidPriceBuffer); // 110 -> 1.1 ether
        _setPenaltyCR(asset, a.penaltyCR); // 110 -> 1.1 ether
        _setResetLiquidationTime(asset, a.resetLiquidationTime); // 12 -> 12 hours
        _setSecondLiquidationTime(asset, a.secondLiquidationTime); // 8 -> 8 hours
        _setFirstLiquidationTime(asset, a.firstLiquidationTime); // 6 -> 6 hours
        _setTappFeePct(asset, a.tappFeePct); // 25 -> .025 ether
        _setCallerFeePct(asset, a.callerFeePct); // 5 -> .005 ether
        _setMinBidEth(asset, a.minBidEth); // 10 -> 0.1 ether
        _setMinAskEth(asset, a.minAskEth); // 10 -> 0.1 ether
        _setMinShortErc(asset, a.minShortErc); // 2000 -> 2000 ether
        _setRecoveryCR(asset, a.recoveryCR); // 150 -> 1.5 ether
        _setDittoTargetCR(asset, a.dittoTargetCR); // 20 -> 2.0 ether

        // Create TAPP short
        LibShortRecord.createTappSR(asset);
        emit Events.CreateMarket(asset, Asset);
    }

    //@dev does not need read only re-entrancy
    function owner() external view returns (address) {
        return LibDiamond.contractOwner();
    }

    function admin() external view returns (address) {
        return s.admin;
    }

    //@dev does not need read only re-entrancy
    function ownerCandidate() external view returns (address) {
        return s.ownerCandidate;
    }

    function transferOwnership(address newOwner) external onlyDAO {
        s.ownerCandidate = newOwner;
        emit Events.NewOwnerCandidate(newOwner);
    }

    //@dev event emitted in setContractOwner
    function claimOwnership() external {
        if (s.ownerCandidate != msg.sender) revert Errors.NotOwnerCandidate();
        LibDiamond.setContractOwner(msg.sender);
        delete s.ownerCandidate;
    }

    //No need for claim step because DAO can also set admin
    function transferAdminship(address newAdmin) external onlyAdminOrDAO {
        s.admin = newAdmin;
        emit Events.NewAdmin(newAdmin);
    }

    function createVault(address deth, uint256 vault, MTypes.CreateVaultParams calldata params) external onlyDAO {
        if (s.dethVault[deth] != 0) revert Errors.VaultAlreadyCreated();
        s.dethVault[deth] = vault;
        _setTithe(vault, params.dethTithePercent);
        _setDittoMatchedRate(vault, params.dittoMatchedRate);
        _setDittoShorterRate(vault, params.dittoShorterRate);
        emit Events.CreateVault(deth, vault);
    }

    // Update eligibility requirements for yield accrual
    function setTithe(uint256 vault, uint16 dethTithePercent) external onlyAdminOrDAO {
        _setTithe(vault, dethTithePercent);
        emit Events.ChangeVaultSetting(vault);
    }

    function setDittoMatchedRate(uint256 vault, uint16 rewardRate) external onlyAdminOrDAO {
        _setDittoMatchedRate(vault, rewardRate);
        emit Events.ChangeVaultSetting(vault);
    }

    function setDittoShorterRate(uint256 vault, uint16 rewardRate) external onlyAdminOrDAO {
        _setDittoShorterRate(vault, rewardRate);
        emit Events.ChangeVaultSetting(vault);
    }

    // For Short Record collateral ratios
    // primaryLiquidationCR > secondaryLiquidationCR > penaltyCR
    // After initial market creation. Set CRs from smallest to largest to prevent triggering the require checks

    function setInitialCR(address asset, uint16 value) external onlyAdminOrDAO {
        _setInitialCR(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setPrimaryLiquidationCR(address asset, uint16 value) external onlyAdminOrDAO {
        require(value > s.asset[asset].secondaryLiquidationCR, "below secondary liquidation");
        _setPrimaryLiquidationCR(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setSecondaryLiquidationCR(address asset, uint16 value) external onlyAdminOrDAO {
        _setSecondaryLiquidationCR(asset, value);
        require(LibAsset.secondaryLiquidationCR(asset) > LibAsset.penaltyCR(asset), "below minimum CR");
        emit Events.ChangeMarketSetting(asset);
    }

    function setForcedBidPriceBuffer(address asset, uint8 value) external onlyAdminOrDAO {
        _setForcedBidPriceBuffer(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setPenaltyCR(address asset, uint8 value) external onlyAdminOrDAO {
        _setPenaltyCR(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    // Used for Primary Liquidation
    // resetLiquidationTime > secondLiquidationTime > firstLiquidationTime

    function setResetLiquidationTime(address asset, uint8 value) external onlyAdminOrDAO {
        _setResetLiquidationTime(asset, value);
        require(value >= s.asset[asset].secondLiquidationTime, "below secondLiquidationTime");
        emit Events.ChangeMarketSetting(asset);
    }

    function setSecondLiquidationTime(address asset, uint8 value) external onlyAdminOrDAO {
        _setSecondLiquidationTime(asset, value);
        require(value >= s.asset[asset].firstLiquidationTime, "below firstLiquidationTime");
        emit Events.ChangeMarketSetting(asset);
    }

    function setFirstLiquidationTime(address asset, uint8 value) external onlyAdminOrDAO {
        _setFirstLiquidationTime(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setTappFeePct(address asset, uint8 value) external onlyAdminOrDAO {
        _setTappFeePct(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setCallerFeePct(address asset, uint8 value) external onlyAdminOrDAO {
        _setCallerFeePct(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setMinBidEth(address asset, uint8 value) external onlyAdminOrDAO {
        _setMinBidEth(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setMinAskEth(address asset, uint8 value) external onlyAdminOrDAO {
        _setMinAskEth(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setMinShortErc(address asset, uint16 value) external onlyAdminOrDAO {
        _setMinShortErc(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setRecoveryCR(address asset, uint8 value) external onlyAdminOrDAO {
        _setRecoveryCR(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function setDittoTargetCR(address asset, uint8 value) external onlyAdminOrDAO {
        _setDittoTargetCR(asset, value);
        emit Events.ChangeMarketSetting(asset);
    }

    function createBridge(address bridge, uint256 vault, uint16 withdrawalFee) external onlyDAO {
        if (vault == 0) revert Errors.InvalidVault();
        STypes.Bridge storage Bridge = s.bridge[bridge];
        if (Bridge.vault != 0) revert Errors.BridgeAlreadyCreated();

        s.vaultBridges[vault].push(bridge);
        Bridge.vault = uint8(vault);
        _setWithdrawalFee(bridge, withdrawalFee);
        emit Events.CreateBridge(bridge, Bridge);
    }

    function setWithdrawalFee(address bridge, uint16 withdrawalFee) external onlyAdminOrDAO {
        _setWithdrawalFee(bridge, withdrawalFee);
        emit Events.ChangeBridgeSetting(bridge);
    }

    function _setAssetOracle(address asset, address oracle) private {
        if (asset == address(0) || oracle == address(0)) revert Errors.ParameterIsZero();
        s.asset[asset].oracle = oracle;
    }

    function _setTithe(uint256 vault, uint16 dethTithePercent) private {
        if (dethTithePercent > 33_33) revert Errors.InvalidTithe();
        //@dev dethTithePercent should never be changed outside of this function
        s.vault[vault].dethTithePercent = dethTithePercent;
    }

    function _setDittoMatchedRate(uint256 vault, uint16 rewardRate) private {
        require(rewardRate <= 100, "above 100");
        s.vault[vault].dittoMatchedRate = rewardRate;
    }

    function _setDittoShorterRate(uint256 vault, uint16 rewardRate) private {
        require(rewardRate <= 100, "above 100");
        s.vault[vault].dittoShorterRate = rewardRate;
    }

    function _setInitialCR(address asset, uint16 value) private {
        s.asset[asset].initialCR = value;
        require(LibAsset.initialCR(asset) < C.CRATIO_MAX, "above max CR");
    }

    function _setPrimaryLiquidationCR(address asset, uint16 value) private {
        require(value > 100, "below 1.0");
        require(value <= 500, "above 5.0");
        s.asset[asset].primaryLiquidationCR = value;
    }

    function _setSecondaryLiquidationCR(address asset, uint16 value) private {
        require(value > 100, "below 1.0");
        require(value <= 500, "above 5.0");
        require(value < s.asset[asset].primaryLiquidationCR, "above primary liquidation");
        s.asset[asset].secondaryLiquidationCR = value;
    }

    function _setForcedBidPriceBuffer(address asset, uint8 value) private {
        require(value >= 100, "below 1.0");
        require(value <= 200, "above 2.0");
        s.asset[asset].forcedBidPriceBuffer = value;
    }

    function _setPenaltyCR(address asset, uint8 value) private {
        require(value >= 100, "below 1.0");
        require(value <= 120, "above 1.2");
        s.asset[asset].penaltyCR = value;
        require(LibAsset.penaltyCR(asset) < LibAsset.secondaryLiquidationCR(asset), "above secondary liquidation");
    }

    // Used for Primary Liquidation
    // resetLiquidationTime > secondLiquidationTime > firstLiquidationTime

    function _setResetLiquidationTime(address asset, uint8 value) private {
        require(value >= 1, "below 1");
        require(value <= 48, "above 48");
        s.asset[asset].resetLiquidationTime = value;
    }

    function _setSecondLiquidationTime(address asset, uint8 value) private {
        require(value >= 1, "below 1");
        require(value <= s.asset[asset].resetLiquidationTime, "above resetLiquidationTime");
        s.asset[asset].secondLiquidationTime = value;
    }

    function _setFirstLiquidationTime(address asset, uint8 value) private {
        require(value >= 1, "below 1");
        require(value <= s.asset[asset].secondLiquidationTime, "above secondLiquidationTime");
        s.asset[asset].firstLiquidationTime = value;
    }

    function _setTappFeePct(address asset, uint8 value) private {
        require(value > 0, "Can't be zero");
        require(value <= 250, "above 250");
        s.asset[asset].tappFeePct = value;
    }

    function _setCallerFeePct(address asset, uint8 value) private {
        require(value > 0, "Can't be zero");
        require(value <= 250, "above 250");
        s.asset[asset].callerFeePct = value;
    }

    function _setMinBidEth(address asset, uint8 value) private {
        //no upperboard check because uint8 max - 255
        require(value > 0, "Can't be zero");
        s.asset[asset].minBidEth = value;
    }

    function _setMinAskEth(address asset, uint8 value) private {
        //no upperboard check because uint8 max - 255
        require(value > 0, "Can't be zero");
        s.asset[asset].minAskEth = value;
    }

    function _setMinShortErc(address asset, uint16 value) private {
        //no upperboard check because uint8 max - 65,535
        require(value > 0, "Can't be zero");
        s.asset[asset].minShortErc = value;
    }

    function _setWithdrawalFee(address bridge, uint16 withdrawalFee) private {
        require(withdrawalFee <= 200, "above 2.00%");
        s.bridge[bridge].withdrawalFee = withdrawalFee;
    }

    function _setRecoveryCR(address asset, uint8 value) private {
        require(value >= 100, "below 1.0");
        require(value <= 200, "above 2.0");
        s.asset[asset].recoveryCR = value;
    }

    function _setDittoTargetCR(address asset, uint8 value) private {
        require(value >= 10, "below 1.0");
        s.asset[asset].dittoTargetCR = value;
    }
}
