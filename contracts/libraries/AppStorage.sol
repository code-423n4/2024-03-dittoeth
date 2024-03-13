// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {STypes, F, SR} from "contracts/libraries/DataTypes.sol";
import {LibDiamond} from "contracts/libraries/LibDiamond.sol";
import {Errors} from "contracts/libraries/Errors.sol";
import {C} from "contracts/libraries/Constants.sol";

// import {console} from "contracts/libraries/console.sol";

struct AppStorage {
    address admin;
    address ownerCandidate;
    address baseOracle;
    uint24 flaggerIdCounter; // UNUSED: flaggerIdCounter deprecated
    uint40 tokenIdCounter; //NFT - As of 2023, Ethereum had ~2B total tx. Uint40 max value is 1T, which is more than enough for NFTs
    uint8 reentrantStatus;
    mapping(address deth => uint256 vault) dethVault; // UNUSED: depositDeth/withdrawDeth removed
    // Bridge
    mapping(address bridge => STypes.Bridge) bridge;
    // Vault
    mapping(uint256 vault => STypes.Vault) vault;
    mapping(uint256 vault => address[]) vaultBridges;
    mapping(uint256 vault => mapping(address account => STypes.VaultUser)) vaultUser;
    // Assets
    mapping(address asset => STypes.Asset) asset;
    mapping(address asset => mapping(address account => STypes.AssetUser)) assetUser;
    // Assets - Orderbook
    mapping(address asset => mapping(uint16 id => STypes.Order)) bids;
    mapping(address asset => mapping(uint16 id => STypes.Order)) asks;
    mapping(address asset => mapping(uint16 id => STypes.Order)) shorts;
    mapping(address asset => mapping(address account => mapping(uint8 id => STypes.ShortRecord))) shortRecords;
    mapping(uint24 flaggerId => address flagger) flagMapping; // UNUSED: flagMapping deprecated
    // ERC721
    mapping(uint256 tokenId => STypes.NFT) nftMapping;
    mapping(uint256 tokenId => address) getApproved;
    mapping(address owner => mapping(address operator => bool)) isApprovedForAll;
    // ERC721 - Assets
    address[] assets;
    mapping(uint256 assetId => address) assetMapping;
    // ERC721 - METADATA STORAGE/LOGIC
    string name;
    string symbol;
}

function appStorage() pure returns (AppStorage storage s) {
    // solhint-disable-next-line no-inline-assembly
    assembly {
        s.slot := 0
    }
}

contract Modifiers {
    AppStorage internal s;

    modifier onlyDAO() {
        LibDiamond.enforceIsContractOwner();
        _;
    }

    modifier onlyAdminOrDAO() {
        if (msg.sender != LibDiamond.contractOwner() && msg.sender != s.admin) revert Errors.NotOwnerOrAdmin();
        _;
    }

    modifier onlyDiamond() {
        if (msg.sender != address(this)) revert Errors.NotDiamond();
        _;
    }

    modifier onlyValidAsset(address asset) {
        if (s.asset[asset].vault == 0) revert Errors.InvalidAsset();
        _;
    }

    modifier isNotFrozen(address asset) {
        if (s.asset[asset].frozen != F.Unfrozen) revert Errors.AssetIsFrozen();
        _;
    }

    modifier isPermanentlyFrozen(address asset) {
        if (s.asset[asset].frozen != F.Permanent) revert Errors.AssetIsNotPermanentlyFrozen();
        _;
    }

    function _onlyValidShortRecord(address asset, address shorter, uint8 id)
        internal
        view
        returns (STypes.ShortRecord storage shortRecord)
    {
        shortRecord = s.shortRecords[asset][shorter][id];
        if (shortRecord.status == SR.Closed || shortRecord.ercDebt == 0) revert Errors.InvalidShortId();
    }

    modifier onlyValidShortRecord(address asset, address shorter, uint8 id) {
        _onlyValidShortRecord(asset, shorter, id);
        _;
    }

    modifier nonReentrant() {
        if (s.reentrantStatus == C.ENTERED) revert Errors.ReentrantCall();
        s.reentrantStatus = C.ENTERED;
        _;
        s.reentrantStatus = C.NOT_ENTERED;
    }

    modifier nonReentrantView() {
        if (s.reentrantStatus == C.ENTERED) revert Errors.ReentrantCallView();
        _;
    }
}
