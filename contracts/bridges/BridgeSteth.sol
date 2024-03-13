// https://docs.lido.fi/contracts/wsteth
// https://github.com/lidofinance/lido-dao/blob/master/contracts/0.6.12/WstETH.sol

// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {U256} from "contracts/libraries/PRBMathHelper.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {ISTETH} from "interfaces/ISTETH.sol";
import {IUNSTETH} from "interfaces/IUNSTETH.sol";
import {IBridge} from "contracts/interfaces/IBridge.sol";

contract BridgeSteth is IBridge, IERC721Receiver {
    using U256 for uint256;

    ISTETH private immutable steth;
    IUNSTETH private immutable unsteth;
    address private immutable diamond;

    constructor(ISTETH _steth, IUNSTETH _unsteth, address diamondAddr) {
        steth = ISTETH(_steth);
        unsteth = IUNSTETH(_unsteth);
        diamond = diamondAddr;

        steth.approve(address(unsteth), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    }

    modifier onlyDiamond() {
        if (msg.sender != diamond) revert NotDiamond();
        _;
    }

    function onERC721Received(address, /*operator*/ address, /*from*/ uint256, /*tokenId*/ bytes calldata /*data*/ )
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    //@dev does not need read only re-entrancy
    function getBaseCollateral() external view returns (address) {
        return address(steth);
    }

    //@dev does not need read only re-entrancy
    function getDethValue() external view returns (uint256) {
        return steth.balanceOf(address(this));
    }

    //@dev does not need read only re-entrancy
    function getUnitDethValue() external view returns (uint256) {
        // This is actually the dETH value of one wstETH
        // Aligns with UNISWAP pool WETH/WSTETH
        return steth.getPooledEthByShares(1 ether);
    }

    // Bring stETH to system and credit dETH to user
    function deposit(address from, uint256 amount) external onlyDiamond returns (uint256) {
        // Transfer stETH to this bridge contract
        // @dev stETH uses OZ ERC-20, don't need to check success bool
        steth.transferFrom(from, address(this), amount);
        return amount;
    }

    // Deposit ETH and mint stETH (to system) and credit dETH to user
    function depositEth() external payable onlyDiamond returns (uint256) {
        uint256 originalBalance = steth.balanceOf(address(this));
        // @edv address(0) means no fee taken by the referring protocol
        steth.submit{value: msg.value}(address(0));
        uint256 netBalance = steth.balanceOf(address(this)) - originalBalance;
        if (netBalance == 0) revert NetBalanceZero();
        return netBalance;
    }

    // Exchange system stETH to fulfill dETH obligation to user
    function withdraw(address to, uint256 amount) external onlyDiamond returns (uint256) {
        // @dev stETH uses OZ ERC-20, don't need to check success bool
        steth.transfer(to, amount);
        return amount;
    }
}
