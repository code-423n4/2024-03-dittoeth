// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {U256} from "contracts/libraries/PRBMathHelper.sol";

import {IAsset} from "interfaces/IAsset.sol";
import {IOBFixture} from "interfaces/IOBFixture.sol";
import {IDiamond} from "interfaces/IDiamond.sol";
import {ITestFacet} from "interfaces/ITestFacet.sol";

import {STypes, MTypes, F, SR} from "contracts/libraries/DataTypes.sol";
import {C} from "contracts/libraries/Constants.sol";
import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

import {ConstantsTest} from "test/utils/ConstantsTest.sol";
import {console} from "contracts/libraries/console.sol";

//DO NOT REMOVE. WIll BREAK CI
import {ImmutableCreate2Factory} from "deploy/ImmutableCreate2Factory.sol";

function slice(string memory s, uint256 start, uint256 end) pure returns (string memory) {
    bytes memory s_bytes = bytes(s);
    require(start <= end && end <= s_bytes.length, "invalid");

    bytes memory sliced = new bytes(end - start);
    for (uint256 i = start; i < end; i++) {
        sliced[i - start] = s_bytes[i];
    }
    return string(sliced);
}

function eq(string memory s1, string memory s2) pure returns (bool) {
    return keccak256(bytes(s1)) == keccak256(bytes(s2));
}

contract Gas is ConstantsTest {
    using U256 for uint256;
    using stdJson for string;

    string private constant SNAPSHOT_DIRECTORY = "./.forge-snapshots/";
    string private constant JSON_PATH = "./.gas.json";
    bool private overwrite = false;
    string private checkpointLabel;
    uint256 private checkpointGasLeft = 12;

    constructor() {
        string[] memory cmd = new string[](3);
        cmd[0] = "mkdir";
        cmd[1] = "-p";
        cmd[2] = SNAPSHOT_DIRECTORY;
        vm.ffi(cmd);

        try vm.envBool("OVERWRITE") returns (bool _check) {
            overwrite = _check;
        } catch {}
    }

    function startMeasuringGas(string memory label) internal virtual {
        checkpointLabel = label;
        checkpointGasLeft = gasleft(); // 5000 gas to set storage first time, set to make first call consistent
        checkpointGasLeft = gasleft(); // 100
    }

    function stringToUint(string memory s) private pure returns (uint256 result) {
        bytes memory b = bytes(s);
        uint256 i;
        result = 0;
        for (i = 0; i < b.length; i++) {
            uint8 c = uint8(b[i]);
            if (c >= 48 && c <= 57) {
                result = result * 10 + (c - 48);
            }
        }
    }

    function stopMeasuringGas() internal virtual returns (uint256) {
        uint256 checkpointGasLeft2 = gasleft();

        // Subtract 146 to account for startMeasuringGas/stopMeasuringGas
        // 100 for cost of setting checkpointGasLeft to same value
        // 40 to call function?
        uint256 gasUsed = (checkpointGasLeft - checkpointGasLeft2) - 140;

        // @dev take the average if test is like `DistributeYieldx100`
        // if the last 4 char of a label == `x100`
        if (eq(slice(checkpointLabel, bytes(checkpointLabel).length - 4, bytes(checkpointLabel).length), "x100")) {
            gasUsed = gasUsed.div(100 ether);
        }

        string memory gasJson = string(abi.encodePacked(JSON_PATH));

        string memory snapFile = string(abi.encodePacked(SNAPSHOT_DIRECTORY, checkpointLabel, ".snap"));

        if (overwrite) {
            vm.writeFile(snapFile, vm.toString(gasUsed));
        } else {
            // if snap file exists
            try vm.readLine(snapFile) returns (string memory oldValue) {
                uint256 oldGasUsed = stringToUint(oldValue);
                bool gasIncrease = gasUsed >= oldGasUsed;
                string memory sign = gasIncrease ? "+" : "-";
                string memory diff =
                    string.concat(sign, Strings.toString(gasIncrease ? gasUsed - oldGasUsed : oldGasUsed - gasUsed));

                if (gasUsed != oldGasUsed) {
                    vm.writeFile(snapFile, vm.toString(gasUsed));
                    if (gasUsed > oldGasUsed + 10000) {
                        console.log(
                            string.concat(
                                string(abi.encodePacked(checkpointLabel)), vm.toString(gasUsed), vm.toString(oldGasUsed), diff
                            )
                        );
                    }
                }
            } catch {
                // if not, read gas.json
                try vm.readFile(gasJson) returns (string memory json) {
                    bytes memory parsed = vm.parseJson(json, string.concat(".", checkpointLabel));

                    // if no key
                    if (parsed.length == 0) {
                        // write new file
                        vm.writeFile(snapFile, vm.toString(gasUsed));
                    } else {
                        // otherwise use this value as the old
                        uint256 oldGasUsed = abi.decode(parsed, (uint256));
                        bool gasIncrease = gasUsed >= oldGasUsed;
                        string memory sign = gasIncrease ? "+" : "-";
                        string memory diff =
                            string.concat(sign, Strings.toString(gasIncrease ? gasUsed - oldGasUsed : oldGasUsed - gasUsed));

                        if (gasUsed != oldGasUsed) {
                            vm.writeFile(snapFile, vm.toString(gasUsed));
                            if (gasUsed > oldGasUsed + 10000) {
                                console.log(
                                    string.concat(
                                        string(abi.encodePacked(checkpointLabel)),
                                        vm.toString(gasUsed),
                                        vm.toString(oldGasUsed),
                                        diff
                                    )
                                );
                            }
                        }
                    }
                } catch {
                    vm.writeFile(snapFile, vm.toString(gasUsed));
                }
            }
        }

        return gasUsed;
    }
}

