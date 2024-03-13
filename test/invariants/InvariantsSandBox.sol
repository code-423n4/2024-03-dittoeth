// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";
import {VAULT} from "contracts/libraries/Constants.sol";

import {Test} from "forge-std/Test.sol";

import {IOBFixture} from "interfaces/IOBFixture.sol";
import {IDiamond} from "interfaces/IDiamond.sol";

import {Handler} from "./Handler.sol";

import {console} from "contracts/libraries/console.sol";

contract InvariantsSandbox is Test {
    using U256 for uint256;
    using U88 for uint88;
    using U80 for uint80;

    Handler internal s_handler;
    IDiamond public diamond;
    uint256 public vault;
    address public asset;
    address public deth;
    IOBFixture public s_ob;

    mapping(uint16 id => uint256 cnt) public orderIdMapping;

    function setUp() public {
        IOBFixture ob = IOBFixture(deployCode("OBFixture.sol"));
        ob.setUp();
        address _diamond = ob.contracts("diamond");
        asset = ob.contracts("dusd");
        deth = ob.contracts("deth");
        diamond = IDiamond(payable(_diamond));
        vault = VAULT.ONE;

        s_handler = new Handler(ob);

        s_ob = ob;
    }

    // function test_InvariantScenario() public {
    //     s_handler.createLimitBid(27367, 48540, 255);

    //     uint16 startingShortId = diamond.getAssetNormalizedStruct(asset).startingShortId;
    //     STypes.Order memory startingShort = diamond.getShortOrder(asset, startingShortId);
    //     if (startingShortId > C.HEAD) {
    //         assertGe(
    //             startingShort.price,
    //             s_handler.ghost_oraclePrice(),
    //             "statefulFuzz_startingShortPriceGteOraclePrice_1"
    //         );
    //     }
    // }
}
