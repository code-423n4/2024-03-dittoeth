// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {SSTORE2} from "solmate/utils/SSTORE2.sol";
import {Test, console} from "forge-std/Test.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {stdJson} from "forge-std/StdJson.sol";

address constant CONSOLE_ADDRESS = address(0x000000000000000000636F6e736F6c652e6c6f67);

/* solhint-disable */
function _castLogPayloadViewToPure(function(bytes memory) internal view fnIn)
    pure
    returns (function(bytes memory) internal pure fnOut)
{
    assembly {
        fnOut := fnIn
    }
}

function _sendLogPayload(bytes memory payload) pure {
    _castLogPayloadViewToPure(_sendLogPayloadView)(payload);
}

function _sendLogPayloadView(bytes memory payload) view {
    uint256 payloadLength = payload.length;
    address consoleAddress = CONSOLE_ADDRESS;
    assembly {
        let payloadStart := add(payload, 32)
        let r := staticcall(gas(), consoleAddress, payloadStart, payloadLength, 0, 0)
    }
}
/* solhint-enable */

function logBytes(bytes memory p0) pure {
    _sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
}

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

contract Gas is Test {
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
                        // solhint-disable-next-line no-console
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
                                // solhint-disable-next-line no-console
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

contract GasRedemptionFixture is Gas {
    struct ProposalInput2 {
        address shorter;
        uint8 shortId;
    }

    struct ProposalInput {
        address shorter;
    }

    function makeProposalInputs(uint8 numInputs) public pure returns (ProposalInput[] memory proposalInputs) {
        proposalInputs = new ProposalInput[](numInputs);
        for (uint8 i = 0; i < numInputs; i++) {
            // proposalInputs[i] = ProposalInput({shorter: address(1337), shortId: 2 + i});
            proposalInputs[i] = ProposalInput({shorter: address(1337)});
        }
    }

    function makeProposalInputs2(uint8 numInputs) public pure returns (ProposalInput2[] memory proposalInputs) {
        proposalInputs = new ProposalInput2[](numInputs);
        for (uint8 i = 0; i < numInputs; i++) {
            proposalInputs[i] = ProposalInput2({shorter: address(1337), shortId: 2 + i});
        }
    }
}

contract GasRedemptionTest is GasRedemptionFixture {
    function test_GasSSTORE2_1() public {
        address addr = address(1337);
        bytes memory sstore2Bytes = abi.encode(addr);
        address a;

        // 0x
        // 0000000000000000000000000000000000000000000000000000000000000539
        logBytes(sstore2Bytes);

        startMeasuringGas("SSTORE2-1a");
        a = SSTORE2.write(sstore2Bytes);
        stopMeasuringGas();
    }

    function test_GasSSTORE2_2() public {
        uint8 redemptions = 2;
        ProposalInput[] memory proposalInputs = makeProposalInputs(redemptions);
        bytes memory sstore2Bytes = abi.encode(proposalInputs);
        address a;

        // 0x
        // 0000000000000000000000000000000000000000000000000000000000000020
        // 0000000000000000000000000000000000000000000000000000000000000002
        // 0000000000000000000000000000000000000000000000000000000000000539
        // 0000000000000000000000000000000000000000000000000000000000000539
        logBytes(sstore2Bytes);

        startMeasuringGas("SSTORE2-2");
        a = SSTORE2.write(sstore2Bytes);
        stopMeasuringGas();
    }

    function test_GasSSTORE2_3() public {
        uint8 redemptions = 3;
        ProposalInput[] memory proposalInputs = makeProposalInputs(redemptions);
        bytes memory sstore2Bytes = abi.encode(proposalInputs);
        address a;

        // 0x
        // 0000000000000000000000000000000000000000000000000000000000000020
        // 0000000000000000000000000000000000000000000000000000000000000003
        // 0000000000000000000000000000000000000000000000000000000000000539
        // 0000000000000000000000000000000000000000000000000000000000000539
        // 0000000000000000000000000000000000000000000000000000000000000539
        logBytes(sstore2Bytes);

        startMeasuringGas("SSTORE2-3");
        a = SSTORE2.write(sstore2Bytes);
        stopMeasuringGas();
    }

    function test_GasSSTORE2_I2() public {
        uint8 redemptions = 1;
        ProposalInput2[] memory proposalInputs = makeProposalInputs2(redemptions);
        bytes memory sstore2Bytes = abi.encode(proposalInputs);
        address a;

        // 0x
        // 0000000000000000000000000000000000000000000000000000000000000020
        // 0000000000000000000000000000000000000000000000000000000000000001
        // 0000000000000000000000000000000000000000000000000000000000000539
        // 0000000000000000000000000000000000000000000000000000000000000002
        logBytes(sstore2Bytes);
        startMeasuringGas("SSTORE2-2a");
        a = SSTORE2.write(sstore2Bytes);
        stopMeasuringGas();
    }

    // address shorter;
    // uint8 shortId;
    // uint64 CR;
    // function test_GasSSTORE2_I3() public {
    //     uint8 redemptions = 2;
    //     ProposalInput3[] memory proposalInputs = makeProposalInputs3(redemptions);
    //     bytes memory sstore2Bytes = abi.encode(proposalInputs);
    //     address a;

    //     // 0x
    //     // 0000000000000000000000000000000000000000000000000000000000000020 // offset of 1 line/32 bytes
    //     // 0000000000000000000000000000000000000000000000000000000000000002 // length of array, 2
    //     // 0000000000000000000000000000000000000000000000000000000000000539 // address(1337)
    //     // 0000000000000000000000000000000000000000000000000000000000000002 // shortId of 2
    //     // 0000000000000000000000000000000000000000000000001bc16d674ec80000 // 2 ether
    //     // 0000000000000000000000000000000000000000000000000000000000000539 // address(1337)
    //     // 0000000000000000000000000000000000000000000000000000000000000003 // shortId of 3
    //     // 0000000000000000000000000000000000000000000000001bc16d674ec80000 // 2 ether
    //     logBytes(sstore2Bytes);
    //     startMeasuringGas("SSTORE2-3a");
    //     a = SSTORE2.write(sstore2Bytes);
    //     stopMeasuringGas();
    // }
}
