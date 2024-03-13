// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

library Errors {
    error AlreadyLiquidatable();
    error AlreadyMinted();
    error AssetIsFrozen();
    error AssetIsNotPermanentlyFrozen();
    error BadHintIdArray();
    error BadShortHint();
    error BelowRecoveryModeCR();
    error BridgeAlreadyCreated();
    error CannotCancelMoreThan1000Orders();
    error CannotDisputeWithRedeemerProposal();
    error CannotDisputeYourself();
    error CannotExitPartialFillSR();
    error CannotLeaveDustAmount();
    error CannotLiquidateSelf();
    error CannotMintAnymoreNFTs();
    error CannotMakeMoreThanMaxSR();
    error CannotSocializeDebt();
    error CannotTransferFlaggableShort();
    error CannotTransferFlaggedShort();
    error CanOnlyClaimYourShort();
    error CollateralHigherThanMax();
    error CRLowerThanMin();
    error DifferentVaults();
    error ExistingProposedRedemptions();
    error ExitShortPriceTooLow();
    error FirstShortDeleted();
    error FirstShortMustBeNFT();
    error FunctionNotFound(bytes4 _functionSelector);
    error InsufficientWalletBalance();
    error InsufficientCollateral();
    error InsufficientERCEscrowed();
    error InsufficientETHEscrowed();
    error InsufficientEthInLiquidityPool();
    error InsufficientNumberOfShorts();
    error InvalidAmount();
    error InvalidAsset();
    error InvalidBridge();
    error InvalidBuyback();
    error InvalidCR();
    error InvalidMsgValue();
    error InvalidNumberOfShortOrderIds();
    error InvalidPrice();
    error InvalidRedemption();
    error InvalidRedemptionDispute();
    error InvalidShortId();
    error InvalidShortOrder();
    error InvalidTithe();
    error InvalidTokenId();
    error InvalidTwapPrice();
    error InvalidTWAPSecondsAgo();
    error InvalidVault();
    error InvalidDeth();
    error IsNotNFT();
    error LiquidationIneligibleWindow();
    error SecondaryLiquidationNoValidShorts();
    error MarketAlreadyCreated();
    error MustUseExistingBridgeCredit();
    error NoDittoReward();
    error NoSells();
    error NoShares();
    error NotActiveOrder();
    error NotBridgeForBaseCollateral();
    error NotDiamond();
    error NotLastOrder();
    error NotMinted();
    error NotOwner();
    error NotOwnerOrAdmin();
    error NotOwnerCandidate();
    error NoValidShortRecordsForRedemption();
    error NoYield();
    error OrderIdCountTooLow();
    error OrderUnderMinimumSize();
    error OriginalShortRecordCancelled();
    error OriginalShortRecordRedeemed();
    error ParameterIsZero();
    error PostExitCRLtPreExitCR();
    error PriceOrAmountIs0();
    error ProposalInputsNotSorted();
    error ReceiverExceededShortRecordLimit();
    error RedemptionFeeTooHigh();
    error RedemptionUnderMinShortErc();
    error ReentrantCall();
    error ReentrantCallView();
    error ShortRecordAlreadyRedeemed();
    error ShortRecordIdOverflow();
    error ShortRecordIdsNotSorted();
    error SufficientCollateral();
    error TimeToDisputeHasElapsed();
    error TimeToDisputeHasNotElapsed();
    error TooManyHints();
    error TooManyProposals();
    error UnderMinimum();
    error UnderMinimumDeposit();
    error VaultAlreadyCreated();

    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);
    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);
    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);
    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);
    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);
    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);
}