contract GasHelper is Gas {
    using U88 for uint88;

    address public receiver = makeAddr("receiver");
    address public sender = makeAddr("sender");
    address public extra = makeAddr("extra");
    address public owner = address(0x71C05a4eA5E9d5b1Ac87Bf962a043f5265d4Bdc8);
    address public tapp;
    address public asset;

    IAsset public ditto;
    IAsset public dusd;

    address public _ob;
    IOBFixture public ob;
    address public _diamond;
    IDiamond public diamond;
    ITestFacet public testFacet;

    uint16 initialCR;

    function setUp() public virtual {
        _ob = deployCode("OBFixture.sol");
        ob = IOBFixture(_ob);
        ob.setUp();

        asset = ob.asset();
        _diamond = ob.contracts("diamond");
        diamond = IDiamond(payable(_diamond));
        testFacet = ITestFacet(_diamond);
        tapp = _diamond;

        ditto = IAsset(ob.contracts("ditto"));
        dusd = IAsset(ob.contracts("dusd"));

        //@dev skip to make updatedAt for
        skip(1 days);
        ob.setETH(4000 ether);

        initialCR = diamond.getAssetStruct(asset).initialCR;
        // Mint to random address for representative gas costs
        vm.startPrank(_diamond);
        ditto.mint(makeAddr("random"), 1);
        dusd.mint(makeAddr("random"), 1);
        vm.stopPrank();
    }

    modifier deposits() {
        ob.depositUsd(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(receiver, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositUsd(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        ob.depositEth(sender, DEFAULT_AMOUNT.mulU88(100 ether));
        _;
    }

    function createShortHintArrayGas(uint16 shortHint) public pure returns (uint16[] memory) {
        uint16[] memory shortHintArray = new uint16[](1);
        shortHintArray[0] = shortHint;
        return shortHintArray;
    }

    function createOrderHintArrayGas() public pure returns (MTypes.OrderHint[] memory orderHintArray) {
        orderHintArray = new MTypes.OrderHint[](1);
        orderHintArray[0] = MTypes.OrderHint({hintId: 0, creationTime: 0});
        return orderHintArray;
    }
}
