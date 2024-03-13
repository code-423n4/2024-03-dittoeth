// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U80, U88} from "contracts/libraries/PRBMathHelper.sol";
import {AddressSet, LibAddressSet} from "test/utils/AddressSet.sol";
import {C} from "contracts/libraries/Constants.sol";
import {STypes, SR, MTypes, O} from "contracts/libraries/DataTypes.sol";

import {IAsset} from "interfaces/IAsset.sol";
import {IOBFixture} from "interfaces/IOBFixture.sol";
import {IDiamond} from "interfaces/IDiamond.sol";
import {IMockAggregatorV3} from "interfaces/IMockAggregatorV3.sol";

import {VAULT} from "contracts/libraries/Constants.sol";
import {console} from "contracts/libraries/console.sol";
import {ConstantsTest} from "test/utils/ConstantsTest.sol";

/// @dev The handler is the set of valid actions that can be performed during an invariant test run.
/* solhint-disable no-console */
// solhint-disable-next-line max-states-count
contract Handler is ConstantsTest {
    using U256 for uint256;
    using U80 for uint80;
    using U88 for uint88;
    using LibAddressSet for AddressSet;

    IOBFixture public s_ob;
    IMockAggregatorV3 public ethAggregator;
    address public _ethAggregator;
    address public asset;
    address public deth;
    uint256 public vault;
    address public _diamond;
    IDiamond public diamond;
    address public _reth;
    IAsset public reth;
    address public _bridgeReth;
    address public _steth;
    IAsset public steth;
    address public _bridgeSteth;

    // GHOST VARIABLES
    address internal currentUser;
    AddressSet internal s_Users;
    AddressSet internal s_Shorters;
    AddressSet internal s_ErcHolders;
    AddressSet internal s_NFTOwners;
    uint16 public ghost_orderId;
    uint88 public ghost_ethEscrowed;
    uint104 public ghost_ercEscrowed;
    uint256 public ghost_oracleTime;
    uint256 public ghost_oraclePrice;
    uint80 public ghost_dethYieldRate;
    uint88 public ghost_dethCollateralReward;
    uint40 public ghost_tokenIdCounter;
    uint256 public ghost_protocolTime;
    // GHOST VARIABLES - Asserts
    uint256 public ghost_checkOracleTime;
    // GHOST VARIABLES - Counters
    uint256 public ghost_exitShort;
    uint256 public ghost_primaryLiquidation;
    uint256 public ghost_secondaryLiquidation;

    uint256 public ghost_exitShortSRGtZeroCounter;
    uint256 public ghost_exitShortComplete;
    uint256 public ghost_secondaryLiquidationSRGtZeroCounter;
    uint256 public ghost_secondaryLiquidationComplete;
    uint256 public ghost_primaryLiquidationSRGtZeroCounter;
    uint256 public ghost_primaryLiquidationComplete;

    uint256 public ghost_exitShortNoAsksCounter;
    uint256 public ghost_exitShortCancelledShortCounter;
    uint256 public ghost_secondaryLiquidationSameUserCounter;
    uint256 public ghost_secondaryLiquidationCancelledShortCounter;
    uint256 public ghost_secondaryLiquidationErcEscrowedShortCounter;
    uint256 public ghost_secondaryLiquidationWalletShortCounter;
    uint256 public ghost_primaryLiquidationSameUserCounter;
    uint256 public ghost_primaryLiquidationCancelledShortCounter;

    uint256 public ghost_denominator;
    uint256 public ghost_numerator;

    // OUTPUT VARS - used to print a summary of calls and reverts during certain actions
    // uint256 internal s_swapToCalls;
    // uint256 internal s_swapToFails;

    constructor(IOBFixture ob) {
        s_ob = ob;
        _diamond = ob.contracts("diamond");
        diamond = IDiamond(payable(_diamond));
        asset = ob.contracts("dusd");
        deth = ob.contracts("deth");
        _ethAggregator = ob.contracts("ethAggregator");
        ethAggregator = IMockAggregatorV3(_ethAggregator);
        _steth = ob.contracts("steth");
        steth = IAsset(_steth);
        _reth = ob.contracts("reth");
        reth = IAsset(_reth);
        _bridgeReth = ob.contracts("bridgeReth");
        _bridgeSteth = ob.contracts("bridgeSteth");
        vault = VAULT.ONE;
    }

    //MODIFIERS
    modifier advanceTime() {
        //@dev 12 seconds to replicate how often a block gets added on average
        skip_ghost(12 seconds);
        vm.roll(block.number + 1);
        // Issues with block.timestamp so have to track manually...
        _;
    }

    //@dev change price by +/- .5% randomly
    modifier advancePrice(uint8 addressSeed) {
        uint256 oracleTime = diamond.getOracleTimeT(asset);
        uint256 currentOraclePrice = diamond.getOraclePriceT(asset);
        uint256 newOraclePrice;
        if (addressSeed % 3 == 0 && block.timestamp < oracleTime + 2 hours) {
            // no change unless oracle price is stale
            newOraclePrice = currentOraclePrice;
        } else if (addressSeed % 2 == 0) {
            newOraclePrice = currentOraclePrice.mul(1.005 ether);
        } else {
            newOraclePrice = currentOraclePrice.mul(0.995 ether);
        }

        int256 newOraclePriceInv = int256(newOraclePrice.inv());
        //@dev Don't change saved oracle data, just chainlink!
        ethAggregator.setRoundData(
            92233720368547778907 wei,
            newOraclePriceInv / C.BASE_ORACLE_DECIMALS,
            block.timestamp,
            block.timestamp,
            92233720368547778907 wei
        );
        _;
    }

    modifier useExistingUser(uint8 userSeed) {
        currentUser = s_Users.rand(userSeed);
        _;
    }

    modifier useExistingShorter(uint8 userSeed) {
        currentUser = s_Shorters.rand(userSeed);
        _;
    }

    modifier useExistingErcHolder(uint8 userSeed) {
        currentUser = s_ErcHolders.rand(userSeed);
        _;
    }

    modifier useExistingNFTOwner(uint8 userSeed) {
        currentUser = s_NFTOwners.rand(userSeed);
        _;
    }

    // Using this modifier as a workaround bc original test was buggy
    // ghost_oracleTime is updated with latest state at beginning of every function
    // ghost_checkOracleTime is potentially updated at the end of every function
    modifier checkSingularAsserts() {
        _;
        if (ghost_oracleTime > diamond.getOracleTimeT(asset)) {
            ghost_checkOracleTime++;
        }
    }

    //HELPERS
    function skip_ghost(uint256 skipTime) internal {
        skip(skipTime);
        ghost_protocolTime += skipTime;
    }

    function _seedToAddress(uint8 addressSeed) internal pure returns (address) {
        return address(uint160(_bound(addressSeed, 2, type(uint8).max)));
    }

    function boundU16(uint16 x, uint256 min, uint256 max) internal pure returns (uint16) {
        return uint16(_bound(uint256(x), uint256(min), uint256(max)));
    }

    function boundU80(uint80 x, uint256 min, uint256 max) internal pure returns (uint80) {
        return uint80(_bound(uint256(x), uint256(min), uint256(max)));
    }

    function boundU88(uint88 x, uint256 min, uint256 max) internal pure returns (uint88) {
        return uint88(_bound(uint256(x), uint256(min), uint256(max)));
    }

    function boundU104(uint104 x, uint256 min, uint256 max) internal pure returns (uint104) {
        return uint104(_bound(uint256(x), uint256(min), uint256(max)));
    }

    function getUsers() public view returns (address[] memory) {
        return s_Users.addrs;
    }

    function getShorters() public view returns (address[] memory) {
        return s_Shorters.addrs;
    }

    function initialGhostVarSetUp(address _msgSender) public {
        ghost_orderId = diamond.getAssetNormalizedStruct(asset).orderId;
        ghost_ethEscrowed = diamond.getVaultUserStruct(vault, _msgSender).ethEscrowed;
        ghost_ercEscrowed = diamond.getAssetUserStruct(asset, _msgSender).ercEscrowed;
        ghost_oracleTime = diamond.getOracleTimeT(asset);
        ghost_dethYieldRate = diamond.getVaultStruct(vault).dethYieldRate;
        ghost_dethCollateralReward = diamond.getVaultStruct(vault).dethCollateralReward;
        ghost_tokenIdCounter = diamond.getTokenId();
    }

    function reduceUsers(uint256 acc, function(uint256,address) external returns (uint256) func) public returns (uint256) {
        return s_Users.reduce(acc, func);
    }

    function reduceShorters(uint256 acc, function(uint256,address) external returns (uint256) func) public returns (uint256) {
        return s_Shorters.reduce(acc, func);
    }

    function updateShorters() public {
        uint256 length = s_Users.length();
        for (uint256 i; i < length; ++i) {
            address addr = s_Users.addrs[i];
            STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, addr);
            bool isShorter = shortRecords.length > 0 && shortRecords[0].collateral > 0;

            if (isShorter && !s_Shorters.saved[addr]) {
                // Shorter should be in the shorters set
                s_Shorters.add(addr);
            } else if (
                // Shorter should not be in the shorters set
                !isShorter && s_Shorters.saved[addr]
            ) {
                s_Shorters.remove(addr);
            }
        }
    }

    function updateErcHolders() public {
        uint256 length = s_Users.length();
        for (uint256 i; i < length; ++i) {
            address addr = s_Users.addrs[i];
            uint104 ercEscrowed = diamond.getAssetUserStruct(asset, addr).ercEscrowed;
            bool ercHolder = ercEscrowed > 0;

            if (ercHolder && !s_ErcHolders.saved[addr]) {
                // Should be in the ErcHolders set
                s_ErcHolders.add(addr);
            } else if (
                // Should not be in the ErcHolders setS
                !ercHolder && s_ErcHolders.saved[addr]
            ) {
                s_ErcHolders.remove(addr);
            }
        }
    }

    //MAIN INVARIANT FUNCTIONS
    function cancelOrder(uint16 index, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
        checkSingularAsserts
    {
        initialGhostVarSetUp(currentUser);
        STypes.Order[] memory bids = diamond.getUserOrders(asset, currentUser, O.LimitBid);
        STypes.Order[] memory asks = diamond.getUserOrders(asset, currentUser, O.LimitAsk);
        STypes.Order[] memory shorts = diamond.getUserOrders(asset, currentUser, O.LimitShort);

        if (index % 3 == 0 && bids.length > 0) {
            index = boundU16(index, 0, uint16(bids.length - 1));
            console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
            console.log(string.concat("diamond.cancelBid(", vm.toString(asset), ",", vm.toString(bids[index].id), ");"));
            vm.prank(currentUser);
            diamond.cancelBid(asset, bids[index].id);
            ghost_oraclePrice = diamond.getOraclePriceT(asset);
        } else if (index % 3 == 1 && asks.length > 0) {
            index = boundU16(index, 0, uint16(asks.length - 1));
            console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
            console.log(string.concat("diamond.cancelAsk(", vm.toString(asset), ",", vm.toString(asks[index].id), ");"));
            vm.prank(currentUser);
            diamond.cancelAsk(asset, asks[index].id);
            ghost_oraclePrice = diamond.getOraclePriceT(asset);
        } else if (index % 3 == 2 && shorts.length > 0) {
            index = boundU16(index, 0, uint16(shorts.length - 1));
            console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
            console.log(string.concat("diamond.cancelShort(", vm.toString(asset), ",", vm.toString(shorts[index].id), ");"));
            vm.prank(currentUser);
            diamond.cancelShort(asset, shorts[index].id);
            ghost_oraclePrice = diamond.getOraclePriceT(asset);
        } else {
            console.log("cancelorder [skip]");
        }

        updateErcHolders();
    }

    function createLimitBid(uint80 price, uint88 amount, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
        checkSingularAsserts
    {
        // bound inputs
        price = boundU80(price, DEFAULT_PRICE / 2, DEFAULT_PRICE * 2);
        //@dev setting lower bound to 500 ether to allow some cases of under minShortErc from happening
        amount = boundU88(amount, 500 ether, DEFAULT_AMOUNT * 10);
        // amount = boundU88(amount, DEFAULT_AMOUNT, DEFAULT_AMOUNT * 10);

        initialGhostVarSetUp(currentUser);

        uint88 ethEscrowed = diamond.getVaultUserStruct(vault, currentUser).ethEscrowed;
        if (ethEscrowed < price.mulU88(amount)) {
            return;
        }

        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, price, O.LimitBid, 1);
        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = diamond.getShortIdAtOracle(asset);

        console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
        console.log(
            string.concat(
                "createBid(",
                vm.toString(asset),
                ",",
                vm.toString(price),
                ",",
                vm.toString(amount),
                ",",
                "C.LIMIT_ORDER",
                ",",
                "orderHintArray",
                ",",
                "shortHintArray",
                ");"
            )
        );
        vm.prank(currentUser);
        diamond.createBid(asset, price, amount, C.LIMIT_ORDER, orderHintArray, shortHintArray);
        updateShorters();
        updateErcHolders();
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }

    function createLimitAsk(uint80 price, uint88 amount, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
        checkSingularAsserts
    {
        // bound inputs
        price = boundU80(price, DEFAULT_PRICE / 2, DEFAULT_PRICE * 2);
        amount = boundU88(amount, DEFAULT_AMOUNT, DEFAULT_AMOUNT * 10);

        initialGhostVarSetUp(currentUser);

        uint104 ercEscrowed = diamond.getAssetUserStruct(asset, currentUser).ercEscrowed;
        if (ercEscrowed < amount) {
            return;
        }

        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, price, O.LimitAsk, 1);
        console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
        console.log(
            string.concat(
                "createAsk(",
                vm.toString(asset),
                ",",
                vm.toString(price),
                ",",
                vm.toString(amount),
                ",",
                "C.LIMIT_ORDER",
                ",",
                "orderHintArray",
                ");"
            )
        );
        vm.prank(currentUser);
        diamond.createAsk(asset, price, amount, C.LIMIT_ORDER, orderHintArray);
        updateErcHolders();
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }

    function createLimitShort(uint80 price, uint88 amount, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
        checkSingularAsserts
    {
        // bound inputs
        price = boundU80(price, DEFAULT_PRICE / 2, DEFAULT_PRICE * 2);
        amount = boundU88(amount, DEFAULT_AMOUNT, DEFAULT_AMOUNT * 10);

        uint88 ethEscrowed = diamond.getVaultUserStruct(vault, currentUser).ethEscrowed;

        if (ethEscrowed <= price.mulU88(amount).mulU88(diamond.getAssetNormalizedStruct(asset).initialCR)) {
            return;
        }

        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, price, O.LimitShort, 1);
        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = diamond.getShortIdAtOracle(asset);

        console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
        console.log(
            string.concat(
                "createLimitShort(",
                vm.toString(asset),
                ",",
                vm.toString(price),
                ",",
                vm.toString(amount),
                ",",
                "orderHintArray",
                ",",
                "shortHintArray",
                ",",
                vm.toString(diamond.getAssetStruct(asset).initialCR),
                ");"
            )
        );

        vm.startPrank(currentUser);
        diamond.createLimitShort(asset, price, amount, orderHintArray, shortHintArray, diamond.getAssetStruct(asset).initialCR);
        vm.stopPrank();
        updateShorters();
        updateErcHolders();
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }

    function exitShort(uint80 price, uint256 index, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingShorter(addressSeed)
        checkSingularAsserts
    {
        ghost_exitShort++;
        initialGhostVarSetUp(currentUser);
        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, currentUser);

        if (shortRecords.length == 0) return;

        //bound inputs
        index = bound(index, 1, shortRecords.length);
        //@dev sometimes the short collateral will not be enough to exit short bc price will be too high
        price = boundU80(price, diamond.getOraclePriceT(asset).div(1.1 ether), diamond.getOraclePriceT(asset).mul(1.1 ether));

        STypes.ShortRecord memory shortRecord = shortRecords[index - 1];
        ghost_exitShortSRGtZeroCounter++;
        if (shortRecord.status == SR.Closed) {
            ghost_exitShortCancelledShortCounter++;
            return;
        }

        if (diamond.getAsks(asset).length == 0) {
            ghost_exitShortNoAsksCounter++;
            return;
        }

        console.log(
            string.concat(
                "exitShort(",
                vm.toString(shortRecord.id),
                ",",
                vm.toString(shortRecord.ercDebt),
                ",",
                vm.toString(price),
                ",",
                vm.toString(currentUser),
                ");"
            )
        );
        s_ob.exitShort(shortRecord.id, shortRecord.ercDebt, uint80(price), currentUser);
        ghost_exitShortComplete++;
        updateShorters();
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }

    //@dev Do not include this in invariant files that check systemwide dethTotal or ercDebt. FundLimitOrders will break
    function mintNFT(uint80 price, uint88 amount, uint256 index, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingShorter(addressSeed)
        checkSingularAsserts
    {
        address msgSender = _seedToAddress(addressSeed);
        initialGhostVarSetUp(msgSender);

        //bound values - Make minimum the ETH price to ensure it is above oracle
        price = boundU80(price, DEFAULT_PRICE, DEFAULT_PRICE * 2);
        amount = boundU88(amount, DEFAULT_AMOUNT, DEFAULT_AMOUNT * 10);

        // keep oracle price fixed
        s_ob.setETHChainlinkOnly(4000 ether);

        //match short with bid
        s_ob.fundLimitBidOpt(price, amount, msgSender);
        s_ob.fundLimitShortOpt(price, amount, msgSender);

        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, msgSender);

        // bound inputs
        index = bound(index, 1, shortRecords.length);
        STypes.ShortRecord memory shortRecord = shortRecords[index - 1];
        if (shortRecord.tokenId != 0) return;
        vm.prank(msgSender);
        diamond.mintNFT(asset, shortRecord.id, 0);

        s_Users.add(msgSender);
        s_Shorters.add(msgSender);
        s_NFTOwners.add(msgSender);
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }

    function transferNFT(uint256 index, uint8 addressSeed)
        public
        advanceTime
        useExistingNFTOwner(addressSeed)
        checkSingularAsserts
    {
        // if (currentUser == address(0)) return;
        initialGhostVarSetUp(currentUser);
        address nftReceiver = _seedToAddress(addressSeed);

        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, currentUser);

        if (shortRecords.length == 0) return;

        // bound inputs
        index = bound(index, 1, shortRecords.length);
        STypes.ShortRecord memory shortRecord = shortRecords[index - 1];

        STypes.NFT memory nft = diamond.getNFT(shortRecord.tokenId);
        if (nft.owner != currentUser) return;

        vm.prank(currentUser);
        diamond.transferFrom(currentUser, nftReceiver, shortRecord.tokenId);
        s_Users.add(nftReceiver);
        s_NFTOwners.add(nftReceiver);
        updateShorters();
    }

    function secondaryLiquidation(uint88 amount, uint256 index, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
        useExistingShorter(addressSeed)
        checkSingularAsserts
    {
        ghost_secondaryLiquidation++;
        initialGhostVarSetUp(currentUser);
        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, currentUser);
        if (shortRecords.length == 0) return;
        // bound inputs
        index = bound(index, 1, shortRecords.length);
        STypes.ShortRecord memory shortRecord = shortRecords[index - 1];

        ghost_secondaryLiquidationSRGtZeroCounter++;
        // bound inputs
        amount = boundU88(amount, DEFAULT_AMOUNT, DEFAULT_AMOUNT * 10);

        address liquidator = currentUser;
        if (liquidator == currentUser) {
            ghost_secondaryLiquidationSameUserCounter++;
            return;
        }

        if (shortRecord.status == SR.Closed) {
            ghost_secondaryLiquidationCancelledShortCounter++;
            return;
        }

        //@dev reduce price to liquidation levels
        int256 preLiquidationPrice = int256(diamond.getOraclePriceT(asset).inv());
        s_ob.setETH(750 ether);
        console.log("setETH(750 ether);");

        //@dev randomly choose between erc vs wallet approach
        if (addressSeed % 2 == 0) {
            if (diamond.getAssetUserStruct(asset, liquidator).ercEscrowed < shortRecord.ercDebt) {
                s_ob.setETH(preLiquidationPrice);
                return;
            }

            console.log(
                string.concat(
                    "liquidateErcEscrowed(",
                    vm.toString(currentUser),
                    ",",
                    vm.toString(shortRecord.id),
                    ",",
                    vm.toString(shortRecord.ercDebt),
                    ",",
                    vm.toString(liquidator),
                    ");"
                )
            );

            s_ob.liquidateErcEscrowed(currentUser, shortRecord.id, shortRecord.ercDebt, liquidator);
            ghost_secondaryLiquidationErcEscrowedShortCounter++;
        } else {
            if (IAsset(asset).balanceOf(liquidator) >= shortRecord.ercDebt) {
                console.log(
                    string.concat(
                        "liquidateWallet(",
                        vm.toString(currentUser),
                        ",",
                        vm.toString(shortRecord.id),
                        ",",
                        vm.toString(shortRecord.ercDebt),
                        ",",
                        vm.toString(liquidator),
                        ");"
                    )
                );
                s_ob.liquidateWallet(currentUser, shortRecord.id, shortRecord.ercDebt, liquidator);

                ghost_secondaryLiquidationWalletShortCounter++;
            } else if (diamond.getAssetUserStruct(asset, liquidator).ercEscrowed >= shortRecord.ercDebt) {
                //withdraw
                console.log(string.concat("vm.prank(", vm.toString(liquidator), ");"));
                console.log(string.concat("diamond.withdrawAsset(asset,", vm.toString(shortRecord.ercDebt), ");"));

                console.log(
                    string.concat(
                        "liquidateWallet(",
                        vm.toString(currentUser),
                        ",",
                        vm.toString(shortRecord.id),
                        ",",
                        vm.toString(shortRecord.ercDebt),
                        ",",
                        vm.toString(liquidator),
                        ");"
                    )
                );
                vm.prank(liquidator);
                diamond.withdrawAsset(asset, shortRecord.ercDebt);

                s_ob.liquidateWallet(currentUser, shortRecord.id, shortRecord.ercDebt, liquidator);
                ghost_secondaryLiquidationWalletShortCounter++;
            } else {
                s_ob.setETH(preLiquidationPrice);
                return;
            }
        }

        //@dev reset price back to original levels
        s_ob.setETH(preLiquidationPrice);

        updateShorters();
        updateErcHolders();
        ghost_secondaryLiquidationComplete++;
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }

    function createLimitAskForLiquidation(uint80 price, uint88 amount, uint8 addressSeed)
        public
        useExistingErcHolder(addressSeed)
        checkSingularAsserts
    {
        uint88 ercEscrowed = uint88(diamond.getAssetUserStruct(asset, currentUser).ercEscrowed);
        if (ercEscrowed < amount) {
            amount = ercEscrowed;
        }

        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, price, O.LimitAsk, 1);
        console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
        console.log(
            string.concat(
                "createAsk(",
                vm.toString(asset),
                ",",
                vm.toString(price),
                ",",
                vm.toString(amount),
                ",",
                "C.LIMIT_ORDER",
                ",",
                "orderHintArray",
                ");"
            )
        );
        vm.prank(currentUser);
        diamond.createAsk(asset, price, amount, C.LIMIT_ORDER, orderHintArray);
        updateErcHolders();
    }

    function primaryLiquidation(uint256 index, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
        useExistingShorter(addressSeed)
        checkSingularAsserts
    {
        ghost_primaryLiquidation++;
        initialGhostVarSetUp(currentUser);
        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, currentUser);

        if (shortRecords.length == 0) return;

        // bound inputs
        index = bound(index, 1, shortRecords.length);
        STypes.ShortRecord memory shortRecord = shortRecords[index - 1];

        ghost_primaryLiquidationSRGtZeroCounter++;
        address liquidator = currentUser;
        if (liquidator == currentUser) {
            ghost_primaryLiquidationSameUserCounter++;
            return;
        }

        if (shortRecord.status == SR.Closed) {
            ghost_primaryLiquidationCancelledShortCounter++;
            return;
        }

        int256 preLiquidationPrice = int256(diamond.getOraclePriceT(asset).inv());

        //@dev create ask for liquidation
        console.log(
            string.concat(
                "fundLimitAskOpt(",
                vm.toString(uint80(diamond.getOraclePriceT(asset))),
                ",",
                vm.toString(shortRecord.ercDebt),
                ",",
                vm.toString(liquidator),
                ");"
            )
        );

        //@dev reduce price to liquidation levels
        console.log("setETH(1500 ether);");
        s_ob.setETH(1500 ether);

        // More likely for liquidation to go through
        createLimitAskForLiquidation(uint80(diamond.getOraclePriceT(asset)), shortRecord.ercDebt, addressSeed);

        //for some reason, the skip and liquidate are not working together
        skip_ghost(10 hours + 1 hours);
        //@dev reset time to prevent stale oracle data, use slightly different price so startingShortId gets updated
        s_ob.setETHChainlinkOnly(1499 ether);
        // Update starting short since ETH price artificially set
        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = diamond.getShortIdAtOracle(asset);
        diamond.updateStartingShortId(asset, shortHintArray);

        console.log(
            string.concat(
                "liquidate(", vm.toString(currentUser), ",", vm.toString(shortRecord.id), ",", vm.toString(liquidator), ");"
            )
        );

        uint256 fillEth = s_ob.liquidate(currentUser, shortRecord.id, liquidator);

        console.log(string.concat("fillEth = ", vm.toString(fillEth)));

        //@dev reset price back to original levels
        s_ob.setETH(preLiquidationPrice);
        updateShorters();
        updateErcHolders();
        ghost_primaryLiquidationComplete++;
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }

    function depositEth(uint8 addressSeed, uint88 amountIn) public checkSingularAsserts {
        // bound address seed
        address msgSender = _seedToAddress(addressSeed);
        initialGhostVarSetUp(msgSender);

        // bound inputs
        amountIn = boundU88(amountIn, C.MIN_DEPOSIT, 10000 ether);
        console.log(string.concat("give(", vm.toString(msgSender), ",", vm.toString(amountIn), ");"));
        give(msgSender, amountIn);

        address bridge;
        if (amountIn % 2 == 0) {
            bridge = _bridgeSteth;
        } else {
            bridge = _bridgeReth;
        }

        console.log(string.concat("vm.prank(", vm.toString(msgSender), ");"));
        console.log(
            string.concat(
                "diamond.depositEth{value:", vm.toString(amountIn), "}(", amountIn % 2 == 0 ? "_bridgeSteth" : "_bridgeReth", ");"
            )
        );

        vm.prank(msgSender);
        diamond.depositEth{value: amountIn}(bridge);
        s_Users.add(msgSender);

        console.log(
            string.concat(
                "// bridge=",
                vm.toString(diamond.getDethTotal(vault)),
                " dethTotal=",
                vm.toString(diamond.getVaultStruct(vault).dethTotal)
            )
        );
    }

    function deposit(uint8 addressSeed, uint88 amountIn) public checkSingularAsserts {
        address msgSender = _seedToAddress(addressSeed);
        initialGhostVarSetUp(msgSender);

        amountIn = boundU88(amountIn, C.MIN_DEPOSIT, 10000 ether);

        address bridge;
        vm.startPrank(msgSender);
        if (amountIn % 2 == 0) {
            bridge = _bridgeSteth;
            give(_steth, msgSender, amountIn);
            give(_steth, amountIn);
            steth.approve(_bridgeSteth, type(uint88).max);

            console.log(string.concat("give(_steth,", vm.toString(msgSender), ",", vm.toString(amountIn), ");"));
            console.log(string.concat("give(_steth,", vm.toString(amountIn), ");"));
            console.log(string.concat("vm.prank(", vm.toString(msgSender), ");"));
            console.log(string.concat("steth.approve(_bridgeSteth, type(uint88).max);"));
        } else {
            bridge = _bridgeReth;
            give(_reth, msgSender, amountIn);
            give(_reth, amountIn);
            reth.approve(_bridgeReth, type(uint88).max);

            console.log(string.concat("give(_reth,", vm.toString(msgSender), ",", vm.toString(amountIn), ");"));
            console.log(string.concat("give(_reth,", vm.toString(amountIn), ");"));
            console.log(string.concat("vm.prank(", vm.toString(msgSender), ");"));
            console.log(string.concat("reth.approve(_bridgeReth, type(uint88).max);"));
        }

        console.log(string.concat("vm.prank(", vm.toString(msgSender), ");"));
        console.log(
            string.concat("diamond.deposit(", amountIn % 2 == 0 ? "_bridgeSteth" : "_bridgeReth", ",", vm.toString(amountIn), ");")
        );

        diamond.deposit(bridge, amountIn);
        vm.stopPrank();
        s_Users.add(msgSender);

        console.log(
            string.concat(
                "// bridge=",
                vm.toString(diamond.getDethTotal(vault)),
                " dethTotal=",
                vm.toString(diamond.getVaultStruct(vault).dethTotal)
            )
        );
    }

    function withdraw(uint8 addressSeed, uint88 amountOut) public useExistingUser(addressSeed) checkSingularAsserts {
        initialGhostVarSetUp(currentUser);
        address bridge;

        uint88 escrowed = diamond.getVaultUserStruct(vault, currentUser).ethEscrowed;
        if (escrowed <= 1) {
            return;
        } else {
            amountOut = boundU88(amountOut, 1, escrowed);
        }

        if (steth.balanceOf(_bridgeSteth) >= amountOut) {
            bridge = _bridgeSteth;
        } else if (reth.balanceOf(_bridgeReth) >= amountOut) {
            bridge = _bridgeReth;
        } else {
            return;
        }

        console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
        console.log(
            string.concat(
                "diamond.withdraw(", amountOut % 2 == 0 ? "_bridgeSteth" : "_bridgeReth", ",", vm.toString(amountOut), ");"
            )
        );

        vm.prank(currentUser);
        diamond.withdraw(bridge, amountOut);

        console.log(
            string.concat(
                "// bridge=",
                vm.toString(diamond.getDethTotal(vault)),
                " dethTotal=",
                vm.toString(diamond.getVaultStruct(vault).dethTotal),
                " ethEscrowed=",
                vm.toString(escrowed)
            )
        );
    }

    function fakeYield(uint64 amountIn) public checkSingularAsserts {
        initialGhostVarSetUp(currentUser);

        amountIn = uint64(_bound(amountIn, 1, 1 ether));
        address bridge;
        if (amountIn % 2 == 0) {
            bridge = _bridgeSteth;
            give(_steth, _bridgeSteth, amountIn);
        } else {
            bridge = _bridgeReth;
            give(_reth, _bridgeReth, amountIn);
        }
        vm.prank(makeAddr("1"));
        diamond.updateYield(vault);

        console.log(
            string.concat(
                "// bridge=",
                vm.toString(diamond.getDethTotal(vault)),
                " dethTotal=",
                vm.toString(diamond.getVaultStruct(vault).dethTotal)
            )
        );
    }

    function distributeYield(uint8 addressSeed)
        public
        advancePrice(addressSeed)
        useExistingShorter(addressSeed)
        checkSingularAsserts
    {
        skip_ghost(C.YIELD_DELAY_SECONDS);
        initialGhostVarSetUp(currentUser);

        if (diamond.getYield(asset, currentUser) <= 1) return;

        address[] memory assets = new address[](1);
        assets[0] = asset;

        vm.prank(currentUser);
        diamond.distributeYield(assets);
    }

    function distributeYieldAll() public checkSingularAsserts {
        skip_ghost(C.YIELD_DELAY_SECONDS);
        initialGhostVarSetUp(currentUser); // Address doesn't matter here

        address[] memory assets = new address[](1);
        assets[0] = asset;

        uint256 length = s_Shorters.addrs.length;
        address currentShorter;
        for (uint256 i; i < length; ++i) {
            currentShorter = s_Shorters.addrs[i];
            if (diamond.getYield(asset, currentShorter) <= 1) skip;
            vm.prank(currentShorter);
            diamond.distributeYield(assets);
        }
    }

    function claimDittoMatchedReward(uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
        checkSingularAsserts
    {
        initialGhostVarSetUp(currentUser);

        if (diamond.getVaultUserStruct(vault, currentUser).dittoMatchedShares <= 1) {
            return;
        }

        vm.prank(currentUser);
        diamond.claimDittoMatchedReward(vault);

        // Ensure some later matches get ditto rewards for matching
        skip_ghost(C.MIN_DURATION);
    }

    function claimDittoMatchedRewardAll(uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
        checkSingularAsserts
    {
        initialGhostVarSetUp(currentUser); // Address doesn't matter here

        uint256 length = s_Users.addrs.length;
        address currentClaimer;
        for (uint256 i; i < length; ++i) {
            currentClaimer = s_Users.addrs[i];
            if (diamond.getVaultUserStruct(vault, currentClaimer).dittoMatchedShares > 1) {
                vm.prank(currentClaimer);
                diamond.claimDittoMatchedReward(vault);
            }
        }

        // Ensure some later matches get ditto rewards for matching
        skip_ghost(C.MIN_DURATION);
    }

    //VAULT Functions
    function depositAsset(uint8 addressSeed, uint104 amount)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
        checkSingularAsserts
    {
        initialGhostVarSetUp(currentUser);
        uint256 balance = IAsset(asset).balanceOf(currentUser);

        if (balance == 0) return;
        // bound inputs
        amount = boundU104(amount, balance, balance);
        vm.prank(currentUser);
        diamond.depositAsset(asset, amount);

        updateErcHolders();
    }

    function withdrawAsset(uint8 addressSeed, uint104 amount)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
        checkSingularAsserts
    {
        initialGhostVarSetUp(currentUser);
        uint104 ercEscrowed = diamond.getAssetUserStruct(asset, currentUser).ercEscrowed;
        if (ercEscrowed == 0) return;
        // bound inputs
        amount = boundU104(amount, ercEscrowed, ercEscrowed);
        vm.prank(currentUser);
        diamond.withdrawAsset(asset, amount);

        updateErcHolders();
    }

    function withdrawDittoReward(uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
        checkSingularAsserts
    {
        initialGhostVarSetUp(currentUser);
        uint80 dittoReward = diamond.getVaultUserStruct(vault, currentUser).dittoReward;
        if (dittoReward <= 1) return;
        // bound inputs
        vm.prank(currentUser);
        diamond.withdrawDittoReward(vault);
    }

    function withdrawDittoRewardAll() public advanceTime checkSingularAsserts {
        initialGhostVarSetUp(currentUser); // Address doesn't matter

        uint256 length = s_Users.addrs.length;
        address currentClaimer;
        for (uint256 i; i < length; ++i) {
            currentClaimer = s_Users.addrs[i];
            if (diamond.getVaultUserStruct(vault, currentUser).dittoReward > 1) {
                vm.prank(currentClaimer);
                diamond.withdrawDittoReward(vault);
            }
        }
    }

    // Shorts Stuff - re-organize page later
    function increaseCollateral(uint88 amount, uint256 index, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingShorter(addressSeed)
        checkSingularAsserts
    {
        initialGhostVarSetUp(currentUser);

        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, currentUser);

        console.log("shortRecords.length == 0");
        if (shortRecords.length == 0) return;
        // bound inputs
        amount = boundU88(amount, DEFAULT_PRICE / 10, DEFAULT_PRICE);
        index = bound(index, 1, shortRecords.length);
        STypes.ShortRecord memory shortRecord = shortRecords[index - 1];

        console.log(string.concat("diamond.increaseCollateral(asset,", vm.toString(shortRecord.id), ",", vm.toString(amount), ");"));
        vm.prank(currentUser);
        diamond.increaseCollateral(asset, shortRecord.id, amount);
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }

    function decreaseCollateral(uint88 amount, uint256 index, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingShorter(addressSeed)
        checkSingularAsserts
    {
        initialGhostVarSetUp(currentUser);

        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, currentUser);

        console.log("shortRecords.length == 0");
        if (shortRecords.length == 0) return;
        // bound inputs
        index = bound(index, 1, shortRecords.length);
        STypes.ShortRecord memory shortRecord = shortRecords[index - 1];
        //@dev bounding this to prevent reducing CR too low
        amount = boundU88(amount, shortRecord.collateral / 10, shortRecord.collateral / 6);

        console.log(string.concat("diamond.decreaseCollateral(asset,", vm.toString(shortRecord.id), ",", vm.toString(amount), ");"));
        vm.prank(currentUser);
        diamond.decreaseCollateral(asset, shortRecord.id, amount);
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }

    function combineShorts(uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingShorter(addressSeed)
        checkSingularAsserts
    {
        initialGhostVarSetUp(currentUser);

        STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, currentUser);

        console.log("shortRecords.length < 2");
        if (shortRecords.length < 2) return;

        uint8[] memory ids = new uint8[](shortRecords.length);
        uint16[] memory shortOrderIds = new uint16[](shortRecords.length);

        for (uint256 i = 0; i < shortRecords.length; i++) {
            ids[i] = shortRecords[i].id;
            uint16 shortOrderId = diamond.getShortOrderId(asset, currentUser, shortRecords[i].id);
            shortOrderIds[i] = shortOrderId;
        }

        vm.prank(currentUser);
        diamond.combineShorts(asset, ids, shortOrderIds);
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }

    function createLimitBidMinShortErc(uint80 price, uint88 amount, uint8 addressSeed)
        public
        advanceTime
        advancePrice(addressSeed)
        useExistingUser(addressSeed)
        checkSingularAsserts
    {
        // bound inputs
        price = boundU80(price, DEFAULT_PRICE / 2, DEFAULT_PRICE * 2);
        amount = boundU88(amount, 500 ether, diamond.getMinShortErc(asset));

        initialGhostVarSetUp(currentUser);

        uint88 ethEscrowed = diamond.getVaultUserStruct(vault, currentUser).ethEscrowed;
        if (ethEscrowed < price.mulU88(amount)) {
            return;
        }

        MTypes.OrderHint[] memory orderHintArray = diamond.getHintArray(asset, price, O.LimitBid, 1);
        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = diamond.getShortIdAtOracle(asset);

        console.log(string.concat("vm.prank(", vm.toString(currentUser), ");"));
        console.log(
            string.concat(
                "createBid(",
                vm.toString(asset),
                ",",
                vm.toString(price),
                ",",
                vm.toString(amount),
                ",",
                "C.LIMIT_ORDER",
                ",",
                "orderHintArray",
                ",",
                "shortHintArray",
                ");"
            )
        );
        vm.prank(currentUser);
        diamond.createBid(asset, price, amount, C.LIMIT_ORDER, orderHintArray, shortHintArray);
        updateShorters();
        updateErcHolders();
        ghost_oraclePrice = diamond.getOraclePriceT(asset);
    }
}
