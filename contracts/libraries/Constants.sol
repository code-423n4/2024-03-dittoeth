// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

library C {
    // @dev mark start of orders mapping
    uint8 internal constant HEAD = 1;
    // @dev only used as an alias since it's the same id
    uint8 internal constant TAIL = 1;
    // for all order types, starting point of orders
    uint8 internal constant STARTING_ID = 100;

    uint8 internal constant SHORT_MAX_ID = 254; //max uint8
    uint8 internal constant SHORT_STARTING_ID = 2;

    uint8 internal constant BID_CR = 100;

    //redemption
    uint256 internal constant MAX_REDEMPTION_CR = 2 ether;
    uint256 internal constant DISPUTE_REDEMPTION_BUFFER = 3600 seconds; //1 hour
    uint256 public constant BETA = 2 ether;
    /*
     * Half-life of 12h. 12h = 43200 seconds
     * (1/2) = d^43200 => d = (1/2)^(1/43200)
     */

    uint256 public constant SECONDS_DECAY_FACTOR = 0.9999839550551 ether;

    uint256 internal constant ROUNDING_ZERO = 100 wei; // @dev Using 100 wei as approximation for 0 to account for rounding
    uint256 internal constant DUST_FACTOR = 0.5 ether;
    uint256 internal constant MIN_DURATION = 14 days;
    uint256 internal constant CRATIO_MAX = 15 ether;
    uint256 internal constant CRATIO_MAX_INITIAL = CRATIO_MAX - 1 ether; // @dev minus 1 bc it comes from bidder
    uint256 internal constant YIELD_DELAY_SECONDS = 60; // just need enough to prevent flash loan
    uint256 internal constant BRIDGE_YIELD_UPDATE_THRESHOLD = 1000 ether;
    uint256 internal constant BRIDGE_YIELD_PERCENT_THRESHOLD = 0.01 ether; // 1%

    // Tithe
    uint16 internal constant MAX_TITHE = 100_00;
    uint16 internal constant INITIAL_TITHE_MOD = 0;

    // Bridge
    // @dev Matching RocketPool min deposit for now, Lido is 100 wei
    uint88 internal constant MIN_DEPOSIT = 0.01 ether;

    // reentrancy
    uint8 internal constant NOT_ENTERED = 1;
    uint8 internal constant ENTERED = 2;
    uint256 internal constant ONE_DECIMAL_PLACES = 10;
    uint256 internal constant TWO_DECIMAL_PLACES = 100;
    uint256 internal constant THREE_DECIMAL_PLACES = 1000;
    uint256 internal constant FOUR_DECIMAL_PLACES = 10000;
    uint256 internal constant FIVE_DECIMAL_PLACES = 100000;
    uint256 internal constant ONE_THIRD = 0.333333333333333333 ether;

    // set this to a datetime closer to deployment
    // @dev changing this will likely break the end to end fork test
    uint256 internal constant STARTING_TIME = 1660353637;

    int256 internal constant PREV = -1;
    int256 internal constant EXACT = 0;
    int256 internal constant NEXT = 1;

    bool internal constant MARKET_ORDER = true;
    bool internal constant LIMIT_ORDER = false;

    // Oracle
    // Base Oracle needs to be adjust 10**10 to have full 18 precision
    int256 internal constant BASE_ORACLE_DECIMALS = 10 ** 10;

    // Mainnet TWAP
    address internal constant USDC_WETH = address(0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640);
    address internal constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address internal constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    uint128 internal constant UNISWAP_WETH_BASE_AMT = 1 ether;
    uint256 internal constant DECIMAL_USDC = 10 ** 6; //USDC's ERC contract sets to 6 decimals
}

library VAULT {
    // ONE is the default vault
    uint256 internal constant ONE = 1;
    // Bridges for Vault ONE
    uint256 internal constant BRIDGE_RETH = 0;
    uint256 internal constant BRIDGE_STETH = 1;
    // TWAP for Vault ONE
    address internal constant WSTETH_WETH = address(0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa);
    address internal constant WSTETH = address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    // @dev MUST redeploy if rETH address changes in Rocket Storage
    address internal constant RETH_WETH = address(0x553e9C493678d8606d6a5ba284643dB2110Df823);
    address internal constant RETH = address(0xae78736Cd615f374D3085123A210448E74Fc6393);
}
