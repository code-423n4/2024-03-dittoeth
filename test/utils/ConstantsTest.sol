// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {C} from "contracts/libraries/Constants.sol";
import {IAsset} from "interfaces/IAsset.sol";

abstract contract ConstantsTest is Test {
    uint80 public constant DEFAULT_PRICE = 0.00025 ether;
    uint80 public constant LOWER_PRICE = DEFAULT_PRICE - 1;
    uint80 public constant HIGHER_PRICE = DEFAULT_PRICE + 1;
    uint88 public constant DEFAULT_AMOUNT = 5000 ether;
    uint88 public constant DEFAULT_TAPP = 1 ether;
    uint88 public constant FUNDED_TAPP = 100 ether;
    uint256 public constant TEN_HRS_PLUS = 10 hours + 1;
    uint256 public constant TWELVE_HRS_PLUS = 12 hours + 1;
    uint256 public constant SIXTEEN_HRS_PLUS = 16 hours + 1;
    uint256 public constant MIN_ETH = 0.0001 ether;
    uint256 public constant MAX_DELTA = 500;
    uint256 public constant MAX_DELTA_SMALL = 5;
    uint256 public constant MAX_DELTA_LARGE = 1000000000; //1 billion wei = $0.000002 @ $2000/ETH
    int256 public constant ORACLE_DECIMALS = C.BASE_ORACLE_DECIMALS;
    uint16 public constant DEFAULT_SHORT_HINT_ID = 100;
    uint16 public constant HIGHER_SHORT_HINT_ID = 101;
    uint8 public constant ZERO = 0;
    uint8 public constant ONE = 1;
    uint88 public constant MAX_REDEMPTION_FEE = 10000 ether; //arbitrary value

    function give(address received, uint256 amount) public {
        uint256 bal = received.balance;
        deal(received, bal + amount);
    }

    function give(address erc, address received, uint256 amount) public {
        uint256 bal = IAsset(erc).balanceOf(received);
        deal(erc, received, bal + amount, true);
    }

    // shorthand string helper
    function s(address val) internal pure returns (string memory) {
        return string.concat("address(", vm.toString(uint256(uint160(val))), ")");
    }

    function s(bytes calldata val) internal pure returns (string memory) {
        return vm.toString(val);
    }

    function s(bytes32 val) internal pure returns (string memory) {
        return vm.toString(val);
    }

    function s(bool val) internal pure returns (string memory) {
        return vm.toString(val);
    }

    function s(uint256 val) internal pure returns (string memory) {
        return vm.toString(val);
    }

    function s(int256 val) internal pure returns (string memory) {
        return vm.toString(val);
    }
}
