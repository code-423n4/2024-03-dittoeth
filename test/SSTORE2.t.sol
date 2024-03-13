// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {SSTORE2} from "solmate/utils/SSTORE2.sol";
import {Test} from "forge-std/Test.sol";

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

struct ProposalData {
    // SLOT 1: 160 + 8 + 88 = 232 (24 unused)
    address shorter;
    uint8 shortId;
    uint64 CR;
    // SLOT 2: 88 + 88 = 176 (80 unused)
    uint88 ercDebtRedeemed;
    uint88 colRedeemed;
}

// solhint-disable-next-line contract-name-camelcase
library console {
    function logBytes(bytes memory p0) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(bytes)", p0));
    }

    function log() internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string)", ""));
    }

    function log(ProposalData memory proposalData) internal pure {
        _sendLogPayload(abi.encodeWithSignature("log(string)", "Proposal Data"));
        _sendLogPayload(abi.encodeWithSignature("log(string,address)", "shorter:", proposalData.shorter));
        _sendLogPayload(abi.encodeWithSignature("log(string,uint)", "shortId:", proposalData.shortId));
        _sendLogPayload(abi.encodeWithSignature("log(string,uint)", "CR:", proposalData.CR));
        _sendLogPayload(abi.encodeWithSignature("log(string,uint)", "ercDebtRedeemed:", proposalData.ercDebtRedeemed));
        _sendLogPayload(abi.encodeWithSignature("log(string,uint)", "colRedeemed:", proposalData.colRedeemed));
    }
}

// no need of abi.encodePacked? https://github.com/ethereum/solidity/issues/11593#issuecomment-1760480573
// https://gist.github.com/rmeissner/76d6345796909ee41fb9f36fdaa4d15f
library BytesLib {
    function slice(bytes memory _bytes, uint256 _start, uint256 _length) internal pure returns (bytes memory) {
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");

        bytes memory tempBytes;

        // Check length is 0. `iszero` return 1 for `true` and 0 for `false`.
        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // Calculate length mod 32 to handle slices that are not a multiple of 32 in size.
                let lengthmod := and(_length, 31)

                // tempBytes will have the following format in memory: <length><data>
                // When copying data I will offset the start forward to avoid allocating additional memory
                // Therefore part of the length area will be written, but this will be overwritten later anyways.
                // In case no offset is require, the start is set to the data region (0x20 from the tempBytes)
                // mc will be used to keep track where to copy the data to.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // Same logic as for mc is applied and additionally the start offset specified for the method is added
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    // increase `mc` and `cc` to read the next word from memory
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    // Copy the data from source (cc location) to the slice data (mc location)
                    mstore(mc, mload(cc))
                }

                // Store the length of the slice. This will overwrite any partial data that
                // was copied when having slices that are not a multiple of 32.
                mstore(tempBytes, _length)

                // update free-memory pointer
                // allocating the array padded to 32 bytes like the compiler does now
                // To set the used memory as a multiple of 32, add 31 to the actual memory usage (mc)
                // and remove the modulo 32 (the `and` with `not(31)`)
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            // if I want a zero-length slice let's just return a zero-length array
            default {
                tempBytes := mload(0x40)
                // zero out the 32 bytes sliceI are about to return
                // I need to do it because Solidity does not garbage collect
                mstore(tempBytes, 0)

                // update free-memory pointer
                // tempBytes uses 32 bytes in memory (even when empty) for the length.
                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }
}

