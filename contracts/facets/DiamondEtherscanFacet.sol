// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

//https://github.com/zdenham/diamond-etherscan
import {LibDiamond} from "contracts/libraries/LibDiamond.sol";
import {LibDiamondEtherscan} from "contracts/libraries/LibDiamondEtherscan.sol";

contract DiamondEtherscanFacet {
    function setDummyImplementation(address _implementation) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamondEtherscan._setDummyImplementation(_implementation);
    }

    //https://eips.ethereum.org/EIPS/eip-1967
    function implementation() external view returns (address) {
        return LibDiamondEtherscan._dummyImplementation();
    }
}
