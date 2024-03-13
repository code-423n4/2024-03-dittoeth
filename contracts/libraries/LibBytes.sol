// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {MTypes} from "contracts/libraries/DataTypes.sol";
import {SSTORE2} from "solmate/utils/SSTORE2.sol";

// import {console} from "contracts/libraries/console.sol";

library LibBytes {
    // custom decode since SSTORE.write was written directly in proposeRedemption
    function readProposalData(address SSTORE2Pointer, uint8 slateLength) internal view returns (MTypes.ProposalData[] memory) {
        bytes memory slate = SSTORE2.read(SSTORE2Pointer);
        // ProposalData is 51 bytes
        require(slate.length % 51 == 0, "Invalid data length");

        MTypes.ProposalData[] memory data = new MTypes.ProposalData[](slateLength);

        for (uint256 i = 0; i < slateLength; i++) {
            // 32 offset for array length, mulitply by each ProposalData
            uint256 offset = i * 51 + 32;

            address shorter; // bytes20
            uint8 shortId; // bytes1
            uint64 CR; // bytes8
            uint88 ercDebtRedeemed; // bytes11
            uint88 colRedeemed; // bytes11

            assembly {
                // mload works 32 bytes at a time
                let fullWord := mload(add(slate, offset))
                // read 20 bytes
                shorter := shr(96, fullWord) // 0x60 = 96 (256-160)
                // read 8 bytes
                shortId := and(0xff, shr(88, fullWord)) // 0x58 = 88 (96-8), mask of bytes1 = 0xff * 1
                // read 64 bytes
                CR := and(0xffffffffffffffff, shr(24, fullWord)) // 0x18 = 24 (88-64), mask of bytes8 = 0xff * 8

                fullWord := mload(add(slate, add(offset, 29))) // (29 offset)
                // read 88 bytes
                ercDebtRedeemed := shr(168, fullWord) // (256-88 = 168)
                // read 88 bytes
                colRedeemed := add(0xffffffffffffffffffffff, shr(80, fullWord)) // (256-88-88 = 80), mask of bytes11 = 0xff * 11
            }

            data[i] = MTypes.ProposalData({
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