contract ShortsRevertTest is Test {
    function test_ReadProposalData() public {
        ProposalData[] memory proposalData = new ProposalData[](3);
        proposalData[0] =
            ProposalData({shorter: makeAddr("sender"), shortId: 2, CR: 1 ether, ercDebtRedeemed: 11 ether, colRedeemed: 12 ether});
        proposalData[1] = ProposalData({
            shorter: makeAddr("sender"),
            shortId: 2 + 1,
            CR: 2 ether,
            ercDebtRedeemed: 13 ether,
            colRedeemed: 14 ether
        });
        proposalData[2] = ProposalData({
            shorter: makeAddr("sender"),
            shortId: 2 + 2,
            CR: 3 ether,
            ercDebtRedeemed: 15 ether,
            colRedeemed: 16 ether
        });

        console.log(proposalData[0]);
        console.log(proposalData[1]);
        console.log(proposalData[2]);
        console.log();

        bytes memory slate = new bytes(0);
        // https://docs.soliditylang.org/en/latest/types.html#the-functions-bytes-concat-and-string-concat
        for (uint256 i = 0; i < proposalData.length; i++) {
            // slate = bytes.concat(
            //     slate,
            //     bytes20(proposalData[i].shorter),
            //     bytes1(proposalData[i].shortId),
            //     bytes8(proposalData[i].CR),
            //     bytes11(proposalData[i].ercDebtRedeemed),
            //     bytes11(proposalData[i].colRedeemed)
            // );

            slate = bytes.concat(
                slate,
                abi.encodePacked(proposalData[i].shorter),
                abi.encodePacked(proposalData[i].shortId),
                abi.encodePacked(proposalData[i].CR),
                abi.encodePacked(proposalData[i].ercDebtRedeemed),
                abi.encodePacked(proposalData[i].colRedeemed)
            );
        }
        // address pointer = SSTORE2.write(slate);
        console.logBytes(slate);
        console.log();

        // can use slice with calldata
        // https://docs.soliditylang.org/en/v0.6.0/types.html#array-slices
        // function forward(bytes calldata _payload) external {
        //   bytes4 sig = abi.decode(_payload[:4], (bytes4));
        // }

        ProposalData[] memory recreate = new ProposalData[](3);
        for (uint256 i = 0; i < recreate.length; i++) {
            uint256 offset = i * 51;
            recreate[i] = ProposalData({
                shorter: address(bytes20(BytesLib.slice(slate, offset, 20))),
                shortId: uint8(bytes1(BytesLib.slice(slate, offset + 20, 1))),
                CR: uint64(bytes8(BytesLib.slice(slate, offset + 21, 8))),
                ercDebtRedeemed: uint88(bytes11(BytesLib.slice(slate, offset + 29, 11))),
                colRedeemed: uint88(bytes11(BytesLib.slice(slate, offset + 40, 11)))
            });
        }
        console.log(recreate[0]);
        console.log(recreate[1]);
        console.log(recreate[2]);
        console.log();

        bytes memory testBytes = abi.encode(proposalData);
        // address pointer2 = SSTORE2.write(testBytes);
        // console.logBytes(testBytes);

        // ProposalData memory testDecode =
        //     abi.decode(BytesLib.slice(slate, 0, 51), (ProposalData));
        // console.log(testDecode);

        // bytes memory testBytes2 = abi.encode(proposalData[0]);
        // console.log();
        // console.logBytes(testBytes2);
        // console.log();

        // ProposalData memory testDecode = bytesToProposalData(slate);
        // console.log(testDecode);

        ProposalData[] memory testArr = bytesToArrProposalData(slate);
        console.log(testArr[0]);
        console.log(testArr[1]);
        console.log(testArr[2]);

        // console.logBytes(SSTORE2.read(pointer, 32 * 2, 32 * 2 + 32 * 5 * 1));
    }

    function test_ReadProposal2() public {
        ProposalData[] memory proposalData = new ProposalData[](3);
        proposalData[0] =
            ProposalData({shorter: makeAddr("sender"), shortId: 2, CR: 1 ether, ercDebtRedeemed: 11 ether, colRedeemed: 12 ether});
        proposalData[1] = ProposalData({
            shorter: makeAddr("sender"),
            shortId: 2 + 1,
            CR: 2 ether,
            ercDebtRedeemed: 13 ether,
            colRedeemed: 14 ether
        });
        proposalData[2] = ProposalData({
            shorter: makeAddr("sender"),
            shortId: 2 + 2,
            CR: 3 ether,
            ercDebtRedeemed: 15 ether,
            colRedeemed: 16 ether
        });

        console.log(proposalData[0]);
        console.log(proposalData[1]);
        console.log(proposalData[2]);
        console.log();

        bytes memory slate = new bytes(0);
        bytes memory slate2 = new bytes(0);
        for (uint256 i = 0; i < proposalData.length; i++) {
            slate = bytes.concat(slate, bytes20(proposalData[i].shorter), bytes1(proposalData[i].shortId));
            slate2 = bytes.concat(
                slate2, bytes8(proposalData[i].CR), bytes11(proposalData[i].ercDebtRedeemed), bytes11(proposalData[i].colRedeemed)
            );
        }
        address pointer = SSTORE2.write(slate);
        console.logBytes(SSTORE2.read(pointer));
        console.log();
        pointer = SSTORE2.write(slate2);
        console.logBytes(SSTORE2.read(pointer));
        console.log();

        slate = bytes.concat(slate, slate2);
        pointer = SSTORE2.write(slate);
        console.logBytes(SSTORE2.read(pointer));
        console.log();

        ProposalData[] memory decodedProposalData = readForDispute(pointer, 3, address(0), 0, 2);
        for (uint256 i = 0; i < decodedProposalData.length; i++) {
            console.log(decodedProposalData[i]);
        }
    }

    // 3 - 1 = 2
    // 0 [1] 2

    function readForDispute(
        address SSTORE2Pointer,
        uint8 slateLength,
        address disputeShorter,
        uint8 disputeShortId,
        uint8 incorrectIndex
    ) internal view returns (ProposalData[] memory) {
        bytes memory slate = SSTORE2.read(SSTORE2Pointer);

        require(slate.length % 51 == 0, "Invalid data length");
        ProposalData[] memory data = new ProposalData[](slateLength - incorrectIndex);

        for (uint256 i = 0; i < slateLength; i++) {
            uint256 offset = i * 21 + 32; // 32 offset for array length
            address shorter; // uint160, bytes20
            uint8 shortId; // bytes1

            assembly {
                let fullWord := mload(add(slate, offset))
                shorter := shr(96, fullWord) // 0x60 = 96 (256-160)
                shortId := and(0xff, shr(88, fullWord)) // 0x58 = 88 (96-8), mask of bytes1 = 0xff * 1
            }

            if (shorter == disputeShorter && shortId == disputeShortId) {
                revert("CannotDisputeWithRedeemerProposal");
            }

            uint64 CR; // bytes8
            uint88 ercDebtRedeemed; // bytes11
            uint88 colRedeemed; // bytes11

            if (i >= incorrectIndex) {
                // uint256 totalLen = slate.length / 51;
                uint256 offset2 = 3 * 21 + 32 + i * 30;
                assembly {
                    let fullWord := mload(add(slate, offset2))
                    CR := shr(192, fullWord) // 256-64=192
                    ercDebtRedeemed := and(0xffffffffffffffffffffff, shr(104, fullWord)) // 192-88=104
                    colRedeemed := add(0xffffffffffffffffffffff, shr(16, fullWord)) // 104-88=16
                }
                data[i - incorrectIndex] = ProposalData({
                    shorter: shorter,
                    shortId: shortId,
                    CR: CR,
                    ercDebtRedeemed: ercDebtRedeemed,
                    colRedeemed: colRedeemed
                });
            }
        }

        return data;
    }

    function bytesToProposalData(bytes memory b) public pure returns (ProposalData memory) {
        require(b.length == 51, "Invalid data length");

        address shorter; // uint160, bytes20
        uint8 shortId; // bytes1
        uint64 CR; // bytes8
        uint88 ercDebtRedeemed; // bytes11
        uint88 colRedeemed; // bytes11

        assembly {
            let fullWord := mload(add(b, 32)) // 32 offset for array length
            shorter := shr(96, fullWord) // 0x60 = 96 (256-160)
            shortId := and(0xff, shr(88, fullWord)) // 0x58 = 88 (96-8), mask of bytes1 = 0xff * 1
            CR := and(0xffffffffffffffff, shr(24, fullWord)) // 0x18 = 24 (88-64), mask of bytes8 = 0xff * 8

            fullWord := mload(add(b, 61)) // (32+29 offset)
            ercDebtRedeemed := shr(168, fullWord) // (256-88 = 168)
            colRedeemed := add(0xffffffffffffffffffffff, shr(80, fullWord)) // (256-88-88 = 80), mask of bytes11 = 0xff * 11
        }

        return
            ProposalData({shorter: shorter, shortId: shortId, CR: CR, ercDebtRedeemed: ercDebtRedeemed, colRedeemed: colRedeemed});
    }

    function bytesToArrProposalData(bytes memory b) public pure returns (ProposalData[] memory) {
        require(b.length % 51 == 0, "Invalid data length");

        uint256 len = b.length / 51;
        ProposalData[] memory data = new ProposalData[](len);

        for (uint256 i = 0; i < len; i++) {
            uint256 offset = i * 51 + 32; // 32 offset for array length

            address shorter; // uint160, bytes20
            uint8 shortId; // bytes1
            uint64 CR; // bytes8
            uint88 ercDebtRedeemed; // bytes11
            uint88 colRedeemed; // bytes11

            assembly {
                let fullWord := mload(add(b, offset))
                shorter := shr(96, fullWord) // 0x60 = 96 (256-160)
                shortId := and(0xff, shr(88, fullWord)) // 0x58 = 88 (96-8), mask of bytes1 = 0xff * 1
                CR := and(0xffffffffffffffff, shr(24, fullWord)) // 0x18 = 24 (88-64), mask of bytes8 = 0xff * 8

                fullWord := mload(add(b, add(offset, 29))) // (29 offset)
                ercDebtRedeemed := shr(168, fullWord) // (256-88 = 168)
                colRedeemed := add(0xffffffffffffffffffffff, shr(80, fullWord)) // (256-88-88 = 80), mask of bytes11 = 0xff * 11
            }

            data[i] = ProposalData({
                shorter: shorter,
                shortId: shortId,
                CR: CR,
                ercDebtRedeemed: ercDebtRedeemed,
                colRedeemed: colRedeemed
            });
        }

        return data;
    }
}
