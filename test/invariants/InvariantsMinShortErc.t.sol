// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256, U80, U88} from "contracts/libraries/PRBMathHelper.sol";
import {STypes, SR} from "contracts/libraries/DataTypes.sol";

import {Test} from "forge-std/Test.sol";

import {IOBFixture} from "interfaces/IOBFixture.sol";
import {IDiamond} from "interfaces/IDiamond.sol";
import {VAULT} from "contracts/libraries/Constants.sol";
import {Handler} from "./Handler.sol";

import {console} from "contracts/libraries/console.sol";

/* solhint-disable */
/// @dev This contract deploys the target contract, the Handler, adds the Handler's actions to the invariant fuzzing
/// @dev targets, then defines invariants that should always hold throughout any invariant run.
contract InvariantsMinShortErc is Test {
    using U256 for uint256;
    using U80 for uint80;
    using U88 for uint88;

    Handler internal s_handler;
    IDiamond public diamond;
    uint256 public vault;
    address public asset;
    IOBFixture public s_ob;

    bytes4[] public selectors;

    // @dev Used for one test: statefulFuzz_allOrderIdsUnique
    mapping(uint16 id => uint256 cnt) orderIdMapping;

    function setUp() public virtual {
        IOBFixture ob = IOBFixture(deployCode("OBFixture.sol"));
        ob.setUp();
        address _diamond = ob.contracts("diamond");
        asset = ob.contracts("dusd");
        diamond = IDiamond(payable(_diamond));
        vault = VAULT.ONE;

        s_handler = new Handler(ob);

        // @dev duplicate the selector to increase the distribution of certain handler calls
        selectors = [
            // Bridge
            Handler.deposit.selector,
            Handler.deposit.selector,
            Handler.deposit.selector,
            Handler.depositEth.selector,
            Handler.depositEth.selector,
            Handler.depositEth.selector,
            Handler.withdraw.selector,
            // OrderBook
            Handler.createLimitBidMinShortErc.selector,
            Handler.createLimitBidMinShortErc.selector,
            Handler.createLimitBidMinShortErc.selector,
            Handler.createLimitShort.selector,
            Handler.createLimitShort.selector,
            Handler.createLimitShort.selector,
            Handler.createLimitShort.selector
        ];
        targetSelector(FuzzSelector({addr: address(s_handler), selectors: selectors}));
        targetContract(address(s_handler));

        s_ob = ob;
    }

    function statefulFuzz_shortRecordDebtUnderMinShortErc() public {
        address[] memory users = s_handler.getUsers();
        STypes.Order memory currentShort;
        uint256 counter = 0;

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            STypes.ShortRecord[] memory shortRecords = diamond.getShortRecords(asset, user);

            if (shortRecords.length > 0) {
                for (uint256 j = 0; j < shortRecords.length; j++) {
                    STypes.ShortRecord memory shortRecord = shortRecords[j];
                    // @dev check that all shorts under minShortErc is partialFill;
                    if (shortRecord.ercDebt < diamond.getMinShortErc(asset)) {
                        // vm.writeLine(
                        //     "./test/invariants/inputs",
                        //     string.concat(
                        //         "id: ",
                        //         vm.toString(shortRecord.id),
                        //         " | ",
                        //         "ercDebt: ",
                        //         vm.toString(shortRecord.ercDebt),
                        //         " | ",
                        //         "minShortErc: ",
                        //         vm.toString(diamond.getMinShortErc(asset))
                        //     )
                        // );

                        assertTrue(shortRecord.status == SR.PartialFill, "statefulFuzz_SRDebtUnderMin_1");

                        //get all the short orders
                        for (uint256 k = 0; k < diamond.getShorts(asset).length; k++) {
                            currentShort = diamond.getShorts(asset)[k];
                            // @dev check that all shorts under minShortErc has a corresponding shortOrder on ob;
                            if (currentShort.shortRecordId == shortRecord.id) {
                                counter++;
                                // vm.writeLine(
                                //     "./test/invariants/inputs",
                                //     string.concat(
                                //         "currentShort.shortRecordId == shortRecord.id",
                                //         vm.toString(shortRecord.id)
                                //     )
                                // );
                                assertEq(currentShort.shortRecordId, shortRecord.id, "statefulFuzz_SRDebtUnderMin_2");
                                break;
                            }
                        }

                        if (counter == 0) {
                            revert("Did not find corresponding shortOrder");
                        }
                        counter = 0;
                    }
                }
            }
        }
    }
}
