// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.21;

import {C} from "contracts/libraries/Constants.sol";
import {OracleLibrary} from "contracts/libraries/UniswapOracleLibrary.sol";

// import {console} from "contracts/libraries/console.sol";

contract TWAPFacet {
    //@dev Computes arithmetic mean of prices between current time and x seconds ago.
    //@dev Uses parts of underlying code for OracleLibrary.consult()
    function estimateWETHInUSDC(uint128 amountIn, uint32 secondsAgo) external view returns (uint256 amountOut) {
        return OracleLibrary.estimateTWAP({
            amountIn: amountIn,
            secondsAgo: secondsAgo,
            pool: C.USDC_WETH,
            baseToken: C.WETH,
            quoteToken: C.USDC
        });
    }
}
