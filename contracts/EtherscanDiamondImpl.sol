// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

/**
 * https://etherscan.diamonds.dev/
 * This is a generated dummy diamond implementation for compatibility with
 * etherscan. For full contract implementation, check out the diamond on louper:
 * https://louper.dev/diamond/0xd177000be70ea4efc23987acd1a79eaba8b758f1?network=mainnet
 */
import {Events} from "contracts/libraries/Events.sol";
import {O, STypes, MTypes} from "contracts/libraries/DataTypes.sol";

//Real implementations can be found in facet address commented below
contract EtherscanDiamondImpl {
    enum FacetCutAction {
        Add,
        Replace,
        Remove
    }

    struct FacetCut {
        address facetAddress;
        uint8 action;
        bytes4[] functionSelectors;
    }

    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    struct OrderHint {
        uint16 hintId;
        uint256 creationTime;
    }

    struct BatchLiquidation {
        address shorter;
        uint8 shortId;
    }

    struct ShortRecord {
        uint88 collateral;
        uint88 ercDebt;
        uint80 dethYieldRate;
        uint8 status;
        uint8 prevId;
        uint8 id;
        uint8 nextId;
        uint64 ercDebtRate;
        uint32 updatedAt;
        uint32 flaggedAt;
        uint24 flaggerId;
        uint40 tokenId;
    }

    struct Order {
        uint88 ercAmount;
        uint80 price;
        uint16 prevId;
        uint16 id;
        uint16 nextId;
        uint8 orderType;
        uint32 creationTime;
        address addr;
        uint8 prevOrderType;
        uint16 initialCR;
        uint8 shortRecordId;
        uint64 filler;
    }

    struct AssetUser {
        uint104 ercEscrowed;
        uint24 g_flaggerId;
        uint32 g_flaggedAt;
        uint8 shortRecordIdCounter;
        uint96 filler;
    }

    struct Bridge {
        uint8 vault;
        uint16 withdrawalFee;
        uint8 unstakeFee;
    }

    struct Vault {
        uint88 dethCollateral;
        uint88 dethTotal;
        uint80 dethYieldRate;
        uint88 dethCollateralReward;
        uint16 dethTithePercent;
        uint16 dittoShorterRate;
        uint128 filler2;
        uint128 dittoMatchedShares;
        uint96 dittoMatchedReward;
        uint16 dittoMatchedRate;
        uint16 dittoMatchedTime;
    }

    struct VaultUser {
        uint88 ethEscrowed;
        uint88 dittoMatchedShares;
        uint80 dittoReward;
    }

    //normally events are not needed for etherscan compatibility, but having events compiled into the etherscan impl ABI is useful for other tools such as substreams that grab events via etherscan api
    event DiamondCut(FacetCut[] _diamondCut, address _init, bytes _calldata);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event CreateBridge(address indexed bridge, Bridge bridgeStruct);
    event LiquidateSecondary(address indexed asset, BatchLiquidation[] batches, address indexed caller, bool isWallet);

    // DiamondCutFacet - 0xd40f94e5fD70835AC6FC0f0eaf00AEb20767A4E8
    function diamondCut(FacetCut[] memory _diamondCut, address _init, bytes memory _calldata) external {
        emit DiamondCut(_diamondCut, _init, _calldata);
    }

    //DiamondLoupeFacet - 0xf9379C53c2c5dC86FB7C9a744966b20e7c0AaFfA
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_) {}

    function facetAddresses() external view returns (address[] memory facetAddresses_) {}

    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory _facetFunctionSelectors) {}

    function facets() external view returns (Facet[] memory facets_) {}

    //ShortRecordFacet - 0xA13b6875971dA0D930Fd3fD93D44c1bE0fF44626
    function combineShorts(address asset, uint8[] memory ids) external {
        emit Events.CombineShorts(asset, msg.sender, ids);
    }

    function decreaseCollateral(address asset, uint8 id, uint88 amount) external {
        emit Events.DecreaseCollateral(asset, msg.sender, id, amount);
    }

    function increaseCollateral(address asset, uint8 id, uint88 amount) external {
        emit Events.IncreaseCollateral(asset, msg.sender, id, amount);
    }

    //VaultFacet - 0xFf73827eaA3A11255c19AdbA10b8f906bc54FA32
    function depositAsset(address asset, uint104 amount) external {}

    function withdrawAsset(address asset, uint104 amount) external {}

    //ERC721Facet - 0xdE661826fAC9d3034F6166E46c70dDd92C73f34c
    function approve(address to, uint256 tokenId) external {
        emit Events.Approval(msg.sender, to, tokenId);
    }

    function balanceOf(address _owner) external view returns (uint256 balance) {}

    function getApproved(uint256 tokenId) external view returns (address operator) {}

    function isApprovedForAll(address _owner, address operator) external view returns (bool) {}

    function mintNFT(address asset, uint8 shortRecordId) external {}

    function ownerOf(uint256 tokenId) external view returns (address) {}

    function safeTransferFrom(address from, address to, uint256 tokenId) external {}

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) external {}

    function setApprovalForAll(address operator, bool approved) external {
        emit Events.ApprovalForAll(msg.sender, operator, approved);
    }

    function supportsInterface(bytes4 _interfaceId) external view returns (bool) {}

    function tokenURI(uint256 id) external view returns (string memory) {}

    function transferFrom(address from, address to, uint256 tokenId) external {
        emit Events.Transfer(from, to, tokenId);
    }

    //BridgeRouterFacet - 0xA127DD7D51E6B5fcbAd3073BB370a05D6C2698A2
    function deposit(address bridge, uint88 amount) external {
        emit Events.Deposit(bridge, msg.sender, amount);
    }

    function depositEth(address bridge) external payable {
        emit Events.DepositEth(bridge, msg.sender, msg.value);
    }

    function getBridges(uint256 vault) external view returns (address[] memory) {}

    function getDethTotal(uint256 vault) external view returns (uint256) {}

    function withdraw(address bridge, uint88 dethAmount) external {
        emit Events.Withdraw(bridge, msg.sender, dethAmount, 0);
    }

    function withdrawTapp(address bridge, uint88 dethAmount) external {
        emit Events.WithdrawTapp(bridge, msg.sender, dethAmount);
    }

    //BidOrdersFacet - 0x5f406F400425704B4B09afD9bb02c4bf9633ab8B
    function createBid(
        address asset,
        uint80 price,
        uint88 ercAmount,
        bool isMarketOrder,
        OrderHint[] memory orderHintArray,
        uint16[] memory shortHintArray
    ) external returns (uint88 ethFilled, uint88 ercAmountLeft) {
        price;
        ercAmount;
        isMarketOrder;
        orderHintArray;
        shortHintArray;
        ethFilled;
        ercAmountLeft;
        emit Events.MatchOrder(asset, msg.sender, O.LimitBid, 0, 0, 0);
    }

    function createForcedBid(address sender, address asset, uint80 price, uint88 ercAmount, uint16[] memory shortHintArray)
        external
        pure
        returns (uint88 ethFilled, uint88 ercAmountLeft)
    {
        sender;
        asset;
        price;
        ercAmount;
        shortHintArray;
        ethFilled;
        ercAmountLeft;
    }

    //AskOrdersFacet - 0x9CB746De13a52d9418104F669a1CaE767B08D556
    function _cancelAsk(address asset, uint16 id) external {}

    function _cancelShort(address asset, uint16 id) external {}

    function createAsk(address asset, uint80 price, uint88 ercAmount, bool isMarketOrder, OrderHint[] memory orderHintArray)
        external
    {
        price;
        ercAmount;
        isMarketOrder;
        orderHintArray;
        emit Events.CreateOrder(asset, msg.sender, O.LimitAsk, 0, ercAmount);
    }

    //ShortOrdersFacet - 0x01b3A877C100A077124DD21e71969E1b89f2b489
    function createLimitShort(
        address asset,
        uint80 price,
        uint88 ercAmount,
        OrderHint[] memory orderHintArray,
        uint16[] memory shortHintArray,
        uint16 initialCR
    ) external {
        price;
        ercAmount;
        orderHintArray;
        shortHintArray;
        initialCR;
        emit Events.CreateShortRecord(asset, msg.sender, 0);
    }

    //ExitShortFacet - 0x19cC8BAbDBEa5d8FeF76286DBb807958b6918eBE
    function exitShort(address asset, uint8 id, uint88 buyBackAmount, uint80 price, uint16[] memory shortHintArray) external {
        price;
        shortHintArray;
        emit Events.ExitShort(asset, msg.sender, id, buyBackAmount);
    }

    function exitShortErcEscrowed(address asset, uint8 id, uint88 buyBackAmount) external {
        emit Events.ExitShortErcEscrowed(asset, msg.sender, id, buyBackAmount);
    }

    function exitShortWallet(address asset, uint8 id, uint88 buyBackAmount) external {
        emit Events.ExitShortWallet(asset, msg.sender, id, buyBackAmount);
    }

    //PrimaryLiquidationFacet - 0x75Cdd1046e54a3aadB60c546bC9c74154937d88a
    function flagShort(address asset, address shorter, uint8 id, uint16 flaggerHint) external {}

    function liquidate(address asset, address shorter, uint8 id, uint16[] memory shortHintArray)
        external
        returns (uint88 gasFee, uint88 ethFilled)
    {
        shortHintArray;
        gasFee;
        ethFilled;
        emit Events.Liquidate(asset, shorter, id, msg.sender, 0);
    }

    //SecondaryLiquidationFacet - 0xFde724FDC1A34C205972F9f5aAe390E5fc1d384c
    function liquidateSecondary(address asset, BatchLiquidation[] memory batches, uint88 liquidateAmount, bool isWallet) external {
        liquidateAmount;
        emit LiquidateSecondary(asset, batches, msg.sender, isWallet);
    }

    //OwnerFacet - 0xCc7C8Eb5aDdEc694fC2EB29ae6c762D9ebCC9deb
    function admin() external view returns (address) {}

    function claimOwnership() external {}

    function createBridge(address bridge, uint256 vault, uint16 withdrawalFee, uint8 unstakeFee) external {
        emit CreateBridge(bridge, Bridge({vault: uint8(vault), withdrawalFee: withdrawalFee, unstakeFee: unstakeFee}));
    }

    function createMarket(address asset, STypes.Asset memory a) external {
        emit Events.CreateMarket(asset, a);
    }

    function createVault(address deth, uint256 vault, MTypes.CreateVaultParams memory params) external {
        params;
        emit Events.CreateVault(deth, vault);
    }

    function owner() external view returns (address) {}

    function ownerCandidate() external view returns (address) {}

    function setCallerFeePct(address asset, uint8 value) external {}

    function setDittoMatchedRate(uint256 vault, uint16 rewardRate) external {}

    function setDittoShorterRate(uint256 vault, uint16 rewardRate) external {}

    function setFirstLiquidationTime(address asset, uint8 value) external {}

    function setForcedBidPriceBuffer(address asset, uint8 value) external {}

    function setInitialCR(address asset, uint16 value) external {
        value;
        emit Events.ChangeMarketSetting(asset);
    }

    function setMinAskEth(address asset, uint8 value) external {}

    function setMinBidEth(address asset, uint8 value) external {}

    function setMinShortErc(address asset, uint16 value) external {}

    function setMinimumCR(address asset, uint8 value) external {}

    function setPrimaryLiquidationCR(address asset, uint16 value) external {}

    function setResetLiquidationTime(address asset, uint8 value) external {}

    function setSecondLiquidationTime(address asset, uint8 value) external {}

    function setSecondaryLiquidationCR(address asset, uint16 value) external {}

    function setTappFeePct(address asset, uint8 value) external {}

    function setTithe(uint256 vault, uint16 dethTithePercent) external {
        dethTithePercent;
        emit Events.ChangeVaultSetting(vault);
    }

    function setWithdrawalFee(address bridge, uint16 withdrawalFee) external {
        withdrawalFee;
        emit Events.ChangeBridgeSetting(bridge);
    }

    function transferAdminship(address newAdmin) external {
        emit Events.NewAdmin(newAdmin);
    }

    function transferOwnership(address newOwner) external {
        emit Events.NewOwnerCandidate(newOwner);
    }

    //YieldFacet - 0xf1ab188256Ad8001E0351a4FBEa32BB9E775F654
    function claimDittoMatchedReward(uint256 vault) external {
        emit Events.ClaimDittoMatchedReward(vault, msg.sender);
    }

    function distributeYield(address[] memory assets) external {
        assets;
        emit Events.DistributeYield(1, msg.sender, 0, 0);
    }

    function updateYield(uint256 vault) external {
        emit Events.UpdateYield(vault);
    }

    function withdrawDittoReward(uint256 vault) external {}

    //ViewFacet - 0x015992589c3FeCcD440e41761076E8b6Bb4a28ab
    function getAskHintId(address asset, uint256 price) external view returns (uint16 hintId) {}

    function getAsks(address asset) external view returns (Order[] memory) {}

    function getAssetBalance(address asset, address user) external view returns (uint256) {}

    function getAssetCollateralRatio(address asset) external view returns (uint256 cRatio) {}

    function getAssetStruct(address asset) external view returns (STypes.Asset memory) {}

    function getAssetUserStruct(address asset, address user) external view returns (AssetUser memory) {}

    function getBidHintId(address asset, uint256 price) external view returns (uint16 hintId) {}

    function getBids(address asset) external view returns (Order[] memory) {}

    function getBridgeStruct(address bridge) external view returns (Bridge memory) {}

    function getBridgeVault(address bridge) external view returns (uint256) {}

    function getCollateralRatio(address asset, ShortRecord memory short) external view returns (uint256 cRatio) {}

    function getCollateralRatioSpotPrice(address asset, ShortRecord memory short) external view returns (uint256 cRatio) {}

    function getDethBalance(uint256 vault, address user) external view returns (uint256) {}

    function getDethYieldRate(uint256 vault) external view returns (uint256) {}

    function getDittoMatchedReward(uint256 vault, address user) external view returns (uint256) {}

    function getDittoReward(uint256 vault, address user) external view returns (uint256) {}

    function getFlaggerHint() external view returns (uint24 flaggerId) {}

    function getFlaggerId(address asset, address user) external view returns (uint24 flaggerId) {}

    function getHintArray(address asset, uint256 price, uint8 orderType, uint256 numHints)
        external
        view
        returns (OrderHint[] memory orderHintArray)
    {}

    function getOffsetTime() external view returns (uint256) {}

    function getOracleAssetPrice(address asset) external view returns (uint256) {}

    function getProtocolAssetPrice(address asset) external view returns (uint256) {}

    function getProtocolAssetTime(address asset) external view returns (uint256) {}

    function getShortHintId(address asset, uint256 price) external view returns (uint16) {}

    function getShortIdAtOracle(address asset) external view returns (uint16 shortHintId) {}

    function getShortRecord(address asset, address shorter, uint8 id) external view returns (ShortRecord memory shortRecord) {}

    function getShortRecordCount(address asset, address shorter) external view returns (uint256 shortRecordCount) {}

    function getShortRecords(address asset, address shorter) external view returns (ShortRecord[] memory shorts) {}

    function getShorts(address asset) external view returns (Order[] memory) {}

    function getTithe(uint256 vault) external view returns (uint256) {}

    function getUndistributedYield(uint256 vault) external view returns (uint256) {}

    function getVault(address asset) external view returns (uint256) {}

    function getVaultStruct(uint256 vault) external view returns (Vault memory) {}

    function getVaultUserStruct(uint256 vault, address user) external view returns (VaultUser memory) {}

    function getYield(address asset, address user) external view returns (uint256 shorterYield) {}

    //OrdersFacet - 0xFccf894D0847E6e346d319aa2EF357309EC79012
    function cancelAsk(address asset, uint16 id) external {
        emit Events.CancelOrder(asset, id, O.LimitAsk);
    }

    function cancelBid(address asset, uint16 id) external {}

    function cancelOrderFarFromOracle(address asset, uint8 orderType, uint16 lastOrderId, uint16 numOrdersToCancel) external {}

    function cancelShort(address asset, uint16 id) external {
        emit Events.DeleteShortRecord(asset, msg.sender, id);
    }

    //MarketShutdownFacet - 0xf7501aedAcE3F88dc5B4c3d6C7b0B673f45Bf8F0
    function redeemErc(address asset, uint88 amtWallet, uint88 amtEscrow) external {
        emit Events.RedeemErc(asset, msg.sender, amtWallet, amtEscrow);
    }

    function shutdownMarket(address asset) external {
        emit Events.ShutdownMarket(asset);
    }

    //TWAPFacet - 0x260D6d7a4eca2f387e36D71BdF5f168F287c9674
    function estimateWETHInUSDC(uint128 amountIn, uint32 secondsAgo) external view returns (uint256 amountOut) {}
}
