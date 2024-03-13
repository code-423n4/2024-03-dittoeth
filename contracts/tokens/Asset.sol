// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {ERC20, ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract Asset is ERC20, ERC20Permit {
    address private immutable diamond;

    error NotDiamond();

    constructor(address diamondAddr, string memory name, string memory symbol) ERC20(name, symbol) ERC20Permit(name) {
        diamond = diamondAddr;
    }

    modifier onlyDiamond() {
        if (msg.sender != diamond) revert NotDiamond();
        _;
    }

    function mint(address to, uint256 amount) external onlyDiamond {
        _mint(to, amount);
    }

    function burnFrom(address account, uint256 amount) external onlyDiamond {
        _burn(account, amount);
    }
}
