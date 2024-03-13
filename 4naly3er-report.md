**Table of Contents**

- [Report](#report)
  - [Gas Optimizations](#gas-optimizations)
    - [\[GAS-1\] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)](#gas-1-a--a--b-is-more-gas-effective-than-a--b-for-state-variables-excluding-arrays-and-mappings)
    - [\[GAS-2\] Use assembly to check for `address(0)`](#gas-2-use-assembly-to-check-for-address0)
    - [\[GAS-3\] Cache array length outside of loop](#gas-3-cache-array-length-outside-of-loop)
    - [\[GAS-4\] State variables should be cached in stack variables rather than re-reading them from storage](#gas-4-state-variables-should-be-cached-in-stack-variables-rather-than-re-reading-them-from-storage)
    - [\[GAS-5\] Use calldata instead of memory for function arguments that do not get mutated](#gas-5-use-calldata-instead-of-memory-for-function-arguments-that-do-not-get-mutated)
    - [\[GAS-6\] For Operations that will not overflow, you could use unchecked](#gas-6-for-operations-that-will-not-overflow-you-could-use-unchecked)
    - [\[GAS-7\] Use Custom Errors instead of Revert Strings to save Gas](#gas-7-use-custom-errors-instead-of-revert-strings-to-save-gas)
    - [\[GAS-8\] Avoid contract existence checks by using low level calls](#gas-8-avoid-contract-existence-checks-by-using-low-level-calls)
    - [\[GAS-9\] State variables only set in the constructor should be declared `immutable`](#gas-9-state-variables-only-set-in-the-constructor-should-be-declared-immutable)
    - [\[GAS-10\] Functions guaranteed to revert when called by normal users can be marked `payable`](#gas-10-functions-guaranteed-to-revert-when-called-by-normal-users-can-be-marked-payable)
    - [\[GAS-11\] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)](#gas-11-i-costs-less-gas-compared-to-i-or-i--1-same-for---i-vs-i---or-i---1)
    - [\[GAS-12\] Increments/decrements can be unchecked in for-loops](#gas-12-incrementsdecrements-can-be-unchecked-in-for-loops)
    - [\[GAS-13\] Use != 0 instead of \> 0 for unsigned integer comparison](#gas-13-use--0-instead-of--0-for-unsigned-integer-comparison)
    - [\[GAS-14\] `internal` functions not called by the contract should be removed](#gas-14-internal-functions-not-called-by-the-contract-should-be-removed)
  - [Non Critical Issues](#non-critical-issues)
    - [\[NC-1\] Missing checks for `address(0)` when assigning values to address state variables](#nc-1-missing-checks-for-address0-when-assigning-values-to-address-state-variables)
    - [\[NC-2\] Array indices should be referenced via `enum`s rather than via numeric literals](#nc-2-array-indices-should-be-referenced-via-enums-rather-than-via-numeric-literals)
    - [\[NC-3\] `require()` should be used instead of `assert()`](#nc-3-require-should-be-used-instead-of-assert)
    - [\[NC-4\] `constant`s should be defined rather than using magic numbers](#nc-4-constants-should-be-defined-rather-than-using-magic-numbers)
    - [\[NC-5\] Control structures do not follow the Solidity Style Guide](#nc-5-control-structures-do-not-follow-the-solidity-style-guide)
    - [\[NC-6\] Dangerous `while(true)` loop](#nc-6-dangerous-whiletrue-loop)
    - [\[NC-7\] Delete rogue `console.log` imports](#nc-7-delete-rogue-consolelog-imports)
    - [\[NC-8\] Function ordering does not follow the Solidity style guide](#nc-8-function-ordering-does-not-follow-the-solidity-style-guide)
    - [\[NC-9\] Functions should not be longer than 50 lines](#nc-9-functions-should-not-be-longer-than-50-lines)
    - [\[NC-10\] Change int to int256](#nc-10-change-int-to-int256)
    - [\[NC-11\] Interfaces should be defined in separate files from their usage](#nc-11-interfaces-should-be-defined-in-separate-files-from-their-usage)
    - [\[NC-12\] Lack of checks in setters](#nc-12-lack-of-checks-in-setters)
    - [\[NC-13\] Incomplete NatSpec: `@param` is missing on actually documented functions](#nc-13-incomplete-natspec-param-is-missing-on-actually-documented-functions)
    - [\[NC-14\] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor](#nc-14-use-a-modifier-instead-of-a-requireif-statement-for-a-special-msgsender-actor)
    - [\[NC-15\] Consider using named mappings](#nc-15-consider-using-named-mappings)
    - [\[NC-16\] Adding a `return` statement when the function defines a named return variable, is redundant](#nc-16-adding-a-return-statement-when-the-function-defines-a-named-return-variable-is-redundant)
    - [\[NC-17\] `require()` / `revert()` statements should have descriptive reason strings](#nc-17-requirerevertstatements-should-have-descriptive-reason-strings)
    - [\[NC-18\] Take advantage of Custom Error's return value property](#nc-18-take-advantage-of-custom-errors-return-value-property)
    - [\[NC-19\] Internal and private variables and functions names should begin with an underscore](#nc-19-internal-and-private-variables-and-functions-names-should-begin-with-an-underscore)
    - [\[NC-20\] Constants should be defined rather than using magic numbers](#nc-20-constants-should-be-defined-rather-than-using-magic-numbers)
    - [\[NC-21\] Variables need not be initialized to zero](#nc-21-variables-need-not-be-initialized-to-zero)
  - [Low Issues](#low-issues)
    - [\[L-1\] Missing checks for `address(0)` when assigning values to address state variables](#l-1-missing-checks-for-address0-when-assigning-values-to-address-state-variables)
    - [\[L-2\] Division by zero not prevented](#l-2-division-by-zero-not-prevented)
    - [\[L-3\] External call recipient may consume all transaction gas](#l-3-external-call-recipient-may-consume-all-transaction-gas)
    - [\[L-4\] Signature use at deadlines should be allowed](#l-4-signature-use-at-deadlines-should-be-allowed)
    - [\[L-5\] Loss of precision](#l-5-loss-of-precision)
    - [\[L-6\] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`](#l-6-solidity-version-0820-may-not-work-on-other-chains-due-to-push0)
    - [\[L-7\] Consider using OpenZeppelin's SafeCast library to prevent unexpected overflows when downcasting](#l-7-consider-using-openzeppelins-safecast-library-to-prevent-unexpected-overflows-when-downcasting)
    - [\[L-8\] Upgradeable contract not initialized](#l-8-upgradeable-contract-not-initialized)
  - [Medium Issues](#medium-issues)
    - [\[M-1\] Fees can be set to be greater than 100%](#m-1-fees-can-be-set-to-be-greater-than-100)
    - [\[M-2\] Library function isn't `internal` or `private`](#m-2-library-function-isnt-internal-or-private)
    - [\[M-3\] Chainlink's `latestRoundData` might return stale or incorrect results](#m-3-chainlinks-latestrounddata-might-return-stale-or-incorrect-results)
    - [\[M-4\] Missing checks for whether the L2 Sequencer is active](#m-4-missing-checks-for-whether-the-l2-sequencer-is-active)

# Report

## Gas Optimizations

| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 59 |
| [GAS-2](#GAS-2) | Use assembly to check for `address(0)` | 5 |
| [GAS-3](#GAS-3) | Cache array length outside of loop | 6 |
| [GAS-4](#GAS-4) | State variables should be cached in stack variables rather than re-reading them from storage | 1 |
| [GAS-5](#GAS-5) | Use calldata instead of memory for function arguments that do not get mutated | 3 |
| [GAS-6](#GAS-6) | For Operations that will not overflow, you could use unchecked | 292 |
| [GAS-7](#GAS-7) | Use Custom Errors instead of Revert Strings to save Gas | 1 |
| [GAS-8](#GAS-8) | Avoid contract existence checks by using low level calls | 2 |
| [GAS-9](#GAS-9) | State variables only set in the constructor should be declared `immutable` | 3 |
| [GAS-10](#GAS-10) | Functions guaranteed to revert when called by normal users can be marked `payable` | 1 |
| [GAS-11](#GAS-11) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 16 |
| [GAS-12](#GAS-12) | Increments/decrements can be unchecked in for-loops | 7 |
| [GAS-13](#GAS-13) | Use != 0 instead of > 0 for unsigned integer comparison | 12 |
| [GAS-14](#GAS-14) | `internal` functions not called by the contract should be removed | 24 |

### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)

This saves **16 gas per instance.**

*Instances (59)*:

```solidity
File: contracts/facets/BidOrdersFacet.sol

229:             matchTotal.shortFillEth += shortFillEth;

255:             s.vaultUser[s.asset[asset].vault][lowestSell.addr].ethEscrowed += fillEth;

256:             matchTotal.askFillErc += fillErc;

259:         matchTotal.fillErc += fillErc;

260:         matchTotal.fillEth += fillEth;

303:             Vault.dittoMatchedShares += matchTotal.dittoMatchedShares;

305:             Vault.dethCollateral += matchTotal.shortFillEth;

306:             Asset.dethCollateral += matchTotal.shortFillEth;

307:             Asset.ercDebt += matchTotal.fillErc - matchTotal.askFillErc;

331:         s.assetUser[asset][bidder].ercEscrowed += matchTotal.fillErc;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)

```solidity
File: contracts/facets/BridgeRouterFacet.sol

114:                     s.vaultUser[vault][address(this)].ethEscrowed += fee;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

```solidity
File: contracts/facets/ExitShortFacet.sol

60:             s.vaultUser[Asset.vault][msg.sender].ethEscrowed += collateral;

112:             s.vaultUser[Asset.vault][msg.sender].ethEscrowed += collateral;

183:         VaultUser.ethEscrowed += e.collateral;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

```solidity
File: contracts/facets/RedemptionFacet.sol

122:             p.totalAmountProposed += p.amountProposed;

123:             p.totalColRedeemed += p.colRedeemed;

265:                 currentSR.collateral += currentProposal.colRedeemed;

266:                 currentSR.ercDebt += currentProposal.ercDebtRedeemed;

268:                 d.incorrectCollateral += currentProposal.colRedeemed;

269:                 d.incorrectErcDebt += currentProposal.ercDebtRedeemed;

272:             s.vault[Asset.vault].dethCollateral += d.incorrectCollateral;

273:             Asset.dethCollateral += d.incorrectCollateral;

274:             Asset.ercDebt += d.incorrectErcDebt;

294:             redeemerAssetUser.ercEscrowed += (d.incorrectErcDebt - penaltyAmt);

295:             s.assetUser[d.asset][msg.sender].ercEscrowed += penaltyAmt;

321:             totalColRedeemed += currentProposal.colRedeemed;

329:         redeemerVaultUser.ethEscrowed += totalColRedeemed;

372:             s.vaultUser[vault][shorter].ethEscrowed += collateral;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibBridgeRouter.sol

27:                 VaultUser.bridgeCreditReth += amount;

29:                 VaultUser.bridgeCreditSteth += amount;

33:         VaultUser.ethEscrowed += amount;

34:         s.vault[vault].dethTotal += amount;

162:                     VaultUserTo.bridgeCreditReth += collateral;

165:                     VaultUserTo.bridgeCreditReth += creditReth;

171:                     VaultUserTo.bridgeCreditSteth += collateral;

174:                     VaultUserTo.bridgeCreditSteth += creditSteth;

188:                 VaultUserTo.bridgeCreditReth += creditReth;

189:                 VaultUserTo.bridgeCreditSteth += creditSteth;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBridgeRouter.sol)

```solidity
File: contracts/libraries/LibOrders.sol

48:             matchTotal.dittoMatchedShares += shares;

51:             s.vaultUser[vault][order.addr].dittoMatchedShares += shares;

210:             s.asset[asset].orderIdCounter += 1;

657:         s.vaultUser[vault][asker].ethEscrowed += matchTotal.fillEth;

658:         s.vault[vault].dittoMatchedShares += matchTotal.dittoMatchedShares;

675:         matchTotal.fillEth += matchTotal.colUsed;

690:         Vault.dittoMatchedShares += matchTotal.dittoMatchedShares;

691:         Vault.dethCollateral += matchTotal.fillEth;

692:         Asset.dethCollateral += matchTotal.fillEth;

693:         Asset.ercDebt += matchTotal.fillErc;

718:             matchTotal.colUsed += incomingSell.price.mulU88(fillErc).mulU88(LibOrders.convertCR(incomingSell.shortOrderCR));

720:         matchTotal.fillErc += fillErc;

721:         matchTotal.fillEth += fillEth;

725:         s.assetUser[asset][highestBid.addr].ercEscrowed += fillErc;

863:         s.vaultUser[vault][bid.addr].ethEscrowed += eth;

877:         s.assetUser[asset][ask.addr].ercEscrowed += ask.ercAmount;

924:                     Vault.dethCollateral += collateralDiff;

925:                     Asset.dethCollateral += collateralDiff;

926:                     Asset.ercDebt += debtDiff;

932:                 s.assetUser[asset][shorter].ercEscrowed += debtDiff;

938:         s.vaultUser[vault][shorter].ethEscrowed += eth;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

### <a name="GAS-2"></a>[GAS-2] Use assembly to check for `address(0)`

*Saves 6 gas per instance*

*Instances (5)*:

```solidity
File: contracts/facets/RedemptionFacet.sol

71:         if (redeemerAssetUser.SSTORE2Pointer != address(0)) revert Errors.ExistingProposedRedemptions();

233:         if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();

312:         if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();

351:         if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibOracle.sol

25:         if (address(oracle) == address(0)) revert Errors.InvalidAsset();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

### <a name="GAS-3"></a>[GAS-3] Cache array length outside of loop

If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (6)*:

```solidity
File: contracts/facets/RedemptionFacet.sol

76:         for (uint8 i = 0; i < proposalInput.length; i++) {

240:         for (uint256 i = 0; i < decodedProposalData.length; i++) {

261:             for (uint256 i = incorrectIndex; i < decodedProposalData.length; i++) {

319:         for (uint256 i = 0; i < decodedProposalData.length; i++) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibOrders.sol

743:             for (uint256 i = 0; i < shortHintArray.length;) {

832:         for (uint256 i; i < orderHintArray.length; i++) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

### <a name="GAS-4"></a>[GAS-4] State variables should be cached in stack variables rather than re-reading them from storage

The instances below point to the second+ access of a state variable within a function. Caching of a state variable replaces each Gwarmaccess (100 gas) with a much cheaper stack read. Other less obvious fixes/optimizations include having local memory caches of state variable structs, or having local caches of state variable contracts/addresses.

*Saves 100 gas per instance*

*Instances (1)*:

```solidity
File: contracts/facets/BridgeRouterFacet.sol

110:                 uint256 withdrawalFeePct = LibBridgeRouter.withdrawalFeePct(bridgePointer, rethBridge, stethBridge);

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

### <a name="GAS-5"></a>[GAS-5] Use calldata instead of memory for function arguments that do not get mutated

When a function with a `memory` array is called externally, the `abi.decode()` step has to use a for-loop to copy each index of the `calldata` to the `memory` index. Each iteration of this for-loop costs at least 60 gas (i.e. `60 * <mem_array>.length`). Using `calldata` directly bypasses this loop.

If the array is passed to an `internal` function which passes the array to another internal function where the array is modified and therefore `memory` is used in the `external` call, it's still more gas-efficient to use `calldata` when the `external` function uses modifiers, since the modifiers may prevent the internal functions from being called. Structs have the same overhead as an array of length one.

 *Saves 60 gas per instance*

*Instances (3)*:

```solidity
File: contracts/facets/ExitShortFacet.sol

147:         uint16[] memory shortHintArray,

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

```solidity
File: contracts/facets/ShortOrdersFacet.sol

39:         MTypes.OrderHint[] memory orderHintArray,

40:         uint16[] memory shortHintArray,

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ShortOrdersFacet.sol)

### <a name="GAS-6"></a>[GAS-6] For Operations that will not overflow, you could use unchecked

*Instances (292)*:

```solidity
File: contracts/facets/BidOrdersFacet.sol

4: import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

6: import {IDiamond} from "interfaces/IDiamond.sol";

8: import {Modifiers} from "contracts/libraries/AppStorage.sol";

9: import {Errors} from "contracts/libraries/Errors.sol";

10: import {Events} from "contracts/libraries/Events.sol";

11: import {STypes, MTypes, O, SR} from "contracts/libraries/DataTypes.sol";

12: import {LibAsset} from "contracts/libraries/LibAsset.sol";

13: import {LibOracle} from "contracts/libraries/LibOracle.sol";

14: import {LibOrders} from "contracts/libraries/LibOrders.sol";

15: import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";

16: import {C} from "contracts/libraries/Constants.sol";

157:                     incomingBid.ercAmount -= lowestSell.ercAmount;

180:                         lowestSell.ercAmount -= incomingBid.ercAmount;

228:             uint88 shortFillEth = fillEth + colUsed;

229:             matchTotal.shortFillEth += shortFillEth;

255:             s.vaultUser[s.asset[asset].vault][lowestSell.addr].ethEscrowed += fillEth;

256:             matchTotal.askFillErc += fillErc;

259:         matchTotal.fillErc += fillErc;

260:         matchTotal.fillEth += fillEth;

303:             Vault.dittoMatchedShares += matchTotal.dittoMatchedShares;

305:             Vault.dethCollateral += matchTotal.shortFillEth;

306:             Asset.dethCollateral += matchTotal.shortFillEth;

307:             Asset.ercDebt += matchTotal.fillErc - matchTotal.askFillErc;

329:         address bidder = incomingBid.addr; // saves 18 gas

330:         s.vaultUser[vault][bidder].ethEscrowed -= matchTotal.fillEth;

331:         s.assetUser[asset][bidder].ercEscrowed += matchTotal.fillErc;

366:          +----------------+-------------------------+--------------------------+

368:          +----------------+-------------------------+--------------------------+

369:          | Fwd only       | firstShortIdBelowOracle*| matchedShortId           |

370:          | Back only      | prevShortId             |shortHintId**             |

372:          +----------------+-------------------------+--------------------------+

381:         BEFORE: HEAD <-> (ID1)* <-> (ID2) <-> (ID3) <-> (ID4) <-> [ID5] <-> (ID6) <-> NEXT

387:         AFTER: HEAD <-> (ID1)* <-> (ID6) <-> NEXT

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)

```solidity
File: contracts/facets/BridgeRouterFacet.sol

4: import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

6: import {IBridge} from "contracts/interfaces/IBridge.sol";

8: import {Modifiers} from "contracts/libraries/AppStorage.sol";

9: import {Errors} from "contracts/libraries/Errors.sol";

10: import {Events} from "contracts/libraries/Events.sol";

11: import {LibBridge} from "contracts/libraries/LibBridge.sol";

12: import {LibBridgeRouter} from "contracts/libraries/LibBridgeRouter.sol";

13: import {LibVault} from "contracts/libraries/LibVault.sol";

14: import {C, VAULT} from "contracts/libraries/Constants.sol";

68:         uint88 dethAmount = uint88(IBridge(bridge).deposit(msg.sender, amount)); // @dev(safe-cast)

87:         uint88 dethAmount = uint88(IBridge(bridge).depositEth{value: msg.value}()); // Assumes 1 ETH = 1 DETH

113:                     dethAmount -= fee;

114:                     s.vaultUser[vault][address(this)].ethEscrowed += fee;

139:         s.vaultUser[vault][address(this)].ethEscrowed -= dethAmount;

140:         s.vault[vault].dethTotal -= dethAmount;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

```solidity
File: contracts/facets/ExitShortFacet.sol

4: import {U256, U80, U88} from "contracts/libraries/PRBMathHelper.sol";

6: import {IDiamond} from "interfaces/IDiamond.sol";

8: import {Modifiers} from "contracts/libraries/AppStorage.sol";

9: import {Errors} from "contracts/libraries/Errors.sol";

10: import {Events} from "contracts/libraries/Events.sol";

11: import {STypes, MTypes, SR} from "contracts/libraries/DataTypes.sol";

12: import {LibAsset} from "contracts/libraries/LibAsset.sol";

13: import {LibOrders} from "contracts/libraries/LibOrders.sol";

14: import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";

15: import {LibSRMin} from "contracts/libraries/LibSRMin.sol";

56:         Asset.ercDebt -= buybackAmount;

60:             s.vaultUser[Asset.vault][msg.sender].ethEscrowed += collateral;

64:             short.ercDebt -= buybackAmount;

105:             AssetUser.ercEscrowed -= buybackAmount;

108:         Asset.ercDebt -= buybackAmount;

112:             s.vaultUser[Asset.vault][msg.sender].ethEscrowed += collateral;

117:             short.ercDebt -= buybackAmount;

183:         VaultUser.ethEscrowed += e.collateral;

189:         e.ercFilled = e.buybackAmount - e.ercAmountLeft;

190:         Asset.ercDebt -= e.ercFilled;

191:         s.assetUser[e.asset][msg.sender].ercEscrowed -= e.ercFilled;

197:             LibShortRecord.deleteShortRecord(e.asset, msg.sender, id); // prevent reentrancy

199:             short.collateral -= e.ethFilled;

200:             short.ercDebt -= e.ercFilled;

207:             VaultUser.ethEscrowed -= e.collateral - e.ethFilled;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

```solidity
File: contracts/facets/RedemptionFacet.sol

4: import {U256, U104, U88, U80, U64, U32} from "contracts/libraries/PRBMathHelper.sol";

6: import {Errors} from "contracts/libraries/Errors.sol";

7: import {Events} from "contracts/libraries/Events.sol";

8: import {Modifiers} from "contracts/libraries/AppStorage.sol";

9: import {STypes, MTypes, SR} from "contracts/libraries/DataTypes.sol";

10: import {LibAsset} from "contracts/libraries/LibAsset.sol";

11: import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";

12: import {LibOracle} from "contracts/libraries/LibOracle.sol";

13: import {LibOrders} from "contracts/libraries/LibOrders.sol";

14: import {LibBytes} from "contracts/libraries/LibBytes.sol";

15: import {C} from "contracts/libraries/Constants.sol";

17: import {SSTORE2} from "solmate/utils/SSTORE2.sol";

18: import {console} from "contracts/libraries/console.sol";

76:         for (uint8 i = 0; i < proposalInput.length; i++) {

94:             if (p.totalAmountProposed + currentSR.ercDebt <= redemptionAmount) {

97:                 p.amountProposed = redemptionAmount - p.totalAmountProposed;

99:                 if (currentSR.ercDebt - p.amountProposed < minShortErc) break;

119:             currentSR.collateral -= p.colRedeemed;

120:             currentSR.ercDebt -= p.amountProposed;

122:             p.totalAmountProposed += p.amountProposed;

123:             p.totalColRedeemed += p.colRedeemed;

137:             p.redemptionCounter++;

138:             if (redemptionAmount - p.totalAmountProposed < minShortErc) break;

147:         redeemerAssetUser.ercEscrowed -= p.totalAmountProposed;

150:         Asset.ercDebt -= p.totalAmountProposed;

158:         +-------+------------+

160:         +-------+------------+

167:         +-------+------------+

170:         Using simple y = mx + b formula

172:         where x = currentCR - previousCR

173:         m = (y2-y1)/(x2-x1)

181:             redeemerAssetUser.timeToDispute = protocolTime + uint32((m.mul(p.currentCR - 1.7 ether) + 3 ether) * 1 hours / 1 ether);

185:                 protocolTime + uint32((m.mul(p.currentCR - 1.5 ether) + 1.5 ether) * 1 hours / 1 ether);

189:                 protocolTime + uint32((m.mul(p.currentCR - 1.3 ether) + 0.75 ether) * 1 hours / 1 ether);

193:                 protocolTime + uint32((m.mul(p.currentCR - 1.2 ether) + C.ONE_THIRD) * 1 hours / 1 ether);

196:             redeemerAssetUser.timeToDispute = protocolTime + uint32(m.mul(p.currentCR - 1.1 ether) * 1 hours / 1 ether);

207:         VaultUser.ethEscrowed -= redemptionFee;

240:         for (uint256 i = 0; i < decodedProposalData.length; i++) {

257:         if (disputeCR < incorrectProposal.CR && disputeSR.updatedAt + C.DISPUTE_REDEMPTION_BUFFER <= redeemerAssetUser.timeProposed)

261:             for (uint256 i = incorrectIndex; i < decodedProposalData.length; i++) {

265:                 currentSR.collateral += currentProposal.colRedeemed;

266:                 currentSR.ercDebt += currentProposal.ercDebtRedeemed;

268:                 d.incorrectCollateral += currentProposal.colRedeemed;

269:                 d.incorrectErcDebt += currentProposal.ercDebtRedeemed;

272:             s.vault[Asset.vault].dethCollateral += d.incorrectCollateral;

273:             Asset.dethCollateral += d.incorrectCollateral;

274:             Asset.ercDebt += d.incorrectErcDebt;

288:                 LibOrders.max(LibAsset.callerFeePct(d.asset), (currentProposal.CR - disputeCR).div(currentProposal.CR)), 0.33 ether

294:             redeemerAssetUser.ercEscrowed += (d.incorrectErcDebt - penaltyAmt);

295:             s.assetUser[d.asset][msg.sender].ercEscrowed += penaltyAmt;

319:         for (uint256 i = 0; i < decodedProposalData.length; i++) {

321:             totalColRedeemed += currentProposal.colRedeemed;

329:         redeemerVaultUser.ethEscrowed += totalColRedeemed;

356:             LibBytes.readProposalData(redeemerAssetUser.SSTORE2Pointer, claimIndex + 1);

372:             s.vaultUser[vault][shorter].ethEscrowed += collateral;

386:         uint256 secondsPassed = uint256((protocolTime - Asset.lastRedemptionTime)) * 1 ether;

390:         uint104 totalAssetErcDebt = (ercDebtRedeemed + Asset.ercDebt).mulU104(C.BETA);

393:         uint256 newBaseRate = decayedBaseRate + redeemedDUSDFraction;

394:         newBaseRate = LibOrders.min(newBaseRate, 1 ether); // cap baseRate at a maximum of 100%

395:         assert(newBaseRate > 0); // Base rate is always non-zero after redemption

399:         uint256 redemptionRate = LibOrders.min((Asset.baseRate + 0.005 ether), 1 ether);

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/facets/ShortOrdersFacet.sol

4: import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

6: import {Errors} from "contracts/libraries/Errors.sol";

7: import {STypes, MTypes, O, SR} from "contracts/libraries/DataTypes.sol";

8: import {Modifiers} from "contracts/libraries/AppStorage.sol";

9: import {LibOrders} from "contracts/libraries/LibOrders.sol";

10: import {LibAsset} from "contracts/libraries/LibAsset.sol";

11: import {LibOracle} from "contracts/libraries/LibOracle.sol";

12: import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";

13: import {LibSRRecovery} from "contracts/libraries/LibSRRecovery.sol";

14: import {C} from "contracts/libraries/Constants.sol";

51:         if ((shortOrderCR + C.BID_CR) < Asset.initialCR || cr >= C.CRATIO_MAX_INITIAL) {

56:         p.minShortErc = cr < 1 ether ? LibAsset.minShortErc(asset).mul(1 ether + cr.inv()) : LibAsset.minShortErc(asset);

70:         incomingShort.shortOrderCR = shortOrderCR; // 170 -> 1.70x

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ShortOrdersFacet.sol)

```solidity
File: contracts/libraries/LibBridgeRouter.sol

4: import {IBridge} from "contracts/interfaces/IBridge.sol";

6: import {STypes} from "contracts/libraries/DataTypes.sol";

7: import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";

8: import {OracleLibrary} from "contracts/libraries/UniswapOracleLibrary.sol";

9: import {C, VAULT} from "contracts/libraries/Constants.sol";

10: import {Errors} from "contracts/libraries/Errors.sol";

12: import {U256, U88} from "contracts/libraries/PRBMathHelper.sol";

27:                 VaultUser.bridgeCreditReth += amount;

29:                 VaultUser.bridgeCreditSteth += amount;

33:         VaultUser.ethEscrowed += amount;

34:         s.vault[vault].dethTotal += amount;

50:                 VaultUser.bridgeCreditReth -= amount;

55:             amount -= creditReth;

64:                         VaultUser.bridgeCreditSteth -= amount;

68:                         return amount - creditSteth;

80:                 VaultUser.bridgeCreditSteth -= amount;

85:             amount -= creditSteth;

94:                         VaultUser.bridgeCreditReth -= amount;

98:                         return amount - creditReth;

127:                 return factorReth.div(factorSteth) - 1 ether;

133:                 return factorSteth.div(factorReth) - 1 ether;

161:                     VaultUserFrom.bridgeCreditReth -= collateral;

162:                     VaultUserTo.bridgeCreditReth += collateral;

165:                     VaultUserTo.bridgeCreditReth += creditReth;

170:                     VaultUserFrom.bridgeCreditSteth -= collateral;

171:                     VaultUserTo.bridgeCreditSteth += collateral;

174:                     VaultUserTo.bridgeCreditSteth += creditSteth;

178:                 uint88 creditTotal = creditReth + creditSteth;

182:                     VaultUserFrom.bridgeCreditReth -= creditReth;

183:                     VaultUserFrom.bridgeCreditSteth -= creditSteth;

188:                 VaultUserTo.bridgeCreditReth += creditReth;

189:                 VaultUserTo.bridgeCreditSteth += creditSteth;

196:         s.vaultUser[vault][msg.sender].ethEscrowed -= (amount + fee);

197:         s.vault[vault].dethTotal -= amount;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBridgeRouter.sol)

```solidity
File: contracts/libraries/LibBytes.sol

4: import {MTypes} from "contracts/libraries/DataTypes.sol";

5: import {SSTORE2} from "solmate/utils/SSTORE2.sol";

18:         for (uint256 i = 0; i < slateLength; i++) {

20:             uint256 offset = i * 51 + 32;

22:             address shorter; // bytes20

23:             uint8 shortId; // bytes1

24:             uint64 CR; // bytes8

25:             uint88 ercDebtRedeemed; // bytes11

26:             uint88 colRedeemed; // bytes11

32:                 shorter := shr(96, fullWord) // 0x60 = 96 (256-160)

34:                 shortId := and(0xff, shr(88, fullWord)) // 0x58 = 88 (96-8), mask of bytes1 = 0xff * 1

36:                 CR := and(0xffffffffffffffff, shr(24, fullWord)) // 0x18 = 24 (88-64), mask of bytes8 = 0xff * 8

38:                 fullWord := mload(add(slate, add(offset, 29))) // (29 offset)

40:                 ercDebtRedeemed := shr(168, fullWord) // (256-88 = 168)

42:                 colRedeemed := add(0xffffffffffffffffffffff, shr(80, fullWord)) // (256-88-88 = 80), mask of bytes11 = 0xff * 11

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBytes.sol)

```solidity
File: contracts/libraries/LibOracle.sol

4: import {U256} from "contracts/libraries/PRBMathHelper.sol";

6: import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

7: import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

8: import {IDiamond} from "interfaces/IDiamond.sol";

9: import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";

10: import {C} from "contracts/libraries/Constants.sol";

11: import {LibOrders} from "contracts/libraries/LibOrders.sol";

12: import {Errors} from "contracts/libraries/Errors.sol";

30:                 uint256 basePriceInEth = basePrice > 0 ? uint256(basePrice * C.BASE_ORACLE_DECIMALS).inv() : 0;

63:                 uint256 priceInEth = uint256(price * C.BASE_ORACLE_DECIMALS).mul(twapInv);

77:             || block.timestamp > 2 hours + timeStamp;

79:             chainlinkPriceInEth > protocolPrice ? chainlinkPriceInEth - protocolPrice : protocolPrice - chainlinkPriceInEth;

93:                 uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);

95:                 uint256 twapDiff = twapPriceInEth > protocolPrice ? twapPriceInEth - protocolPrice : protocolPrice - twapPriceInEth;

141:         uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);

146:     @dev C.HEAD to marks the start/end of the linked list, so the only properties needed are id/nextId/prevId.

169:         if (LibOrders.getOffsetTime() - getTime(asset) < 15 minutes) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

4: import {U256, U104, U80, U88, U16} from "contracts/libraries/PRBMathHelper.sol";

6: import {IDiamond} from "interfaces/IDiamond.sol";

8: import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";

9: import {STypes, MTypes, O, SR} from "contracts/libraries/DataTypes.sol";

10: import {Errors} from "contracts/libraries/Errors.sol";

11: import {Events} from "contracts/libraries/Events.sol";

12: import {LibAsset} from "contracts/libraries/LibAsset.sol";

13: import {LibOracle} from "contracts/libraries/LibOracle.sol";

14: import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";

15: import {LibVault} from "contracts/libraries/LibVault.sol";

16: import {C} from "contracts/libraries/Constants.sol";

32:         return uint32(block.timestamp - C.STARTING_TIME); // @dev(safe-cast)

36:         return (uint256(cr) * 1 ether) / C.TWO_DECIMAL_PLACES;

44:         uint32 timeTillMatch = getOffsetTime() - order.creationTime;

47:             uint88 shares = eth * (timeTillMatch / 1 days);

48:             matchTotal.dittoMatchedShares += shares;

51:             s.vaultUser[vault][order.addr].dittoMatchedShares += shares;

64:             size++;

69:         currentId = orders[asset][C.HEAD].nextId; // reset currentId

71:         for (uint256 i = 0; i < size; i++) {

100:         s.vaultUser[vault][order.addr].ethEscrowed -= eth;

118:         s.assetUser[asset][order.addr].ercEscrowed -= order.ercAmount;

143:         s.vaultUser[vault][order.addr].ethEscrowed -= eth;

210:             s.asset[asset].orderIdCounter += 1;

584:                     incomingAsk.ercAmount -= highestBid.ercAmount;

604:                         highestBid.ercAmount -= incomingAsk.ercAmount;

656:         s.assetUser[asset][asker].ercEscrowed -= matchTotal.fillErc;

657:         s.vaultUser[vault][asker].ethEscrowed += matchTotal.fillEth;

658:         s.vault[vault].dittoMatchedShares += matchTotal.dittoMatchedShares;

674:         s.vaultUser[vault][incomingShort.addr].ethEscrowed -= matchTotal.colUsed;

675:         matchTotal.fillEth += matchTotal.colUsed;

690:         Vault.dittoMatchedShares += matchTotal.dittoMatchedShares;

691:         Vault.dethCollateral += matchTotal.fillEth;

692:         Asset.dethCollateral += matchTotal.fillEth;

693:         Asset.ercDebt += matchTotal.fillErc;

718:             matchTotal.colUsed += incomingSell.price.mulU88(fillErc).mulU88(LibOrders.convertCR(incomingSell.shortOrderCR));

720:         matchTotal.fillErc += fillErc;

721:         matchTotal.fillEth += fillEth;

725:         s.assetUser[asset][highestBid.addr].ercEscrowed += fillErc;

734:             return; // no need to update startingShortId

746:                     ++i;

792:             orderPriceGtThreshold = (incomingOrder.price - savedPrice).div(savedPrice) > 0.005 ether;

794:             orderPriceGtThreshold = (savedPrice - incomingOrder.price).div(savedPrice) > 0.005 ether;

804:         uint256 timeDiff = getOffsetTime() - LibOracle.getTime(asset);

832:         for (uint256 i; i < orderHintArray.length; i++) {

863:         s.vaultUser[vault][bid.addr].ethEscrowed += eth;

877:         s.assetUser[asset][ask.addr].ercEscrowed += ask.ercAmount;

907:                 uint88 debtDiff = minShortErc - shortRecord.ercDebt;

924:                     Vault.dethCollateral += collateralDiff;

925:                     Asset.dethCollateral += collateralDiff;

926:                     Asset.ercDebt += debtDiff;

929:                     eth -= collateralDiff;

932:                 s.assetUser[asset][shorter].ercEscrowed += debtDiff;

938:         s.vaultUser[vault][shorter].ethEscrowed += eth;

965:             uint256 discountPct = max(0.01 ether, min(((savedPrice - price).div(savedPrice)), 0.04 ether));

968:             Vault.dethTitheMod = (C.MAX_TITHE - Vault.dethTithePercent).mulU16(discountPct.div(0.04 ether));

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

```solidity
File: contracts/libraries/LibSRMin.sol

4: import {STypes, SR} from "contracts/libraries/DataTypes.sol";

5: import {Errors} from "contracts/libraries/Errors.sol";

6: import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";

7: import {LibAsset} from "contracts/libraries/LibAsset.sol";

8: import {LibOrders} from "contracts/libraries/LibOrders.sol";

59:                 if (shortOrder.ercAmount + shortRecord.ercDebt < minShortErc) revert Errors.CannotLeaveDustAmount();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRMin.sol)

```solidity
File: contracts/libraries/LibSRRecovery.sol

4: import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";

5: import {U256, U88, U80} from "contracts/libraries/PRBMathHelper.sol";

7: import {LibAsset} from "contracts/libraries/LibAsset.sol";

8: import {STypes} from "contracts/libraries/DataTypes.sol";

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRRecovery.sol)

```solidity
File: contracts/libraries/LibSRTransfer.sol

4: import {STypes, SR} from "contracts/libraries/DataTypes.sol";

5: import {Errors} from "contracts/libraries/Errors.sol";

6: import {AppStorage, appStorage} from "contracts/libraries/AppStorage.sol";

7: import {LibBridgeRouter} from "contracts/libraries/LibBridgeRouter.sol";

8: import {LibOrders} from "contracts/libraries/LibOrders.sol";

9: import {LibShortRecord} from "contracts/libraries/LibShortRecord.sol";

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRTransfer.sol)

```solidity
File: contracts/libraries/UniswapOracleLibrary.sol

6: import {Errors} from "contracts/libraries/Errors.sol";

7: import {TickMath} from "contracts/libraries/UniswapTickMath.sol";

8: import {U256} from "contracts/libraries/PRBMathHelper.sol";

37:             uint256 ratioX192 = uint256(sqrtRatioX96) * sqrtRatioX96;

61:         int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

62:         int24 tick = int24(tickCumulativesDelta / int32(secondsAgo));

66:             tick--;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol)

### <a name="GAS-7"></a>[GAS-7] Use Custom Errors instead of Revert Strings to save Gas

Custom errors are available from solidity version 0.8.4. Custom errors save [**~50 gas**](https://gist.github.com/IllIllI000/ad1bd0d29a0101b25e57c293b4b0c746) each time they're hit by [avoiding having to allocate and store the revert string](https://blog.soliditylang.org/2021/04/21/custom-errors/#errors-in-depth). Not defining the strings also save deployment gas

Additionally, custom errors can be used inside and outside of contracts (including interfaces and libraries).

Source: <https://blog.soliditylang.org/2021/04/21/custom-errors/>:

> Starting from [Solidity v0.8.4](https://github.com/ethereum/solidity/releases/tag/v0.8.4), there is a convenient and gas-efficient way to explain to users why an operation failed through the use of custom errors. Until now, you could already use strings to give more information about failures (e.g., `revert("Insufficient funds.");`), but they are rather expensive, especially when it comes to deploy cost, and it is difficult to use dynamic information in them.

Consider replacing **all revert strings** with custom errors in the solution, and particularly those that have multiple occurrences:

*Instances (1)*:

```solidity
File: contracts/libraries/LibBytes.sol

14:         require(slate.length % 51 == 0, "Invalid data length");

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBytes.sol)

### <a name="GAS-8"></a>[GAS-8] Avoid contract existence checks by using low level calls

Prior to 0.8.10 the compiler inserted extra code, including `EXTCODESIZE` (**100 gas**), to check for contract existence for external function calls. In more recent solidity versions, the compiler will not insert these checks if the external call has a return value. Similar behavior can be achieved in earlier versions by using low-level calls, since low level calls never check for contract existence

*Instances (2)*:

```solidity
File: contracts/libraries/LibOracle.sol

103:                     uint256 wethBal = weth.balanceOf(C.USDC_WETH);

138:         uint256 wethBal = weth.balanceOf(C.USDC_WETH);

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

### <a name="GAS-9"></a>[GAS-9] State variables only set in the constructor should be declared `immutable`

Variables only set in the constructor and never edited afterwards should be marked as immutable, as it would avoid the expensive storage-writing operation in the constructor (around **20 000 gas** per variable) and replace the expensive storage-reading operations (around **2100 gas** per reading) to a less expensive value reading (**3 gas**)

*Instances (3)*:

```solidity
File: contracts/facets/BridgeRouterFacet.sol

30:         rethBridge = _rethBridge;

31:         stethBridge = _stethBridge;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

```solidity
File: contracts/facets/ExitShortFacet.sol

29:         dusd = _dusd;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

### <a name="GAS-10"></a>[GAS-10] Functions guaranteed to revert when called by normal users can be marked `payable`

If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (1)*:

```solidity
File: contracts/facets/BridgeRouterFacet.sol

133:     function withdrawTapp(address bridge, uint88 dethAmount) external onlyDAO {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

### <a name="GAS-11"></a>[GAS-11] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)

Pre-increments and pre-decrements are cheaper.

For a `uint256 i` variable, the following is true with the Optimizer enabled at 10k:

**Increment:**

- `i += 1` is the most expensive form
- `i++` costs 6 gas less than `i += 1`
- `++i` costs 5 gas less than `i++` (11 gas less than `i += 1`)

**Decrement:**

- `i -= 1` is the most expensive form
- `i--` costs 11 gas less than `i -= 1`
- `--i` costs 5 gas less than `i--` (16 gas less than `i -= 1`)

Note that post-increments (or post-decrements) return the old value before incrementing or decrementing, hence the name *post-increment*:

```solidity
uint i = 1;  
uint j = 2;
require(j == i++, "This will be false as i is incremented after the comparison");
```
  
However, pre-increments (or pre-decrements) return the new value:
  
```solidity
uint i = 1;  
uint j = 2;
require(j == ++i, "This will be true as i is incremented before the comparison");
```

In the pre-increment case, the compiler has to create a temporary variable (when used) for returning `1` instead of `2`.

Consider using pre-increments and pre-decrements where they are relevant (meaning: not where post-increments/decrements logic are relevant).

*Saves 5 gas per instance*

*Instances (16)*:

```solidity
File: contracts/facets/BidOrdersFacet.sol

366:          +----------------+-------------------------+--------------------------+

368:          +----------------+-------------------------+--------------------------+

372:          +----------------+-------------------------+--------------------------+

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)

```solidity
File: contracts/facets/RedemptionFacet.sol

76:         for (uint8 i = 0; i < proposalInput.length; i++) {

137:             p.redemptionCounter++;

158:         +-------+------------+

160:         +-------+------------+

167:         +-------+------------+

240:         for (uint256 i = 0; i < decodedProposalData.length; i++) {

261:             for (uint256 i = incorrectIndex; i < decodedProposalData.length; i++) {

319:         for (uint256 i = 0; i < decodedProposalData.length; i++) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibBytes.sol

18:         for (uint256 i = 0; i < slateLength; i++) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBytes.sol)

```solidity
File: contracts/libraries/LibOrders.sol

64:             size++;

71:         for (uint256 i = 0; i < size; i++) {

832:         for (uint256 i; i < orderHintArray.length; i++) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

```solidity
File: contracts/libraries/UniswapOracleLibrary.sol

66:             tick--;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol)

### <a name="GAS-12"></a>[GAS-12] Increments/decrements can be unchecked in for-loops

In Solidity 0.8+, there's a default overflow check on unsigned integers. It's possible to uncheck this in for-loops and save some gas at each iteration, but at the cost of some code readability, as this uncheck cannot be made inline.

[ethereum/solidity#10695](https://github.com/ethereum/solidity/issues/10695)

The change would be:

```diff
- for (uint256 i; i < numIterations; i++) {
+ for (uint256 i; i < numIterations;) {
 // ...  
+   unchecked { ++i; }
}  
```

These save around **25 gas saved** per instance.

The same can be applied with decrements (which should use `break` when `i == 0`).

The risk of overflow is non-existent for `uint256`.

*Instances (7)*:

```solidity
File: contracts/facets/RedemptionFacet.sol

76:         for (uint8 i = 0; i < proposalInput.length; i++) {

240:         for (uint256 i = 0; i < decodedProposalData.length; i++) {

261:             for (uint256 i = incorrectIndex; i < decodedProposalData.length; i++) {

319:         for (uint256 i = 0; i < decodedProposalData.length; i++) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibBytes.sol

18:         for (uint256 i = 0; i < slateLength; i++) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBytes.sol)

```solidity
File: contracts/libraries/LibOrders.sol

71:         for (uint256 i = 0; i < size; i++) {

832:         for (uint256 i; i < orderHintArray.length; i++) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

### <a name="GAS-13"></a>[GAS-13] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (12)*:

```solidity
File: contracts/facets/BidOrdersFacet.sol

292:         if (b.dustAskId > 0) {

294:         } else if (b.dustShortId > 0) {

299:         if (matchTotal.shortFillEth > 0) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)

```solidity
File: contracts/facets/BridgeRouterFacet.sol

109:             if (dethAssessable > 0) {

111:                 if (withdrawalFeePct > 0) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

```solidity
File: contracts/facets/RedemptionFacet.sol

277:             if (incorrectIndex > 0) {

395:         assert(newBaseRate > 0); // Base rate is always non-zero after redemption

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibOracle.sol

30:                 uint256 basePriceInEth = basePrice > 0 ? uint256(basePrice * C.BASE_ORACLE_DECIMALS).inv() : 0;

80:         bool priceDeviation = protocolPrice > 0 && chainlinkDiff.div(protocolPrice) > 0.5 ether;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

792:             orderPriceGtThreshold = (incomingOrder.price - savedPrice).div(savedPrice) > 0.005 ether;

794:             orderPriceGtThreshold = (savedPrice - incomingOrder.price).div(savedPrice) > 0.005 ether;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

```solidity
File: contracts/libraries/LibSRRecovery.sol

28:             if (Asset.ercDebt > 0) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRRecovery.sol)

### <a name="GAS-14"></a>[GAS-14] `internal` functions not called by the contract should be removed

If the functions are required by an interface, the contract should inherit from that interface and use the `override` keyword

*Instances (24)*:

```solidity
File: contracts/libraries/LibBridgeRouter.sol

20:     function addDeth(uint256 vault, uint256 bridgePointer, uint88 amount) internal {

37:     function assessDeth(uint256 vault, uint256 bridgePointer, uint88 amount, address rethBridge, address stethBridge)

111:     function withdrawalFeePct(uint256 bridgePointer, address rethBridge, address stethBridge) internal view returns (uint256 fee) {

141:     function transferBridgeCredit(address asset, address from, address to, uint88 collateral) internal {

194:     function removeDeth(uint256 vault, uint88 amount, uint88 fee) internal {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBridgeRouter.sol)

```solidity
File: contracts/libraries/LibBytes.sol

11:     function readProposalData(address SSTORE2Pointer, uint8 slateLength) internal view returns (MTypes.ProposalData[] memory) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBytes.sol)

```solidity
File: contracts/libraries/LibOracle.sol

149:     function setPriceAndTime(address asset, uint256 oraclePrice, uint32 oracleTime) internal {

168:     function getSavedOrSpotOraclePrice(address asset) internal view returns (uint256) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

35:     function convertCR(uint16 cr) internal pure returns (uint256) {

55:     function currentOrders(mapping(address => mapping(uint16 => STypes.Order)) storage orders, address asset)

78:     function isShort(STypes.Order memory order) internal pure returns (bool) {

82:     function addBid(address asset, STypes.Order memory order, MTypes.OrderHint[] memory orderHintArray) internal {

499:     function updateSellOrdersOnMatch(address asset, MTypes.BidMatchAlgo memory b) internal {

556:     function sellMatchAlgo(

783:     function updateOracleAndStartingShortViaThreshold(

803:     function updateOracleAndStartingShortViaTimeBidOnly(address asset, uint16[] memory shortHintArray) internal {

868:     function cancelAsk(address asset, uint16 id) internal {

882:     function cancelShort(address asset, uint16 id) internal {

955:     function handlePriceDiscount(address asset, uint80 price) internal {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

```solidity
File: contracts/libraries/LibSRMin.sol

13:     function checkCancelShortOrder(address asset, SR initialStatus, uint16 shortOrderId, uint8 shortRecordId, address shorter)

36:     function checkShortMinErc(address asset, SR initialStatus, uint16 shortOrderId, uint8 shortRecordId, address shorter)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRMin.sol)

```solidity
File: contracts/libraries/LibSRRecovery.sol

17:     function checkRecoveryModeViolation(address asset, uint256 shortRecordCR, uint256 oraclePrice)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRRecovery.sol)

```solidity
File: contracts/libraries/LibSRTransfer.sol

14:     function transferShortRecord(address from, address to, uint40 tokenId) internal {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRTransfer.sol)

```solidity
File: contracts/libraries/UniswapOracleLibrary.sol

47:     function estimateTWAP(uint128 amountIn, uint32 secondsAgo, address pool, address baseToken, address quoteToken)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol)

## Non Critical Issues

| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Missing checks for `address(0)` when assigning values to address state variables | 3 |
| [NC-2](#NC-2) | Array indices should be referenced via `enum`s rather than via numeric literals | 3 |
| [NC-3](#NC-3) | `require()` should be used instead of `assert()` | 2 |
| [NC-4](#NC-4) | `constant`s should be defined rather than using magic numbers | 18 |
| [NC-5](#NC-5) | Control structures do not follow the Solidity Style Guide | 79 |
| [NC-6](#NC-6) | Dangerous `while(true)` loop | 3 |
| [NC-7](#NC-7) | Delete rogue `console.log` imports | 1 |
| [NC-8](#NC-8) | Function ordering does not follow the Solidity style guide | 3 |
| [NC-9](#NC-9) | Functions should not be longer than 50 lines | 65 |
| [NC-10](#NC-10) | Change int to int256 | 3 |
| [NC-11](#NC-11) | Interfaces should be defined in separate files from their usage | 1 |
| [NC-12](#NC-12) | Lack of checks in setters | 1 |
| [NC-13](#NC-13) | Incomplete NatSpec: `@param` is missing on actually documented functions | 3 |
| [NC-14](#NC-14) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 5 |
| [NC-15](#NC-15) | Consider using named mappings | 12 |
| [NC-16](#NC-16) | Adding a `return` statement when the function defines a named return variable, is redundant | 46 |
| [NC-17](#NC-17) | `require()` / `revert()` statements should have descriptive reason strings | 57 |
| [NC-18](#NC-18) | Take advantage of Custom Error's return value property | 57 |
| [NC-19](#NC-19) | Internal and private variables and functions names should begin with an underscore | 62 |
| [NC-20](#NC-20) | Constants should be defined rather than using magic numbers | 6 |
| [NC-21](#NC-21) | Variables need not be initialized to zero | 6 |

### <a name="NC-1"></a>[NC-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (3)*:

```solidity
File: contracts/facets/BridgeRouterFacet.sol

30:         rethBridge = _rethBridge;

31:         stethBridge = _stethBridge;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

```solidity
File: contracts/facets/ExitShortFacet.sol

29:         dusd = _dusd;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

### <a name="NC-2"></a>[NC-2] Array indices should be referenced via `enum`s rather than via numeric literals

*Instances (3)*:

```solidity
File: contracts/libraries/UniswapOracleLibrary.sol

55:         secondsAgos[0] = secondsAgo;

56:         secondsAgos[1] = 0;

61:         int56 tickCumulativesDelta = tickCumulatives[1] - tickCumulatives[0];

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol)

### <a name="NC-3"></a>[NC-3] `require()` should be used instead of `assert()`

Prior to solidity version 0.8.0, hitting an assert consumes the **remainder of the transaction's available gas** rather than returning it, as `require()`/`revert()` do. `assert()` should be avoided even past solidity version 0.8.0 as its [documentation](https://docs.soliditylang.org/en/v0.8.14/control-structures.html#panic-via-assert-and-error-via-require) states that "The assert function creates an error of type Panic(uint256). ... Properly functioning code should never create a Panic, not even on invalid external input. If this happens, then there is a bug in your contract which you should fix. Additionally, a require statement (or a custom error) are more friendly in terms of understanding what happened."

*Instances (2)*:

```solidity
File: contracts/facets/RedemptionFacet.sol

395:         assert(newBaseRate > 0); // Base rate is always non-zero after redemption

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibSRMin.sol

26:                 assert(shortRecord.status != SR.PartialFill);

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRMin.sol)

### <a name="NC-4"></a>[NC-4] `constant`s should be defined rather than using magic numbers

Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (18)*:

```solidity
File: contracts/facets/RedemptionFacet.sol

165:         | 1.7   |     3      |

166:         | 2.0   |     6      |

181:             redeemerAssetUser.timeToDispute = protocolTime + uint32((m.mul(p.currentCR - 1.7 ether) + 3 ether) * 1 hours / 1 ether);

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibBridgeRouter.sol

116:         uint256 unitRethTWAP = OracleLibrary.estimateTWAP(1 ether, 30 minutes, VAULT.RETH_WETH, VAULT.RETH, C.WETH);

120:         uint256 unitWstethTWAP = OracleLibrary.estimateTWAP(1 ether, 30 minutes, VAULT.WSTETH_WETH, VAULT.WSTETH, C.WETH);

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBridgeRouter.sol)

```solidity
File: contracts/libraries/LibBytes.sol

14:         require(slate.length % 51 == 0, "Invalid data length");

20:             uint256 offset = i * 51 + 32;

38:                 fullWord := mload(add(slate, add(offset, 29))) // (29 offset)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBytes.sol)

```solidity
File: contracts/libraries/LibOracle.sol

77:             || block.timestamp > 2 hours + timeStamp;

87:             try IDiamond(payable(address(this))).estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 30 minutes) returns (uint256 twapPrice)

104:                     if (wethBal < 100 ether) {

133:         uint256 twapPrice = IDiamond(payable(address(this))).estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 30 minutes);

139:         if (wethBal < 100 ether) revert Errors.InsufficientEthInLiquidityPool();

169:         if (LibOrders.getOffsetTime() - getTime(asset) < 15 minutes) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

805:         if (timeDiff >= 15 minutes) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

```solidity
File: contracts/libraries/UniswapOracleLibrary.sol

39:                 baseToken < quoteToken ? U256.mulDiv(ratioX192, baseAmount, 1 << 192) : U256.mulDiv(1 << 192, baseAmount, ratioX192);

41:             uint256 ratioX128 = U256.mulDiv(sqrtRatioX96, sqrtRatioX96, 1 << 64);

43:                 baseToken < quoteToken ? U256.mulDiv(ratioX128, baseAmount, 1 << 128) : U256.mulDiv(1 << 128, baseAmount, ratioX128);

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol)

### <a name="NC-5"></a>[NC-5] Control structures do not follow the Solidity Style Guide

See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (79)*:

```solidity
File: contracts/facets/BidOrdersFacet.sol

8: import {Modifiers} from "contracts/libraries/AppStorage.sol";

87:         if (eth < LibAsset.minBidEth(asset)) revert Errors.OrderUnderMinimumSize();

90:         if (s.vaultUser[Asset.vault][sender].ethEscrowed < eth) revert Errors.InsufficientETHEscrowed();

378:         As such, it will be used as the last Id matched (if moving backwards ONLY)

385:         If the bid matches BACKWARDS ONLY, lets say to (ID2), then the linked list will look like this after execution

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)

```solidity
File: contracts/facets/BridgeRouterFacet.sol

8: import {Modifiers} from "contracts/libraries/AppStorage.sol";

64:         if (amount < C.MIN_DEPOSIT) revert Errors.UnderMinimumDeposit();

83:         if (msg.value < C.MIN_DEPOSIT) revert Errors.UnderMinimumDeposit();

102:         if (dethAmount == 0) revert Errors.ParameterIsZero();

134:         if (dethAmount == 0) revert Errors.ParameterIsZero();

164:             if (vault == 0) revert Errors.InvalidBridge();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

```solidity
File: contracts/facets/ExitShortFacet.sol

8: import {Modifiers} from "contracts/libraries/AppStorage.sol";

53:         if (buybackAmount > ercDebt || buybackAmount == 0) revert Errors.InvalidBuyback();

99:         if (buybackAmount == 0 || buybackAmount > ercDebt) revert Errors.InvalidBuyback();

103:             if (AssetUser.ercEscrowed < buybackAmount) revert Errors.InsufficientERCEscrowed();

174:         if (e.buybackAmount == 0 || e.buybackAmount > e.ercDebt) revert Errors.InvalidBuyback();

178:             if (ethAmount > e.collateral) revert Errors.InsufficientCollateral();

188:         if (e.ethFilled == 0) revert Errors.ExitShortPriceTooLow();

201:             if (short.ercDebt < LibAsset.minShortErc(asset)) revert Errors.CannotLeaveDustAmount();

204:             if (getCollateralRatioNonPrice(short) < e.beforeExitCR) revert Errors.PostExitCRLtPreExitCR();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

```solidity
File: contracts/facets/RedemptionFacet.sol

8: import {Modifiers} from "contracts/libraries/AppStorage.sol";

60:         if (proposalInput.length > type(uint8).max) revert Errors.TooManyProposals();

66:         if (redemptionAmount < minShortErc) revert Errors.RedemptionUnderMinShortErc();

68:         if (redeemerAssetUser.ercEscrowed < redemptionAmount) revert Errors.InsufficientERCEscrowed();

71:         if (redeemerAssetUser.SSTORE2Pointer != address(0)) revert Errors.ExistingProposedRedemptions();

85:             if (!validRedemptionSR(currentSR, msg.sender, p.shorter, minShortErc)) continue;

91:             if (p.previousCR > p.currentCR || p.currentCR >= C.MAX_REDEMPTION_CR) continue;

99:                 if (currentSR.ercDebt - p.amountProposed < minShortErc) break;

110:                 if (shortOrder.shortRecordId != p.shortId || shortOrder.addr != p.shorter) revert Errors.InvalidShortOrder();

138:             if (redemptionAmount - p.totalAmountProposed < minShortErc) break;

141:         if (p.totalAmountProposed < minShortErc) revert Errors.RedemptionUnderMinShortErc();

203:         if (redemptionFee > maxRedemptionFee) revert Errors.RedemptionFeeTooHigh();

206:         if (VaultUser.ethEscrowed < redemptionFee) revert Errors.InsufficientETHEscrowed();

227:         if (redeemer == msg.sender) revert Errors.CannotDisputeYourself();

233:         if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();

235:         if (LibOrders.getOffsetTime() >= redeemerAssetUser.timeToDispute) revert Errors.TimeToDisputeHasElapsed();

249:         if (!validRedemptionSR(disputeSR, d.redeemer, disputeShorter, minShortErc)) revert Errors.InvalidRedemption();

257:         if (disputeCR < incorrectProposal.CR && disputeSR.updatedAt + C.DISPUTE_REDEMPTION_BUFFER <= redeemerAssetUser.timeProposed)

312:         if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();

313:         if (LibOrders.getOffsetTime() < redeemerAssetUser.timeToDispute) revert Errors.TimeToDisputeHasNotElapsed();

351:         if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();

352:         if (redeemerAssetUser.timeToDispute > LibOrders.getOffsetTime()) revert Errors.TimeToDisputeHasNotElapsed();

359:         if (claimProposal.shorter != msg.sender && claimProposal.shortId != id) revert Errors.CanOnlyClaimYourShort();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/facets/ShortOrdersFacet.sol

8: import {Modifiers} from "contracts/libraries/AppStorage.sol";

59:         if (ercAmount < p.minShortErc || p.eth < p.minAskEth) revert Errors.OrderUnderMinimumSize();

62:         if (s.vaultUser[Asset.vault][msg.sender].ethEscrowed < p.eth.mul(cr)) revert Errors.InsufficientETHEscrowed();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ShortOrdersFacet.sol)

```solidity
File: contracts/libraries/LibOracle.sol

25:         if (address(oracle) == address(0)) revert Errors.InvalidAsset();

60:                 if (roundID == 0 || price == 0 || timeStamp > block.timestamp) revert Errors.InvalidPrice();

78:         uint256 chainlinkDiff =

80:         bool priceDeviation = protocolPrice > 0 && chainlinkDiff.div(protocolPrice) > 0.5 ether;

95:                 uint256 twapDiff = twapPriceInEth > protocolPrice ? twapPriceInEth - protocolPrice : protocolPrice - twapPriceInEth;

128:         if (invalidFetchData) revert Errors.InvalidPrice();

134:         if (twapPrice == 0) revert Errors.InvalidTwapPrice();

139:         if (wethBal < 100 ether) revert Errors.InsufficientEthInLiquidityPool();

147:     Helper methods are used to set the values of oraclePrice and oracleTime since they are set to different properties

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

231:     function verifyBidId(address asset, uint16 _prevId, uint256 _newPrice, uint16 _nextId)

260:     function verifySellId(

376:         int256 direction = verifyId(orders, asset, hintId, incomingOrder.price, nextId, incomingOrder.orderType);

402:     function verifyId(

413:             return verifySellId(orders, asset, prevId, newPrice, nextId);

415:             return verifyBidId(asset, prevId, newPrice, nextId);

804:         uint256 timeDiff = getOffsetTime() - LibOracle.getTime(asset);

859:         if (orderType == O.Cancelled || orderType == O.Matched) revert Errors.NotActiveOrder();

887:         if (orderType == O.Cancelled || orderType == O.Matched) revert Errors.NotActiveOrder();

907:                 uint88 debtDiff = minShortErc - shortRecord.ercDebt;

911:                     uint88 collateralDiff = shortOrder.price.mulU88(debtDiff).mulU88(LibOrders.convertCR(shortOrder.shortOrderCR));

918:                         collateralDiff,

919:                         debtDiff,

924:                     Vault.dethCollateral += collateralDiff;

925:                     Asset.dethCollateral += collateralDiff;

926:                     Asset.ercDebt += debtDiff;

929:                     eth -= collateralDiff;

932:                 s.assetUser[asset][shorter].ercEscrowed += debtDiff;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

```solidity
File: contracts/libraries/LibSRMin.sol

21:             if (shortOrder.shortRecordId != shortRecordId || shortOrder.addr != shorter) revert Errors.InvalidShortOrder();

48:             if (shortOrder.shortRecordId != shortRecordId || shortOrder.addr != shorter) revert Errors.InvalidShortOrder();

59:                 if (shortOrder.ercAmount + shortRecord.ercDebt < minShortErc) revert Errors.CannotLeaveDustAmount();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRMin.sol)

```solidity
File: contracts/libraries/LibSRTransfer.sol

20:         if (short.status == SR.Closed) revert Errors.OriginalShortRecordCancelled();

21:         if (short.ercDebt == 0) revert Errors.OriginalShortRecordRedeemed();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRTransfer.sol)

```solidity
File: contracts/libraries/UniswapOracleLibrary.sol

52:         if (secondsAgo <= 0) revert Errors.InvalidTWAPSecondsAgo();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol)

### <a name="NC-6"></a>[NC-6] Dangerous `while(true)` loop

Consider using for-loops to avoid all risks of an infinite-loop situation

*Instances (3)*:

```solidity
File: contracts/facets/BidOrdersFacet.sol

139:         while (true) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)

```solidity
File: contracts/libraries/LibOrders.sol

448:         while (true) {

572:         while (true) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

### <a name="NC-7"></a>[NC-7] Delete rogue `console.log` imports

These shouldn't be deployed in production

*Instances (1)*:

```solidity
File: contracts/facets/RedemptionFacet.sol

18: import {console} from "contracts/libraries/console.sol";

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

### <a name="NC-8"></a>[NC-8] Function ordering does not follow the Solidity style guide

According to the [Solidity style guide](https://docs.soliditylang.org/en/v0.8.17/style-guide.html#order-of-functions), functions should be laid out in the following order :`constructor()`, `receive()`, `fallback()`, `external`, `public`, `internal`, `private`, but the cases below do not follow this pattern

*Instances (3)*:

```solidity
File: contracts/facets/RedemptionFacet.sol

1: 
   Current order:
   internal validRedemptionSR
   external proposeRedemption
   external disputeRedemption
   external claimRedemption
   external claimRemainingCollateral
   private _claimRemainingCollateral
   internal calculateRedemptionFee
   
   Suggested order:
   external proposeRedemption
   external disputeRedemption
   external claimRedemption
   external claimRemainingCollateral
   internal validRedemptionSR
   internal calculateRedemptionFee
   private _claimRemainingCollateral

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibOracle.sol

1: 
   Current order:
   internal getOraclePrice
   private baseOracleCircuitBreaker
   private oracleCircuitBreaker
   private twapCircuitBreaker
   internal setPriceAndTime
   internal getTime
   internal getPrice
   internal getSavedOrSpotOraclePrice
   
   Suggested order:
   internal getOraclePrice
   internal setPriceAndTime
   internal getTime
   internal getPrice
   internal getSavedOrSpotOraclePrice
   private baseOracleCircuitBreaker
   private oracleCircuitBreaker
   private twapCircuitBreaker

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

1: 
   Current order:
   internal getOffsetTime
   internal convertCR
   internal increaseSharesOnMatch
   internal currentOrders
   internal isShort
   internal addBid
   internal addAsk
   internal addShort
   private addSellOrder
   private addOrder
   internal verifyBidId
   private verifySellId
   internal cancelOrder
   internal matchOrder
   private _reuseOrderIds
   internal findPrevOfIncomingId
   internal verifyId
   private normalizeOrderType
   internal getOrderId
   internal updateBidOrdersOnMatch
   internal updateSellOrdersOnMatch
   private _updateOrders
   internal sellMatchAlgo
   private matchIncomingSell
   private matchIncomingAsk
   private matchIncomingShort
   internal matchHighestBid
   private _updateOracleAndStartingShort
   internal updateOracleAndStartingShortViaThreshold
   internal updateOracleAndStartingShortViaTimeBidOnly
   internal updateStartingShortIdViaShort
   internal findOrderHintId
   internal cancelBid
   internal cancelAsk
   internal cancelShort
   internal handlePriceDiscount
   internal min
   internal max
   
   Suggested order:
   internal getOffsetTime
   internal convertCR
   internal increaseSharesOnMatch
   internal currentOrders
   internal isShort
   internal addBid
   internal addAsk
   internal addShort
   internal verifyBidId
   internal cancelOrder
   internal matchOrder
   internal findPrevOfIncomingId
   internal verifyId
   internal getOrderId
   internal updateBidOrdersOnMatch
   internal updateSellOrdersOnMatch
   internal sellMatchAlgo
   internal matchHighestBid
   internal updateOracleAndStartingShortViaThreshold
   internal updateOracleAndStartingShortViaTimeBidOnly
   internal updateStartingShortIdViaShort
   internal findOrderHintId
   internal cancelBid
   internal cancelAsk
   internal cancelShort
   internal handlePriceDiscount
   internal min
   internal max
   private addSellOrder
   private addOrder
   private verifySellId
   private _reuseOrderIds
   private normalizeOrderType
   private _updateOrders
   private matchIncomingSell
   private matchIncomingAsk
   private matchIncomingShort
   private _updateOracleAndStartingShort

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

### <a name="NC-9"></a>[NC-9] Functions should not be longer than 50 lines

Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability

*Instances (65)*:

```solidity
File: contracts/facets/BidOrdersFacet.sol

65:     function createForcedBid(address sender, address asset, uint80 price, uint88 ercAmount, uint16[] calldata shortHintArray)

340:     function _getLowestSell(address asset, MTypes.BidMatchAlgo memory b) private view returns (STypes.Order memory lowestSell) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)

```solidity
File: contracts/facets/BridgeRouterFacet.sol

40:     function getDethTotal(uint256 vault) external view nonReentrantView returns (uint256) {

51:     function getBridges(uint256 vault) external view returns (address[] memory) {

63:     function deposit(address bridge, uint88 amount) external nonReentrant {

82:     function depositEth(address bridge) external payable nonReentrant {

101:     function withdraw(address bridge, uint88 dethAmount) external nonReentrant {

133:     function withdrawTapp(address bridge, uint88 dethAmount) external onlyDAO {

148:     function maybeUpdateYield(uint256 vault, uint88 amount) private {

156:     function _getVault(address bridge) private view returns (uint256 vault, uint256 bridgePointer) {

169:     function _ethConversion(uint256 vault, uint88 amount) private view returns (uint88) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

```solidity
File: contracts/facets/ExitShortFacet.sol

41:     function exitShortWallet(address asset, uint8 id, uint88 buybackAmount, uint16 shortOrderId)

87:     function exitShortErcEscrowed(address asset, uint8 id, uint88 buybackAmount, uint16 shortOrderId)

213:     function getCollateralRatioNonPrice(STypes.ShortRecord storage short) internal view returns (uint256 cRatio) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

```solidity
File: contracts/facets/RedemptionFacet.sol

29:     function validRedemptionSR(STypes.ShortRecord storage shortRecord, address proposer, address shorter, uint256 minShortErc)

222:     function disputeRedemption(address asset, address redeemer, uint8 incorrectIndex, address disputeShorter, uint8 disputeShortId)

308:     function claimRedemption(address asset) external isNotFrozen(asset) nonReentrant {

345:     function claimRemainingCollateral(address asset, address redeemer, uint8 claimIndex, uint8 id)

366:     function _claimRemainingCollateral(address asset, uint256 vault, address shorter, uint8 shortId) private {

380:     function calculateRedemptionFee(address asset, uint88 colRedeemed, uint88 ercDebtRedeemed)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibBridgeRouter.sol

20:     function addDeth(uint256 vault, uint256 bridgePointer, uint88 amount) internal {

37:     function assessDeth(uint256 vault, uint256 bridgePointer, uint88 amount, address rethBridge, address stethBridge)

111:     function withdrawalFeePct(uint256 bridgePointer, address rethBridge, address stethBridge) internal view returns (uint256 fee) {

141:     function transferBridgeCredit(address asset, address from, address to, uint88 collateral) internal {

194:     function removeDeth(uint256 vault, uint88 amount, uint88 fee) internal {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBridgeRouter.sol)

```solidity
File: contracts/libraries/LibBytes.sol

11:     function readProposalData(address SSTORE2Pointer, uint8 slateLength) internal view returns (MTypes.ProposalData[] memory) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBytes.sol)

```solidity
File: contracts/libraries/LibOracle.sol

19:     function getOraclePrice(address asset) internal view returns (uint256) {

131:     function twapCircuitBreaker() private view returns (uint256 twapPriceInEth) {

149:     function setPriceAndTime(address asset, uint256 oraclePrice, uint32 oracleTime) internal {

156:     function getTime(address asset) internal view returns (uint256 creationTime) {

162:     function getPrice(address asset) internal view returns (uint80 oraclePrice) {

168:     function getSavedOrSpotOraclePrice(address asset) internal view returns (uint256) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

30:     function getOffsetTime() internal view returns (uint32 timeInSeconds) {

35:     function convertCR(uint16 cr) internal pure returns (uint256) {

40:     function increaseSharesOnMatch(address asset, STypes.Order memory order, MTypes.Match memory matchTotal, uint88 eth) internal {

55:     function currentOrders(mapping(address => mapping(uint16 => STypes.Order)) storage orders, address asset)

78:     function isShort(STypes.Order memory order) internal pure returns (bool) {

82:     function addBid(address asset, STypes.Order memory order, MTypes.OrderHint[] memory orderHintArray) internal {

103:     function addAsk(address asset, STypes.Order memory order, MTypes.OrderHint[] memory orderHintArray) internal {

128:     function addShort(address asset, STypes.Order memory order, MTypes.OrderHint[] memory orderHintArray) internal {

153:     function addSellOrder(STypes.Order memory incomingOrder, address asset, MTypes.OrderHint[] memory orderHintArray) private {

231:     function verifyBidId(address asset, uint16 _prevId, uint256 _newPrice, uint16 _nextId)

289:     function cancelOrder(mapping(address => mapping(uint16 => STypes.Order)) storage orders, address asset, uint16 id) internal {

314:     function matchOrder(mapping(address => mapping(uint16 => STypes.Order)) storage orders, address asset, uint16 id) internal {

420:     function normalizeOrderType(O o) private pure returns (O newO) {

499:     function updateSellOrdersOnMatch(address asset, MTypes.BidMatchAlgo memory b) internal {

628:     function matchIncomingSell(address asset, STypes.Order memory incomingOrder, MTypes.Match memory matchTotal) private {

652:     function matchIncomingAsk(address asset, STypes.Order memory incomingAsk, MTypes.Match memory matchTotal) private {

668:     function matchIncomingShort(address asset, STypes.Order memory incomingShort, MTypes.Match memory matchTotal) private {

728:     function _updateOracleAndStartingShort(address asset, uint16[] memory shortHintArray) private {

783:     function updateOracleAndStartingShortViaThreshold(

803:     function updateOracleAndStartingShortViaTimeBidOnly(address asset, uint16[] memory shortHintArray) internal {

810:     function updateStartingShortIdViaShort(address asset, STypes.Order memory incomingShort) internal {

854:     function cancelBid(address asset, uint16 id) internal {

868:     function cancelAsk(address asset, uint16 id) internal {

882:     function cancelShort(address asset, uint16 id) internal {

955:     function handlePriceDiscount(address asset, uint80 price) internal {

985:     function min(uint256 a, uint256 b) internal pure returns (uint256) {

989:     function max(uint256 a, uint256 b) internal pure returns (uint256) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

```solidity
File: contracts/libraries/LibSRMin.sol

13:     function checkCancelShortOrder(address asset, SR initialStatus, uint16 shortOrderId, uint8 shortRecordId, address shorter)

36:     function checkShortMinErc(address asset, SR initialStatus, uint16 shortOrderId, uint8 shortRecordId, address shorter)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRMin.sol)

```solidity
File: contracts/libraries/LibSRRecovery.sol

17:     function checkRecoveryModeViolation(address asset, uint256 shortRecordCR, uint256 oraclePrice)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRRecovery.sol)

```solidity
File: contracts/libraries/LibSRTransfer.sol

14:     function transferShortRecord(address from, address to, uint40 tokenId) internal {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRTransfer.sol)

```solidity
File: contracts/libraries/UniswapOracleLibrary.sol

28:     function getQuoteAtTick(int24 tick, uint128 baseAmount, address baseToken, address quoteToken)

47:     function estimateTWAP(uint128 amountIn, uint32 secondsAgo, address pool, address baseToken, address quoteToken)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol)

### <a name="NC-10"></a>[NC-10] Change int to int256

Throughout the code base, some variables are declared as `int`. To favor explicitness, consider changing all instances of `int` to `int256`

*Instances (3)*:

```solidity
File: contracts/facets/BidOrdersFacet.sol

389:         Here, (ID1) becomes the "First ID" and the shortHint ID [ID5] was the "LastID"

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)

```solidity
File: contracts/facets/RedemptionFacet.sol

174:         b = previous fixed point (Y)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibOrders.sol

833:             MTypes.OrderHint memory orderHint = orderHintArray[i];

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

### <a name="NC-11"></a>[NC-11] Interfaces should be defined in separate files from their usage

The interfaces below should be defined in separate files, so that it's easier for future projects to import them, and to avoid duplication later on if they need to be used elsewhere in the project

*Instances (1)*:

```solidity
File: contracts/libraries/UniswapOracleLibrary.sol

10: interface IUniswapV3Pool {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol)

### <a name="NC-12"></a>[NC-12] Lack of checks in setters

Be it sanity checks (like checks against `0`-values) or initial setting checks: it's best for Setter functions to have them

*Instances (1)*:

```solidity
File: contracts/libraries/LibOracle.sol

149:     function setPriceAndTime(address asset, uint256 oraclePrice, uint32 oracleTime) internal {
             AppStorage storage s = appStorage();
             s.bids[asset][C.HEAD].ercAmount = uint80(oraclePrice);
             s.bids[asset][C.HEAD].creationTime = oracleTime;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

### <a name="NC-13"></a>[NC-13] Incomplete NatSpec: `@param` is missing on actually documented functions

The following functions are missing `@param` NatSpec comments.

*Instances (3)*:

```solidity
File: contracts/facets/ExitShortFacet.sol

32:     /**
         * @notice Exits a short using shorter's ERC in wallet (i.e.MetaMask)
         * @dev allows for partial exit via buybackAmount
         *
         * @param asset The market that will be impacted
         * @param id Id of short
         * @param buybackAmount Erc amount to buy back
         *
         */
        function exitShortWallet(address asset, uint8 id, uint88 buybackAmount, uint16 shortOrderId)

78:     /**
         * @notice Exits a short using shorter's ERC in balance (ErcEscrowed)
         * @dev allows for partial exit via buybackAmount
         *
         * @param asset The market that will be impacted
         * @param id Id of short
         * @param buybackAmount Erc amount to buy back
         *
         */
        function exitShortErcEscrowed(address asset, uint8 id, uint88 buybackAmount, uint16 shortOrderId)

131:     /**
          * @notice Exits a short by placing bid on market
          * @dev allows for partial exit via buybackAmount
          *
          * @param asset The market that will be impacted
          * @param id Id of short
          * @param buybackAmount Erc amount to buy back
          * @param price Price at which shorter wants to place bid
          * @param shortHintArray Array of hintId for the id to start matching against shorts since you can't match a short < oracle price
          *
          */
         function exitShort(
             address asset,
             uint8 id,
             uint88 buybackAmount,
             uint80 price,
             uint16[] memory shortHintArray,
             uint16 shortOrderId

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

### <a name="NC-14"></a>[NC-14] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor

If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (5)*:

```solidity
File: contracts/facets/RedemptionFacet.sol

85:             if (!validRedemptionSR(currentSR, msg.sender, p.shorter, minShortErc)) continue;

227:         if (redeemer == msg.sender) revert Errors.CannotDisputeYourself();

359:         if (claimProposal.shorter != msg.sender && claimProposal.shortId != id) revert Errors.CanOnlyClaimYourShort();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/facets/ShortOrdersFacet.sol

62:         if (s.vaultUser[Asset.vault][msg.sender].ethEscrowed < p.eth.mul(cr)) revert Errors.InsufficientETHEscrowed();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ShortOrdersFacet.sol)

```solidity
File: contracts/libraries/LibSRMin.sol

23:             if (shorter == msg.sender) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRMin.sol)

### <a name="NC-15"></a>[NC-15] Consider using named mappings

Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (12)*:

```solidity
File: contracts/libraries/LibOrders.sol

55:     function currentOrders(mapping(address => mapping(uint16 => STypes.Order)) storage orders, address asset)

174:         mapping(address => mapping(uint16 => STypes.Order)) storage orders,

261:         mapping(address => mapping(uint16 => STypes.Order)) storage orders,

289:     function cancelOrder(mapping(address => mapping(uint16 => STypes.Order)) storage orders, address asset, uint16 id) internal {

314:     function matchOrder(mapping(address => mapping(uint16 => STypes.Order)) storage orders, address asset, uint16 id) internal {

321:         mapping(address => mapping(uint16 => STypes.Order)) storage orders,

363:         mapping(address => mapping(uint16 => STypes.Order)) storage orders,

403:         mapping(address => mapping(uint16 => STypes.Order)) storage orders,

441:         mapping(address => mapping(uint16 => STypes.Order)) storage orders,

475:         mapping(address => mapping(uint16 => STypes.Order)) storage orders,

533:         mapping(address => mapping(uint16 => STypes.Order)) storage orders,

827:         mapping(address => mapping(uint16 => STypes.Order)) storage orders,

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

### <a name="NC-16"></a>[NC-16] Adding a `return` statement when the function defines a named return variable, is redundant

*Instances (46)*:

```solidity
File: contracts/facets/BidOrdersFacet.sol

26:     /**
         * @notice Creates bid order in market
         * @dev IncomingBid created here instead of BidMatchAlgo to prevent stack too deep
         *
         * @param asset The market that will be impacted
         * @param price Unit price in eth for erc
         * @param ercAmount Amount of erc to buy
         * @param isMarketOrder Boolean for whether the bid is limit or market
         * @param orderHintArray Array of hint ID for gas-optimized sorted placement on market
         * @param shortHintArray Array of hint ID for gas-optimized short matching above oracle price
         *
         * @return ethFilled Amount of eth filled
         * @return ercAmountLeft Amount of erc not matched
         */
        function createBid(
            address asset,
            uint80 price,
            uint88 ercAmount,
            bool isMarketOrder,
            MTypes.OrderHint[] calldata orderHintArray,
            uint16[] calldata shortHintArray
        ) external isNotFrozen(asset) onlyValidAsset(asset) nonReentrant returns (uint88 ethFilled, uint88 ercAmountLeft) {
            LibOrders.updateOracleAndStartingShortViaTimeBidOnly(asset, shortHintArray);
    
            return _createBid(msg.sender, asset, price, ercAmount, isMarketOrder, orderHintArray, shortHintArray);

53:     /**
         * @notice create a bid order for exiting a short, only callable by specific contracts
         *
         * @param sender Address of caller (only for exiting a short)
         * @param asset The market that will be impacted
         * @param price Unit price in eth for erc
         * @param ercAmount Amount of erc to buy
         * @param shortHintArray Array of hint ID for gas-optimized short matching above oracle price
         *
         * @return ethFilled Amount of eth filled
         * @return ercAmountLeft Amount of erc not matched
         */
        function createForcedBid(address sender, address asset, uint80 price, uint88 ercAmount, uint16[] calldata shortHintArray)
            external
            onlyDiamond
            returns (uint88 ethFilled, uint88 ercAmountLeft)
        {
            // @dev leave empty, don't need hint for market buys
            MTypes.OrderHint[] memory orderHintArray;
    
            // @dev update oracle in callers
            return _createBid(sender, asset, price, ercAmount, C.MARKET_ORDER, orderHintArray, shortHintArray);

77:     function _createBid(
            address sender,
            address asset,
            uint80 price,
            uint88 ercAmount,
            bool isMarketOrder,
            MTypes.OrderHint[] memory orderHintArray,
            uint16[] memory shortHintArray
        ) private returns (uint88 ethFilled, uint88 ercAmountLeft) {
            uint256 eth = ercAmount.mul(price);
            if (eth < LibAsset.minBidEth(asset)) revert Errors.OrderUnderMinimumSize();
    
            STypes.Asset storage Asset = s.asset[asset];
            if (s.vaultUser[Asset.vault][sender].ethEscrowed < eth) revert Errors.InsufficientETHEscrowed();
    
            STypes.Order memory incomingBid;
            incomingBid.addr = sender;
            incomingBid.price = price;
            incomingBid.ercAmount = ercAmount;
            incomingBid.id = Asset.orderIdCounter;
            incomingBid.orderType = isMarketOrder ? O.MarketBid : O.LimitBid;
            incomingBid.creationTime = LibOrders.getOffsetTime();
    
            MTypes.BidMatchAlgo memory b;
            b.askId = s.asks[asset][C.HEAD].nextId;
            // @dev setting initial shortId to match "backwards" (See _shortDirectionHandler() below)
            b.shortHintId = b.shortId = Asset.startingShortId;
    
            STypes.Order memory lowestSell = _getLowestSell(asset, b);
            if (incomingBid.price >= lowestSell.price && (lowestSell.orderType == O.LimitAsk || lowestSell.orderType == O.LimitShort)) {
                // @dev if match and match price is gt .5% to saved oracle in either direction, update startingShortId
                LibOrders.updateOracleAndStartingShortViaThreshold(asset, LibOracle.getPrice(asset), incomingBid, shortHintArray);
                b.shortHintId = b.shortId = Asset.startingShortId;
                b.oraclePrice = LibOracle.getPrice(asset);
                return bidMatchAlgo(asset, incomingBid, orderHintArray, b);
            } else {
                // @dev no match, add to market if limit order
                LibOrders.addBid(asset, incomingBid, orderHintArray);
                return (0, ercAmount);

77:     function _createBid(
            address sender,
            address asset,
            uint80 price,
            uint88 ercAmount,
            bool isMarketOrder,
            MTypes.OrderHint[] memory orderHintArray,
            uint16[] memory shortHintArray
        ) private returns (uint88 ethFilled, uint88 ercAmountLeft) {
            uint256 eth = ercAmount.mul(price);
            if (eth < LibAsset.minBidEth(asset)) revert Errors.OrderUnderMinimumSize();
    
            STypes.Asset storage Asset = s.asset[asset];
            if (s.vaultUser[Asset.vault][sender].ethEscrowed < eth) revert Errors.InsufficientETHEscrowed();
    
            STypes.Order memory incomingBid;
            incomingBid.addr = sender;
            incomingBid.price = price;
            incomingBid.ercAmount = ercAmount;
            incomingBid.id = Asset.orderIdCounter;
            incomingBid.orderType = isMarketOrder ? O.MarketBid : O.LimitBid;
            incomingBid.creationTime = LibOrders.getOffsetTime();
    
            MTypes.BidMatchAlgo memory b;
            b.askId = s.asks[asset][C.HEAD].nextId;
            // @dev setting initial shortId to match "backwards" (See _shortDirectionHandler() below)
            b.shortHintId = b.shortId = Asset.startingShortId;
    
            STypes.Order memory lowestSell = _getLowestSell(asset, b);
            if (incomingBid.price >= lowestSell.price && (lowestSell.orderType == O.LimitAsk || lowestSell.orderType == O.LimitShort)) {
                // @dev if match and match price is gt .5% to saved oracle in either direction, update startingShortId
                LibOrders.updateOracleAndStartingShortViaThreshold(asset, LibOracle.getPrice(asset), incomingBid, shortHintArray);
                b.shortHintId = b.shortId = Asset.startingShortId;
                b.oraclePrice = LibOracle.getPrice(asset);
                return bidMatchAlgo(asset, incomingBid, orderHintArray, b);

119:     /**
          * @notice The matching algorithm for bids
          *
          * @param asset The market that will be impacted
          * @param incomingBid Active bid order
          * @param orderHintArray Array of hint ID for gas-optimized sorted placement on market
          * @param b Memory struct used throughout bidMatchAlgo
          *
          * @return ethFilled Amount of eth filled
          * @return ercAmountLeft Amount of erc not matched
          */
         function bidMatchAlgo(
             address asset,
             STypes.Order memory incomingBid,
             MTypes.OrderHint[] memory orderHintArray,
             MTypes.BidMatchAlgo memory b
         ) private returns (uint88 ethFilled, uint88 ercAmountLeft) {
             uint256 minBidEth = LibAsset.minBidEth(asset);
             MTypes.Match memory matchTotal;
     
             while (true) {
                 // @dev Handles scenario when no sells left after partial fill
                 if (b.askId == C.TAIL && b.shortId == C.TAIL) {
                     if (incomingBid.ercAmount.mul(incomingBid.price) >= minBidEth) {
                         LibOrders.addBid(asset, incomingBid, orderHintArray);
                     }
                     return matchIncomingBid(asset, incomingBid, matchTotal, b);

119:     /**
          * @notice The matching algorithm for bids
          *
          * @param asset The market that will be impacted
          * @param incomingBid Active bid order
          * @param orderHintArray Array of hint ID for gas-optimized sorted placement on market
          * @param b Memory struct used throughout bidMatchAlgo
          *
          * @return ethFilled Amount of eth filled
          * @return ercAmountLeft Amount of erc not matched
          */
         function bidMatchAlgo(
             address asset,
             STypes.Order memory incomingBid,
             MTypes.OrderHint[] memory orderHintArray,
             MTypes.BidMatchAlgo memory b
         ) private returns (uint88 ethFilled, uint88 ercAmountLeft) {
             uint256 minBidEth = LibAsset.minBidEth(asset);
             MTypes.Match memory matchTotal;
     
             while (true) {
                 // @dev Handles scenario when no sells left after partial fill
                 if (b.askId == C.TAIL && b.shortId == C.TAIL) {
                     if (incomingBid.ercAmount.mul(incomingBid.price) >= minBidEth) {
                         LibOrders.addBid(asset, incomingBid, orderHintArray);
                     }
                     return matchIncomingBid(asset, incomingBid, matchTotal, b);
                 }
     
                 STypes.Order memory lowestSell = _getLowestSell(asset, b);
     
                 if (incomingBid.price >= lowestSell.price) {
                     // Consider bid filled if only dust amount left
                     if (incomingBid.ercAmount.mul(lowestSell.price) == 0) {
                         return matchIncomingBid(asset, incomingBid, matchTotal, b);
                     }
                     matchlowestSell(asset, lowestSell, incomingBid, matchTotal);
                     if (incomingBid.ercAmount > lowestSell.ercAmount) {
                         incomingBid.ercAmount -= lowestSell.ercAmount;
                         lowestSell.ercAmount = 0;
                         if (lowestSell.isShort()) {
                             b.matchedShortId = lowestSell.id;
                             b.prevShortId = lowestSell.prevId;
                             LibOrders.matchOrder(s.shorts, asset, lowestSell.id);
                             _shortDirectionHandler(asset, lowestSell, incomingBid, b);
                         } else {
                             b.matchedAskId = lowestSell.id;
                             LibOrders.matchOrder(s.asks, asset, lowestSell.id);
                             b.askId = lowestSell.nextId;
                         }
                     } else {
                         if (incomingBid.ercAmount == lowestSell.ercAmount) {
                             if (lowestSell.isShort()) {
                                 b.matchedShortId = lowestSell.id;
                                 b.prevShortId = lowestSell.prevId;
                                 LibOrders.matchOrder(s.shorts, asset, lowestSell.id);
                             } else {
                                 b.matchedAskId = lowestSell.id;
                                 LibOrders.matchOrder(s.asks, asset, lowestSell.id);
                             }
                         } else {
                             lowestSell.ercAmount -= incomingBid.ercAmount;
                             if (lowestSell.isShort()) {
                                 b.dustShortId = lowestSell.id;
                                 STypes.Order storage lowestShort = s.shorts[asset][lowestSell.id];
                                 lowestShort.ercAmount = lowestSell.ercAmount;
                             } else {
                                 b.dustAskId = lowestSell.id;
                                 s.asks[asset][lowestSell.id].ercAmount = lowestSell.ercAmount;
                             }
                             // Check reduced dust threshold for existing limit orders
                             if (lowestSell.ercAmount.mul(lowestSell.price) >= LibAsset.minAskEth(asset).mul(C.DUST_FACTOR)) {
                                 b.dustShortId = b.dustAskId = 0;
                             }
                         }
                         incomingBid.ercAmount = 0;
                         return matchIncomingBid(asset, incomingBid, matchTotal, b);
                     }
                 } else {
                     if (incomingBid.ercAmount.mul(incomingBid.price) >= minBidEth) {
                         LibOrders.addBid(asset, incomingBid, orderHintArray);
                     }
                     return matchIncomingBid(asset, incomingBid, matchTotal, b);

119:     /**
          * @notice The matching algorithm for bids
          *
          * @param asset The market that will be impacted
          * @param incomingBid Active bid order
          * @param orderHintArray Array of hint ID for gas-optimized sorted placement on market
          * @param b Memory struct used throughout bidMatchAlgo
          *
          * @return ethFilled Amount of eth filled
          * @return ercAmountLeft Amount of erc not matched
          */
         function bidMatchAlgo(
             address asset,
             STypes.Order memory incomingBid,
             MTypes.OrderHint[] memory orderHintArray,
             MTypes.BidMatchAlgo memory b
         ) private returns (uint88 ethFilled, uint88 ercAmountLeft) {
             uint256 minBidEth = LibAsset.minBidEth(asset);
             MTypes.Match memory matchTotal;
     
             while (true) {
                 // @dev Handles scenario when no sells left after partial fill
                 if (b.askId == C.TAIL && b.shortId == C.TAIL) {
                     if (incomingBid.ercAmount.mul(incomingBid.price) >= minBidEth) {
                         LibOrders.addBid(asset, incomingBid, orderHintArray);
                     }
                     return matchIncomingBid(asset, incomingBid, matchTotal, b);
                 }
     
                 STypes.Order memory lowestSell = _getLowestSell(asset, b);
     
                 if (incomingBid.price >= lowestSell.price) {
                     // Consider bid filled if only dust amount left
                     if (incomingBid.ercAmount.mul(lowestSell.price) == 0) {
                         return matchIncomingBid(asset, incomingBid, matchTotal, b);

119:     /**
          * @notice The matching algorithm for bids
          *
          * @param asset The market that will be impacted
          * @param incomingBid Active bid order
          * @param orderHintArray Array of hint ID for gas-optimized sorted placement on market
          * @param b Memory struct used throughout bidMatchAlgo
          *
          * @return ethFilled Amount of eth filled
          * @return ercAmountLeft Amount of erc not matched
          */
         function bidMatchAlgo(
             address asset,
             STypes.Order memory incomingBid,
             MTypes.OrderHint[] memory orderHintArray,
             MTypes.BidMatchAlgo memory b
         ) private returns (uint88 ethFilled, uint88 ercAmountLeft) {
             uint256 minBidEth = LibAsset.minBidEth(asset);
             MTypes.Match memory matchTotal;
     
             while (true) {
                 // @dev Handles scenario when no sells left after partial fill
                 if (b.askId == C.TAIL && b.shortId == C.TAIL) {
                     if (incomingBid.ercAmount.mul(incomingBid.price) >= minBidEth) {
                         LibOrders.addBid(asset, incomingBid, orderHintArray);
                     }
                     return matchIncomingBid(asset, incomingBid, matchTotal, b);
                 }
     
                 STypes.Order memory lowestSell = _getLowestSell(asset, b);
     
                 if (incomingBid.price >= lowestSell.price) {
                     // Consider bid filled if only dust amount left
                     if (incomingBid.ercAmount.mul(lowestSell.price) == 0) {
                         return matchIncomingBid(asset, incomingBid, matchTotal, b);
                     }
                     matchlowestSell(asset, lowestSell, incomingBid, matchTotal);
                     if (incomingBid.ercAmount > lowestSell.ercAmount) {
                         incomingBid.ercAmount -= lowestSell.ercAmount;
                         lowestSell.ercAmount = 0;
                         if (lowestSell.isShort()) {
                             b.matchedShortId = lowestSell.id;
                             b.prevShortId = lowestSell.prevId;
                             LibOrders.matchOrder(s.shorts, asset, lowestSell.id);
                             _shortDirectionHandler(asset, lowestSell, incomingBid, b);
                         } else {
                             b.matchedAskId = lowestSell.id;
                             LibOrders.matchOrder(s.asks, asset, lowestSell.id);
                             b.askId = lowestSell.nextId;
                         }
                     } else {
                         if (incomingBid.ercAmount == lowestSell.ercAmount) {
                             if (lowestSell.isShort()) {
                                 b.matchedShortId = lowestSell.id;
                                 b.prevShortId = lowestSell.prevId;
                                 LibOrders.matchOrder(s.shorts, asset, lowestSell.id);
                             } else {
                                 b.matchedAskId = lowestSell.id;
                                 LibOrders.matchOrder(s.asks, asset, lowestSell.id);
                             }
                         } else {
                             lowestSell.ercAmount -= incomingBid.ercAmount;
                             if (lowestSell.isShort()) {
                                 b.dustShortId = lowestSell.id;
                                 STypes.Order storage lowestShort = s.shorts[asset][lowestSell.id];
                                 lowestShort.ercAmount = lowestSell.ercAmount;
                             } else {
                                 b.dustAskId = lowestSell.id;
                                 s.asks[asset][lowestSell.id].ercAmount = lowestSell.ercAmount;
                             }
                             // Check reduced dust threshold for existing limit orders
                             if (lowestSell.ercAmount.mul(lowestSell.price) >= LibAsset.minAskEth(asset).mul(C.DUST_FACTOR)) {
                                 b.dustShortId = b.dustAskId = 0;
                             }
                         }
                         incomingBid.ercAmount = 0;
                         return matchIncomingBid(asset, incomingBid, matchTotal, b);

264:     /**
          * @notice Final settlement of incoming bid
          *
          * @param asset The market that will be impacted
          * @param incomingBid Active bid order
          * @param matchTotal Struct of the running matched totals
          * @param b Memory struct used throughout bidMatchAlgo
          *
          * @return ethFilled Amount of eth filled
          * @return ercAmountLeft Amount of erc not matched
          */
         function matchIncomingBid(
             address asset,
             STypes.Order memory incomingBid,
             MTypes.Match memory matchTotal,
             MTypes.BidMatchAlgo memory b
         ) private returns (uint88 ethFilled, uint88 ercAmountLeft) {
             if (matchTotal.fillEth == 0) {
                 return (0, incomingBid.ercAmount);
             }
     
             STypes.Asset storage Asset = s.asset[asset];
             uint256 vault = Asset.vault;
     
             LibOrders.updateSellOrdersOnMatch(asset, b);
     
             // Remove last sell order from order book if under dust threshold
             // @dev needs to happen after updateSellOrdersOnMatch()
             if (b.dustAskId > 0) {
                 IDiamond(payable(address(this)))._cancelAsk(asset, b.dustAskId);
             } else if (b.dustShortId > 0) {
                 IDiamond(payable(address(this)))._cancelShort(asset, b.dustShortId);
             }
     
             // If at least one short was matched
             if (matchTotal.shortFillEth > 0) {
                 STypes.Vault storage Vault = s.vault[vault];
     
                 // Matched Shares
                 Vault.dittoMatchedShares += matchTotal.dittoMatchedShares;
                 // Yield Accounting
                 Vault.dethCollateral += matchTotal.shortFillEth;
                 Asset.dethCollateral += matchTotal.shortFillEth;
                 Asset.ercDebt += matchTotal.fillErc - matchTotal.askFillErc;
     
                 // @dev Approximates the startingShortId after bid is fully executed
                 STypes.Order storage currentShort = s.shorts[asset][b.shortId];
                 O shortOrderType = currentShort.orderType;
                 STypes.Order storage prevShort = s.shorts[asset][b.prevShortId];
                 O prevShortOrderType = prevShort.orderType;
     
                 if (shortOrderType != O.Cancelled && shortOrderType != O.Matched) {
                     Asset.startingShortId = b.shortId;
                 } else if (prevShortOrderType != O.Cancelled && prevShortOrderType != O.Matched && prevShort.price >= b.oraclePrice) {
                     Asset.startingShortId = b.prevShortId;
                 } else {
                     if (b.isMovingFwd) {
                         Asset.startingShortId = currentShort.nextId;
                     } else {
                         Asset.startingShortId = s.shorts[asset][b.shortHintId].nextId;
                     }
                 }
             }
     
             // Match bid
             address bidder = incomingBid.addr; // saves 18 gas
             s.vaultUser[vault][bidder].ethEscrowed -= matchTotal.fillEth;
             s.assetUser[asset][bidder].ercEscrowed += matchTotal.fillErc;
             emit Events.MatchOrder(asset, bidder, incomingBid.orderType, incomingBid.id, matchTotal.fillEth, matchTotal.fillErc);
     
             // @dev match price is based on the order that was already on orderbook
             LibOrders.handlePriceDiscount(asset, matchTotal.lastMatchPrice);
             return (matchTotal.fillEth, incomingBid.ercAmount);

264:     /**
          * @notice Final settlement of incoming bid
          *
          * @param asset The market that will be impacted
          * @param incomingBid Active bid order
          * @param matchTotal Struct of the running matched totals
          * @param b Memory struct used throughout bidMatchAlgo
          *
          * @return ethFilled Amount of eth filled
          * @return ercAmountLeft Amount of erc not matched
          */
         function matchIncomingBid(
             address asset,
             STypes.Order memory incomingBid,
             MTypes.Match memory matchTotal,
             MTypes.BidMatchAlgo memory b
         ) private returns (uint88 ethFilled, uint88 ercAmountLeft) {
             if (matchTotal.fillEth == 0) {
                 return (0, incomingBid.ercAmount);

340:     function _getLowestSell(address asset, MTypes.BidMatchAlgo memory b) private view returns (STypes.Order memory lowestSell) {
             if (b.shortId != C.HEAD) {
                 STypes.Order storage lowestShort = s.shorts[asset][b.shortId];
                 STypes.Order storage lowestAsk = s.asks[asset][b.askId];
                 // @dev Setting lowestSell after comparing short and ask prices
                 bool noAsks = b.askId == C.TAIL;
                 bool shortPriceLessThanAskPrice = lowestShort.price < lowestAsk.price;
                 if (noAsks || shortPriceLessThanAskPrice) {
                     return lowestShort;
                 } else {
                     return lowestAsk;
                 }
             } else if (b.askId != C.TAIL) {
                 // @dev Handles scenario when there are no shorts
                 return s.asks[asset][b.askId];

340:     function _getLowestSell(address asset, MTypes.BidMatchAlgo memory b) private view returns (STypes.Order memory lowestSell) {
             if (b.shortId != C.HEAD) {
                 STypes.Order storage lowestShort = s.shorts[asset][b.shortId];
                 STypes.Order storage lowestAsk = s.asks[asset][b.askId];
                 // @dev Setting lowestSell after comparing short and ask prices
                 bool noAsks = b.askId == C.TAIL;
                 bool shortPriceLessThanAskPrice = lowestShort.price < lowestAsk.price;
                 if (noAsks || shortPriceLessThanAskPrice) {
                     return lowestShort;
                 } else {
                     return lowestAsk;

340:     function _getLowestSell(address asset, MTypes.BidMatchAlgo memory b) private view returns (STypes.Order memory lowestSell) {
             if (b.shortId != C.HEAD) {
                 STypes.Order storage lowestShort = s.shorts[asset][b.shortId];
                 STypes.Order storage lowestAsk = s.asks[asset][b.askId];
                 // @dev Setting lowestSell after comparing short and ask prices
                 bool noAsks = b.askId == C.TAIL;
                 bool shortPriceLessThanAskPrice = lowestShort.price < lowestAsk.price;
                 if (noAsks || shortPriceLessThanAskPrice) {
                     return lowestShort;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)

```solidity
File: contracts/facets/ExitShortFacet.sol

213:     function getCollateralRatioNonPrice(STypes.ShortRecord storage short) internal view returns (uint256 cRatio) {
             return short.collateral.div(short.ercDebt);

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

```solidity
File: contracts/facets/RedemptionFacet.sol

380:     function calculateRedemptionFee(address asset, uint88 colRedeemed, uint88 ercDebtRedeemed)
             internal
             returns (uint88 redemptionFee)
         {
             STypes.Asset storage Asset = s.asset[asset];
             uint32 protocolTime = LibOrders.getOffsetTime();
             uint256 secondsPassed = uint256((protocolTime - Asset.lastRedemptionTime)) * 1 ether;
             uint256 decayFactor = C.SECONDS_DECAY_FACTOR.pow(secondsPassed);
             uint256 decayedBaseRate = Asset.baseRate.mulU64(decayFactor);
             // @dev Calculate Asset.ercDebt prior to proposal
             uint104 totalAssetErcDebt = (ercDebtRedeemed + Asset.ercDebt).mulU104(C.BETA);
             // @dev Derived via this forumula: baseRateNew = baseRateOld + redeemedLUSD / (2 * totalLUSD)
             uint256 redeemedDUSDFraction = ercDebtRedeemed.div(totalAssetErcDebt);
             uint256 newBaseRate = decayedBaseRate + redeemedDUSDFraction;
             newBaseRate = LibOrders.min(newBaseRate, 1 ether); // cap baseRate at a maximum of 100%
             assert(newBaseRate > 0); // Base rate is always non-zero after redemption
             // Update the baseRate state variable
             Asset.baseRate = uint64(newBaseRate);
             Asset.lastRedemptionTime = protocolTime;
             uint256 redemptionRate = LibOrders.min((Asset.baseRate + 0.005 ether), 1 ether);
             return uint88(redemptionRate.mul(colRedeemed));

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibBridgeRouter.sol

111:     function withdrawalFeePct(uint256 bridgePointer, address rethBridge, address stethBridge) internal view returns (uint256 fee) {
             IBridge bridgeReth = IBridge(rethBridge);
             IBridge bridgeSteth = IBridge(stethBridge);
     
             // Calculate rETH market premium/discount (factor)
             uint256 unitRethTWAP = OracleLibrary.estimateTWAP(1 ether, 30 minutes, VAULT.RETH_WETH, VAULT.RETH, C.WETH);
             uint256 unitRethOracle = bridgeReth.getUnitDethValue();
             uint256 factorReth = unitRethTWAP.div(unitRethOracle);
             // Calculate stETH market premium/discount (factor)
             uint256 unitWstethTWAP = OracleLibrary.estimateTWAP(1 ether, 30 minutes, VAULT.WSTETH_WETH, VAULT.WSTETH, C.WETH);
             uint256 unitWstethOracle = bridgeSteth.getUnitDethValue();
             uint256 factorSteth = unitWstethTWAP.div(unitWstethOracle);
             if (factorReth > factorSteth) {
                 // rETH market premium relative to stETH
                 if (bridgePointer == VAULT.BRIDGE_RETH) {
                     // Only charge fee if withdrawing rETH
                     return factorReth.div(factorSteth) - 1 ether;
                 }
             } else if (factorSteth > factorReth) {
                 // stETH market premium relative to rETH
                 if (bridgePointer == VAULT.BRIDGE_STETH) {
                     // Only charge fee if withdrawing stETH
                     return factorSteth.div(factorReth) - 1 ether;
                 }
             } else {
                 // Withdrawing less premium LST or premiums are equivalent
                 return 0;

111:     function withdrawalFeePct(uint256 bridgePointer, address rethBridge, address stethBridge) internal view returns (uint256 fee) {
             IBridge bridgeReth = IBridge(rethBridge);
             IBridge bridgeSteth = IBridge(stethBridge);
     
             // Calculate rETH market premium/discount (factor)
             uint256 unitRethTWAP = OracleLibrary.estimateTWAP(1 ether, 30 minutes, VAULT.RETH_WETH, VAULT.RETH, C.WETH);
             uint256 unitRethOracle = bridgeReth.getUnitDethValue();
             uint256 factorReth = unitRethTWAP.div(unitRethOracle);
             // Calculate stETH market premium/discount (factor)
             uint256 unitWstethTWAP = OracleLibrary.estimateTWAP(1 ether, 30 minutes, VAULT.WSTETH_WETH, VAULT.WSTETH, C.WETH);
             uint256 unitWstethOracle = bridgeSteth.getUnitDethValue();
             uint256 factorSteth = unitWstethTWAP.div(unitWstethOracle);
             if (factorReth > factorSteth) {
                 // rETH market premium relative to stETH
                 if (bridgePointer == VAULT.BRIDGE_RETH) {
                     // Only charge fee if withdrawing rETH
                     return factorReth.div(factorSteth) - 1 ether;

111:     function withdrawalFeePct(uint256 bridgePointer, address rethBridge, address stethBridge) internal view returns (uint256 fee) {
             IBridge bridgeReth = IBridge(rethBridge);
             IBridge bridgeSteth = IBridge(stethBridge);
     
             // Calculate rETH market premium/discount (factor)
             uint256 unitRethTWAP = OracleLibrary.estimateTWAP(1 ether, 30 minutes, VAULT.RETH_WETH, VAULT.RETH, C.WETH);
             uint256 unitRethOracle = bridgeReth.getUnitDethValue();
             uint256 factorReth = unitRethTWAP.div(unitRethOracle);
             // Calculate stETH market premium/discount (factor)
             uint256 unitWstethTWAP = OracleLibrary.estimateTWAP(1 ether, 30 minutes, VAULT.WSTETH_WETH, VAULT.WSTETH, C.WETH);
             uint256 unitWstethOracle = bridgeSteth.getUnitDethValue();
             uint256 factorSteth = unitWstethTWAP.div(unitWstethOracle);
             if (factorReth > factorSteth) {
                 // rETH market premium relative to stETH
                 if (bridgePointer == VAULT.BRIDGE_RETH) {
                     // Only charge fee if withdrawing rETH
                     return factorReth.div(factorSteth) - 1 ether;
                 }
             } else if (factorSteth > factorReth) {
                 // stETH market premium relative to rETH
                 if (bridgePointer == VAULT.BRIDGE_STETH) {
                     // Only charge fee if withdrawing stETH
                     return factorSteth.div(factorReth) - 1 ether;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBridgeRouter.sol)

```solidity
File: contracts/libraries/LibOracle.sol

69:     function baseOracleCircuitBreaker(
            uint256 protocolPrice,
            uint80 roundId,
            int256 chainlinkPrice,
            uint256 timeStamp,
            uint256 chainlinkPriceInEth
        ) private view returns (uint256 _protocolPrice) {
            bool invalidFetchData = roundId == 0 || timeStamp == 0 || timeStamp > block.timestamp || chainlinkPrice <= 0
                || block.timestamp > 2 hours + timeStamp;
            uint256 chainlinkDiff =
                chainlinkPriceInEth > protocolPrice ? chainlinkPriceInEth - protocolPrice : protocolPrice - chainlinkPriceInEth;
            bool priceDeviation = protocolPrice > 0 && chainlinkDiff.div(protocolPrice) > 0.5 ether;
    
            // @dev if there is issue with chainlink, get twap price. Verify twap and compare with chainlink
            if (invalidFetchData) {
                return twapCircuitBreaker();

69:     function baseOracleCircuitBreaker(
            uint256 protocolPrice,
            uint80 roundId,
            int256 chainlinkPrice,
            uint256 timeStamp,
            uint256 chainlinkPriceInEth
        ) private view returns (uint256 _protocolPrice) {
            bool invalidFetchData = roundId == 0 || timeStamp == 0 || timeStamp > block.timestamp || chainlinkPrice <= 0
                || block.timestamp > 2 hours + timeStamp;
            uint256 chainlinkDiff =
                chainlinkPriceInEth > protocolPrice ? chainlinkPriceInEth - protocolPrice : protocolPrice - chainlinkPriceInEth;
            bool priceDeviation = protocolPrice > 0 && chainlinkDiff.div(protocolPrice) > 0.5 ether;
    
            // @dev if there is issue with chainlink, get twap price. Verify twap and compare with chainlink
            if (invalidFetchData) {
                return twapCircuitBreaker();
            } else if (priceDeviation) {
                // Check valid twap price
                try IDiamond(payable(address(this))).estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 30 minutes) returns (uint256 twapPrice)
                {
                    if (twapPrice == 0) {
                        return chainlinkPriceInEth;
                    }
    
                    uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);
                    uint256 twapPriceInEth = twapPriceNormalized.inv();
                    uint256 twapDiff = twapPriceInEth > protocolPrice ? twapPriceInEth - protocolPrice : protocolPrice - twapPriceInEth;
    
                    // Save the price that is closest to saved oracle price
                    if (chainlinkDiff <= twapDiff) {
                        return chainlinkPriceInEth;
                    } else {
                        // Check valid twap liquidity
                        IERC20 weth = IERC20(C.WETH);
                        uint256 wethBal = weth.balanceOf(C.USDC_WETH);
                        if (wethBal < 100 ether) {
                            return chainlinkPriceInEth;
                        }
                        return twapPriceInEth;
                    }
                } catch {
                    return chainlinkPriceInEth;
                }
            } else {
                return chainlinkPriceInEth;

69:     function baseOracleCircuitBreaker(
            uint256 protocolPrice,
            uint80 roundId,
            int256 chainlinkPrice,
            uint256 timeStamp,
            uint256 chainlinkPriceInEth
        ) private view returns (uint256 _protocolPrice) {
            bool invalidFetchData = roundId == 0 || timeStamp == 0 || timeStamp > block.timestamp || chainlinkPrice <= 0
                || block.timestamp > 2 hours + timeStamp;
            uint256 chainlinkDiff =
                chainlinkPriceInEth > protocolPrice ? chainlinkPriceInEth - protocolPrice : protocolPrice - chainlinkPriceInEth;
            bool priceDeviation = protocolPrice > 0 && chainlinkDiff.div(protocolPrice) > 0.5 ether;
    
            // @dev if there is issue with chainlink, get twap price. Verify twap and compare with chainlink
            if (invalidFetchData) {
                return twapCircuitBreaker();
            } else if (priceDeviation) {
                // Check valid twap price
                try IDiamond(payable(address(this))).estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 30 minutes) returns (uint256 twapPrice)
                {
                    if (twapPrice == 0) {
                        return chainlinkPriceInEth;
                    }
    
                    uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);
                    uint256 twapPriceInEth = twapPriceNormalized.inv();
                    uint256 twapDiff = twapPriceInEth > protocolPrice ? twapPriceInEth - protocolPrice : protocolPrice - twapPriceInEth;
    
                    // Save the price that is closest to saved oracle price
                    if (chainlinkDiff <= twapDiff) {
                        return chainlinkPriceInEth;
                    } else {
                        // Check valid twap liquidity
                        IERC20 weth = IERC20(C.WETH);
                        uint256 wethBal = weth.balanceOf(C.USDC_WETH);
                        if (wethBal < 100 ether) {
                            return chainlinkPriceInEth;
                        }
                        return twapPriceInEth;
                    }
                } catch {
                    return chainlinkPriceInEth;

69:     function baseOracleCircuitBreaker(
            uint256 protocolPrice,
            uint80 roundId,
            int256 chainlinkPrice,
            uint256 timeStamp,
            uint256 chainlinkPriceInEth
        ) private view returns (uint256 _protocolPrice) {
            bool invalidFetchData = roundId == 0 || timeStamp == 0 || timeStamp > block.timestamp || chainlinkPrice <= 0
                || block.timestamp > 2 hours + timeStamp;
            uint256 chainlinkDiff =
                chainlinkPriceInEth > protocolPrice ? chainlinkPriceInEth - protocolPrice : protocolPrice - chainlinkPriceInEth;
            bool priceDeviation = protocolPrice > 0 && chainlinkDiff.div(protocolPrice) > 0.5 ether;
    
            // @dev if there is issue with chainlink, get twap price. Verify twap and compare with chainlink
            if (invalidFetchData) {
                return twapCircuitBreaker();
            } else if (priceDeviation) {
                // Check valid twap price
                try IDiamond(payable(address(this))).estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 30 minutes) returns (uint256 twapPrice)
                {
                    if (twapPrice == 0) {
                        return chainlinkPriceInEth;

69:     function baseOracleCircuitBreaker(
            uint256 protocolPrice,
            uint80 roundId,
            int256 chainlinkPrice,
            uint256 timeStamp,
            uint256 chainlinkPriceInEth
        ) private view returns (uint256 _protocolPrice) {
            bool invalidFetchData = roundId == 0 || timeStamp == 0 || timeStamp > block.timestamp || chainlinkPrice <= 0
                || block.timestamp > 2 hours + timeStamp;
            uint256 chainlinkDiff =
                chainlinkPriceInEth > protocolPrice ? chainlinkPriceInEth - protocolPrice : protocolPrice - chainlinkPriceInEth;
            bool priceDeviation = protocolPrice > 0 && chainlinkDiff.div(protocolPrice) > 0.5 ether;
    
            // @dev if there is issue with chainlink, get twap price. Verify twap and compare with chainlink
            if (invalidFetchData) {
                return twapCircuitBreaker();
            } else if (priceDeviation) {
                // Check valid twap price
                try IDiamond(payable(address(this))).estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 30 minutes) returns (uint256 twapPrice)
                {
                    if (twapPrice == 0) {
                        return chainlinkPriceInEth;
                    }
    
                    uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);
                    uint256 twapPriceInEth = twapPriceNormalized.inv();
                    uint256 twapDiff = twapPriceInEth > protocolPrice ? twapPriceInEth - protocolPrice : protocolPrice - twapPriceInEth;
    
                    // Save the price that is closest to saved oracle price
                    if (chainlinkDiff <= twapDiff) {
                        return chainlinkPriceInEth;
                    } else {
                        // Check valid twap liquidity
                        IERC20 weth = IERC20(C.WETH);
                        uint256 wethBal = weth.balanceOf(C.USDC_WETH);
                        if (wethBal < 100 ether) {
                            return chainlinkPriceInEth;
                        }
                        return twapPriceInEth;

69:     function baseOracleCircuitBreaker(
            uint256 protocolPrice,
            uint80 roundId,
            int256 chainlinkPrice,
            uint256 timeStamp,
            uint256 chainlinkPriceInEth
        ) private view returns (uint256 _protocolPrice) {
            bool invalidFetchData = roundId == 0 || timeStamp == 0 || timeStamp > block.timestamp || chainlinkPrice <= 0
                || block.timestamp > 2 hours + timeStamp;
            uint256 chainlinkDiff =
                chainlinkPriceInEth > protocolPrice ? chainlinkPriceInEth - protocolPrice : protocolPrice - chainlinkPriceInEth;
            bool priceDeviation = protocolPrice > 0 && chainlinkDiff.div(protocolPrice) > 0.5 ether;
    
            // @dev if there is issue with chainlink, get twap price. Verify twap and compare with chainlink
            if (invalidFetchData) {
                return twapCircuitBreaker();
            } else if (priceDeviation) {
                // Check valid twap price
                try IDiamond(payable(address(this))).estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 30 minutes) returns (uint256 twapPrice)
                {
                    if (twapPrice == 0) {
                        return chainlinkPriceInEth;
                    }
    
                    uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);
                    uint256 twapPriceInEth = twapPriceNormalized.inv();
                    uint256 twapDiff = twapPriceInEth > protocolPrice ? twapPriceInEth - protocolPrice : protocolPrice - twapPriceInEth;
    
                    // Save the price that is closest to saved oracle price
                    if (chainlinkDiff <= twapDiff) {
                        return chainlinkPriceInEth;

69:     function baseOracleCircuitBreaker(
            uint256 protocolPrice,
            uint80 roundId,
            int256 chainlinkPrice,
            uint256 timeStamp,
            uint256 chainlinkPriceInEth
        ) private view returns (uint256 _protocolPrice) {
            bool invalidFetchData = roundId == 0 || timeStamp == 0 || timeStamp > block.timestamp || chainlinkPrice <= 0
                || block.timestamp > 2 hours + timeStamp;
            uint256 chainlinkDiff =
                chainlinkPriceInEth > protocolPrice ? chainlinkPriceInEth - protocolPrice : protocolPrice - chainlinkPriceInEth;
            bool priceDeviation = protocolPrice > 0 && chainlinkDiff.div(protocolPrice) > 0.5 ether;
    
            // @dev if there is issue with chainlink, get twap price. Verify twap and compare with chainlink
            if (invalidFetchData) {
                return twapCircuitBreaker();
            } else if (priceDeviation) {
                // Check valid twap price
                try IDiamond(payable(address(this))).estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 30 minutes) returns (uint256 twapPrice)
                {
                    if (twapPrice == 0) {
                        return chainlinkPriceInEth;
                    }
    
                    uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);
                    uint256 twapPriceInEth = twapPriceNormalized.inv();
                    uint256 twapDiff = twapPriceInEth > protocolPrice ? twapPriceInEth - protocolPrice : protocolPrice - twapPriceInEth;
    
                    // Save the price that is closest to saved oracle price
                    if (chainlinkDiff <= twapDiff) {
                        return chainlinkPriceInEth;
                    } else {
                        // Check valid twap liquidity
                        IERC20 weth = IERC20(C.WETH);
                        uint256 wethBal = weth.balanceOf(C.USDC_WETH);
                        if (wethBal < 100 ether) {
                            return chainlinkPriceInEth;

131:     function twapCircuitBreaker() private view returns (uint256 twapPriceInEth) {
             // Check valid price
             uint256 twapPrice = IDiamond(payable(address(this))).estimateWETHInUSDC(C.UNISWAP_WETH_BASE_AMT, 30 minutes);
             if (twapPrice == 0) revert Errors.InvalidTwapPrice();
     
             // Check valid liquidity
             IERC20 weth = IERC20(C.WETH);
             uint256 wethBal = weth.balanceOf(C.USDC_WETH);
             if (wethBal < 100 ether) revert Errors.InsufficientEthInLiquidityPool();
     
             uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);
             return twapPriceNormalized.inv();

156:     function getTime(address asset) internal view returns (uint256 creationTime) {
             AppStorage storage s = appStorage();
             return s.bids[asset][C.HEAD].creationTime;

162:     function getPrice(address asset) internal view returns (uint80 oraclePrice) {
             AppStorage storage s = appStorage();
             return uint80(s.bids[asset][C.HEAD].ercAmount);

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

30:     function getOffsetTime() internal view returns (uint32 timeInSeconds) {
            // shouldn't overflow in 136 years
            return uint32(block.timestamp - C.STARTING_TIME); // @dev(safe-cast)

221:     /**
          * @notice Verifies that bid id is between two id based on price
          *
          * @param asset The market that will be impacted
          * @param _prevId The first id supposedly preceding the new price
          * @param _newPrice price of prospective order
          * @param _nextId The first id supposedly following the new price
          *
          * @return direction int direction to search (PREV, EXACT, NEXT)
          */
         function verifyBidId(address asset, uint16 _prevId, uint256 _newPrice, uint16 _nextId)
             internal
             view
             returns (int256 direction)
         {
             AppStorage storage s = appStorage();
             // @dev: TAIL can't be prevId because it will always be last item in list
             bool check1 = s.bids[asset][_prevId].price >= _newPrice || _prevId == C.HEAD;
             bool check2 = _newPrice > s.bids[asset][_nextId].price || _nextId == C.TAIL;
     
             if (check1 && check2) {
                 return C.EXACT;

221:     /**
          * @notice Verifies that bid id is between two id based on price
          *
          * @param asset The market that will be impacted
          * @param _prevId The first id supposedly preceding the new price
          * @param _newPrice price of prospective order
          * @param _nextId The first id supposedly following the new price
          *
          * @return direction int direction to search (PREV, EXACT, NEXT)
          */
         function verifyBidId(address asset, uint16 _prevId, uint256 _newPrice, uint16 _nextId)
             internal
             view
             returns (int256 direction)
         {
             AppStorage storage s = appStorage();
             // @dev: TAIL can't be prevId because it will always be last item in list
             bool check1 = s.bids[asset][_prevId].price >= _newPrice || _prevId == C.HEAD;
             bool check2 = _newPrice > s.bids[asset][_nextId].price || _nextId == C.TAIL;
     
             if (check1 && check2) {
                 return C.EXACT;
             } else if (!check1) {
                 return C.PREV;

221:     /**
          * @notice Verifies that bid id is between two id based on price
          *
          * @param asset The market that will be impacted
          * @param _prevId The first id supposedly preceding the new price
          * @param _newPrice price of prospective order
          * @param _nextId The first id supposedly following the new price
          *
          * @return direction int direction to search (PREV, EXACT, NEXT)
          */
         function verifyBidId(address asset, uint16 _prevId, uint256 _newPrice, uint16 _nextId)
             internal
             view
             returns (int256 direction)
         {
             AppStorage storage s = appStorage();
             // @dev: TAIL can't be prevId because it will always be last item in list
             bool check1 = s.bids[asset][_prevId].price >= _newPrice || _prevId == C.HEAD;
             bool check2 = _newPrice > s.bids[asset][_nextId].price || _nextId == C.TAIL;
     
             if (check1 && check2) {
                 return C.EXACT;
             } else if (!check1) {
                 return C.PREV;
             } else if (!check2) {
                 return C.NEXT;

250:     /**
          * @notice Verifies that short id is between two id based on price
          *
          * @param asset The market that will be impacted
          * @param _prevId The first id supposedly preceding the new price
          * @param _newPrice price of prospective order
          * @param _nextId The first id supposedly following the new price
          *
          * @return direction int direction to search (PREV, EXACT, NEXT)
          */
         function verifySellId(
             mapping(address => mapping(uint16 => STypes.Order)) storage orders,
             address asset,
             uint16 _prevId,
             uint256 _newPrice,
             uint16 _nextId
         ) private view returns (int256 direction) {
             // @dev: TAIL can't be prevId because it will always be last item in list
             bool check1 = orders[asset][_prevId].price <= _newPrice || _prevId == C.HEAD;
     
             bool check2 = _newPrice < orders[asset][_nextId].price || _nextId == C.TAIL;
     
             if (check1 && check2) {
                 return C.EXACT;

250:     /**
          * @notice Verifies that short id is between two id based on price
          *
          * @param asset The market that will be impacted
          * @param _prevId The first id supposedly preceding the new price
          * @param _newPrice price of prospective order
          * @param _nextId The first id supposedly following the new price
          *
          * @return direction int direction to search (PREV, EXACT, NEXT)
          */
         function verifySellId(
             mapping(address => mapping(uint16 => STypes.Order)) storage orders,
             address asset,
             uint16 _prevId,
             uint256 _newPrice,
             uint16 _nextId
         ) private view returns (int256 direction) {
             // @dev: TAIL can't be prevId because it will always be last item in list
             bool check1 = orders[asset][_prevId].price <= _newPrice || _prevId == C.HEAD;
     
             bool check2 = _newPrice < orders[asset][_nextId].price || _nextId == C.TAIL;
     
             if (check1 && check2) {
                 return C.EXACT;
             } else if (!check1) {
                 return C.PREV;

250:     /**
          * @notice Verifies that short id is between two id based on price
          *
          * @param asset The market that will be impacted
          * @param _prevId The first id supposedly preceding the new price
          * @param _newPrice price of prospective order
          * @param _nextId The first id supposedly following the new price
          *
          * @return direction int direction to search (PREV, EXACT, NEXT)
          */
         function verifySellId(
             mapping(address => mapping(uint16 => STypes.Order)) storage orders,
             address asset,
             uint16 _prevId,
             uint256 _newPrice,
             uint16 _nextId
         ) private view returns (int256 direction) {
             // @dev: TAIL can't be prevId because it will always be last item in list
             bool check1 = orders[asset][_prevId].price <= _newPrice || _prevId == C.HEAD;
     
             bool check2 = _newPrice < orders[asset][_nextId].price || _nextId == C.TAIL;
     
             if (check1 && check2) {
                 return C.EXACT;
             } else if (!check1) {
                 return C.PREV;
             } else if (!check2) {
                 return C.NEXT;

391:     /**
          * @notice Verifies that an id is between two id based on price and orderType
          *
          * @param asset The market that will be impacted
          * @param prevId The first id supposedly preceding the new price
          * @param newPrice price of prospective order
          * @param nextId The first id supposedly following the new price
          * @param orderType order type (bid, ask, short)
          *
          * @return direction int direction to search (PREV, EXACT, NEXT)
          */
         function verifyId(
             mapping(address => mapping(uint16 => STypes.Order)) storage orders,
             address asset,
             uint16 prevId,
             uint256 newPrice,
             uint16 nextId,
             O orderType
         ) internal view returns (int256 direction) {
             orderType = normalizeOrderType(orderType);
     
             if (orderType == O.LimitAsk || orderType == O.LimitShort) {
                 return verifySellId(orders, asset, prevId, newPrice, nextId);

391:     /**
          * @notice Verifies that an id is between two id based on price and orderType
          *
          * @param asset The market that will be impacted
          * @param prevId The first id supposedly preceding the new price
          * @param newPrice price of prospective order
          * @param nextId The first id supposedly following the new price
          * @param orderType order type (bid, ask, short)
          *
          * @return direction int direction to search (PREV, EXACT, NEXT)
          */
         function verifyId(
             mapping(address => mapping(uint16 => STypes.Order)) storage orders,
             address asset,
             uint16 prevId,
             uint256 newPrice,
             uint16 nextId,
             O orderType
         ) internal view returns (int256 direction) {
             orderType = normalizeOrderType(orderType);
     
             if (orderType == O.LimitAsk || orderType == O.LimitShort) {
                 return verifySellId(orders, asset, prevId, newPrice, nextId);
             } else if (orderType == O.LimitBid) {
                 return verifyBidId(asset, prevId, newPrice, nextId);

420:     function normalizeOrderType(O o) private pure returns (O newO) {
             if (o == O.LimitBid || o == O.MarketBid) {
                 return O.LimitBid;

420:     function normalizeOrderType(O o) private pure returns (O newO) {
             if (o == O.LimitBid || o == O.MarketBid) {
                 return O.LimitBid;
             } else if (o == O.LimitAsk || o == O.MarketAsk) {
                 return O.LimitAsk;

420:     function normalizeOrderType(O o) private pure returns (O newO) {
             if (o == O.LimitBid || o == O.MarketBid) {
                 return O.LimitBid;
             } else if (o == O.LimitAsk || o == O.MarketAsk) {
                 return O.LimitAsk;
             } else if (o == O.LimitShort) {
                 return O.LimitShort;

430:     /**
          * @notice Helper function for finding and returning id of potential order
          *
          * @param orders the order mapping
          * @param asset The market that will be impacted
          * @param direction int direction to search (PREV, EXACT, NEXT)
          * @param hintId hint id
          * @param _newPrice price of prospective order used to find the id
          * @param orderType which OrderType to verify
          */
         function getOrderId(
             mapping(address => mapping(uint16 => STypes.Order)) storage orders,
             address asset,
             int256 direction,
             uint16 hintId,
             uint256 _newPrice,
             O orderType
         ) internal view returns (uint16 _hintId) {
             while (true) {
                 uint16 nextId = orders[asset][hintId].nextId;
     
                 if (verifyId(orders, asset, hintId, _newPrice, nextId, orderType) == C.EXACT) {
                     return hintId;

826:     function findOrderHintId(
             mapping(address => mapping(uint16 => STypes.Order)) storage orders,
             address asset,
             MTypes.OrderHint[] memory orderHintArray
         ) internal view returns (uint16 hintId) {
             bool anyOrderHintPrevMatched;
             for (uint256 i; i < orderHintArray.length; i++) {
                 MTypes.OrderHint memory orderHint = orderHintArray[i];
                 STypes.Order storage order = orders[asset][orderHint.hintId];
                 O hintOrderType = order.orderType;
                 if (hintOrderType == O.Cancelled || hintOrderType == O.Matched) {
                     continue;
                 } else if (order.creationTime == orderHint.creationTime) {
                     return orderHint.hintId;
                 } else if (!anyOrderHintPrevMatched && order.prevOrderType == O.Matched) {
                     anyOrderHintPrevMatched = true;
                 }
             }
     
             if (anyOrderHintPrevMatched) {
                 // @dev If hint was prev matched, assume that hint was close to HEAD and therefore is reasonable to use HEAD
                 return C.HEAD;

826:     function findOrderHintId(
             mapping(address => mapping(uint16 => STypes.Order)) storage orders,
             address asset,
             MTypes.OrderHint[] memory orderHintArray
         ) internal view returns (uint16 hintId) {
             bool anyOrderHintPrevMatched;
             for (uint256 i; i < orderHintArray.length; i++) {
                 MTypes.OrderHint memory orderHint = orderHintArray[i];
                 STypes.Order storage order = orders[asset][orderHint.hintId];
                 O hintOrderType = order.orderType;
                 if (hintOrderType == O.Cancelled || hintOrderType == O.Matched) {
                     continue;
                 } else if (order.creationTime == orderHint.creationTime) {
                     return orderHint.hintId;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

```solidity
File: contracts/libraries/LibSRMin.sol

13:     function checkCancelShortOrder(address asset, SR initialStatus, uint16 shortOrderId, uint8 shortRecordId, address shorter)
            internal
            returns (bool isCancelled)
        {
            AppStorage storage s = appStorage();
            if (initialStatus == SR.PartialFill) {
                STypes.Order storage shortOrder = s.shorts[asset][shortOrderId];
                STypes.ShortRecord storage shortRecord = s.shortRecords[asset][shorter][shortRecordId];
                if (shortOrder.shortRecordId != shortRecordId || shortOrder.addr != shorter) revert Errors.InvalidShortOrder();
    
                if (shorter == msg.sender) {
                    // If call comes from exitShort() or combineShorts() then always cancel
                    LibOrders.cancelShort(asset, shortOrderId);
                    assert(shortRecord.status != SR.PartialFill);
                    return true;

13:     function checkCancelShortOrder(address asset, SR initialStatus, uint16 shortOrderId, uint8 shortRecordId, address shorter)
            internal
            returns (bool isCancelled)
        {
            AppStorage storage s = appStorage();
            if (initialStatus == SR.PartialFill) {
                STypes.Order storage shortOrder = s.shorts[asset][shortOrderId];
                STypes.ShortRecord storage shortRecord = s.shortRecords[asset][shorter][shortRecordId];
                if (shortOrder.shortRecordId != shortRecordId || shortOrder.addr != shorter) revert Errors.InvalidShortOrder();
    
                if (shorter == msg.sender) {
                    // If call comes from exitShort() or combineShorts() then always cancel
                    LibOrders.cancelShort(asset, shortOrderId);
                    assert(shortRecord.status != SR.PartialFill);
                    return true;
                } else if (shortRecord.ercDebt < LibAsset.minShortErc(asset)) {
                    // If call comes from liquidate() and SR ercDebt under minShortErc
                    LibOrders.cancelShort(asset, shortOrderId);
                    return true;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRMin.sol)

```solidity
File: contracts/libraries/LibSRRecovery.sol

17:     function checkRecoveryModeViolation(address asset, uint256 shortRecordCR, uint256 oraclePrice)
            internal
            view
            returns (bool recoveryViolation)
        {
            AppStorage storage s = appStorage();
    
            uint256 recoveryCR = LibAsset.recoveryCR(asset);
            if (shortRecordCR < recoveryCR) {
                // Only check asset CR if low enough
                STypes.Asset storage Asset = s.asset[asset];
                if (Asset.ercDebt > 0) {
                    // If Asset.ercDebt == 0 then assetCR is NA
                    uint256 assetCR = Asset.dethCollateral.div(oraclePrice.mul(Asset.ercDebt));
                    if (assetCR < recoveryCR) {
                        // Market is in recovery mode and shortRecord CR too low
                        return true;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRRecovery.sol)

### <a name="NC-17"></a>[NC-17] `require()` / `revert()` statements should have descriptive reason strings

*Instances (57)*:

```solidity
File: contracts/facets/BidOrdersFacet.sol

87:         if (eth < LibAsset.minBidEth(asset)) revert Errors.OrderUnderMinimumSize();

90:         if (s.vaultUser[Asset.vault][sender].ethEscrowed < eth) revert Errors.InsufficientETHEscrowed();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)

```solidity
File: contracts/facets/BridgeRouterFacet.sol

64:         if (amount < C.MIN_DEPOSIT) revert Errors.UnderMinimumDeposit();

83:         if (msg.value < C.MIN_DEPOSIT) revert Errors.UnderMinimumDeposit();

102:         if (dethAmount == 0) revert Errors.ParameterIsZero();

134:         if (dethAmount == 0) revert Errors.ParameterIsZero();

164:             if (vault == 0) revert Errors.InvalidBridge();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

```solidity
File: contracts/facets/ExitShortFacet.sol

53:         if (buybackAmount > ercDebt || buybackAmount == 0) revert Errors.InvalidBuyback();

99:         if (buybackAmount == 0 || buybackAmount > ercDebt) revert Errors.InvalidBuyback();

103:             if (AssetUser.ercEscrowed < buybackAmount) revert Errors.InsufficientERCEscrowed();

174:         if (e.buybackAmount == 0 || e.buybackAmount > e.ercDebt) revert Errors.InvalidBuyback();

178:             if (ethAmount > e.collateral) revert Errors.InsufficientCollateral();

188:         if (e.ethFilled == 0) revert Errors.ExitShortPriceTooLow();

201:             if (short.ercDebt < LibAsset.minShortErc(asset)) revert Errors.CannotLeaveDustAmount();

204:             if (getCollateralRatioNonPrice(short) < e.beforeExitCR) revert Errors.PostExitCRLtPreExitCR();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

```solidity
File: contracts/facets/RedemptionFacet.sol

60:         if (proposalInput.length > type(uint8).max) revert Errors.TooManyProposals();

66:         if (redemptionAmount < minShortErc) revert Errors.RedemptionUnderMinShortErc();

68:         if (redeemerAssetUser.ercEscrowed < redemptionAmount) revert Errors.InsufficientERCEscrowed();

71:         if (redeemerAssetUser.SSTORE2Pointer != address(0)) revert Errors.ExistingProposedRedemptions();

110:                 if (shortOrder.shortRecordId != p.shortId || shortOrder.addr != p.shorter) revert Errors.InvalidShortOrder();

141:         if (p.totalAmountProposed < minShortErc) revert Errors.RedemptionUnderMinShortErc();

203:         if (redemptionFee > maxRedemptionFee) revert Errors.RedemptionFeeTooHigh();

206:         if (VaultUser.ethEscrowed < redemptionFee) revert Errors.InsufficientETHEscrowed();

227:         if (redeemer == msg.sender) revert Errors.CannotDisputeYourself();

233:         if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();

235:         if (LibOrders.getOffsetTime() >= redeemerAssetUser.timeToDispute) revert Errors.TimeToDisputeHasElapsed();

242:                 revert Errors.CannotDisputeWithRedeemerProposal();

249:         if (!validRedemptionSR(disputeSR, d.redeemer, disputeShorter, minShortErc)) revert Errors.InvalidRedemption();

297:             revert Errors.InvalidRedemptionDispute();

312:         if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();

313:         if (LibOrders.getOffsetTime() < redeemerAssetUser.timeToDispute) revert Errors.TimeToDisputeHasNotElapsed();

351:         if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();

352:         if (redeemerAssetUser.timeToDispute > LibOrders.getOffsetTime()) revert Errors.TimeToDisputeHasNotElapsed();

359:         if (claimProposal.shorter != msg.sender && claimProposal.shortId != id) revert Errors.CanOnlyClaimYourShort();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/facets/ShortOrdersFacet.sol

52:             revert Errors.InvalidCR();

59:         if (ercAmount < p.minShortErc || p.eth < p.minAskEth) revert Errors.OrderUnderMinimumSize();

62:         if (s.vaultUser[Asset.vault][msg.sender].ethEscrowed < p.eth.mul(cr)) revert Errors.InsufficientETHEscrowed();

81:             revert Errors.BelowRecoveryModeCR();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ShortOrdersFacet.sol)

```solidity
File: contracts/libraries/LibBridgeRouter.sol

73:                     revert Errors.MustUseExistingBridgeCredit();

103:                     revert Errors.MustUseExistingBridgeCredit();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBridgeRouter.sol)

```solidity
File: contracts/libraries/LibOracle.sol

25:         if (address(oracle) == address(0)) revert Errors.InvalidAsset();

60:                 if (roundID == 0 || price == 0 || timeStamp > block.timestamp) revert Errors.InvalidPrice();

128:         if (invalidFetchData) revert Errors.InvalidPrice();

134:         if (twapPrice == 0) revert Errors.InvalidTwapPrice();

139:         if (wethBal < 100 ether) revert Errors.InsufficientEthInLiquidityPool();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

778:             revert Errors.BadShortHint();

850:         revert Errors.BadHintIdArray();

859:         if (orderType == O.Cancelled || orderType == O.Matched) revert Errors.NotActiveOrder();

874:             revert Errors.NotActiveOrder();

887:         if (orderType == O.Cancelled || orderType == O.Matched) revert Errors.NotActiveOrder();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

```solidity
File: contracts/libraries/LibSRMin.sol

21:             if (shortOrder.shortRecordId != shortRecordId || shortOrder.addr != shorter) revert Errors.InvalidShortOrder();

48:             if (shortOrder.shortRecordId != shortRecordId || shortOrder.addr != shorter) revert Errors.InvalidShortOrder();

59:                 if (shortOrder.ercAmount + shortRecord.ercDebt < minShortErc) revert Errors.CannotLeaveDustAmount();

62:             revert Errors.CannotLeaveDustAmount();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRMin.sol)

```solidity
File: contracts/libraries/LibSRTransfer.sol

20:         if (short.status == SR.Closed) revert Errors.OriginalShortRecordCancelled();

21:         if (short.ercDebt == 0) revert Errors.OriginalShortRecordRedeemed();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRTransfer.sol)

```solidity
File: contracts/libraries/UniswapOracleLibrary.sol

52:         if (secondsAgo <= 0) revert Errors.InvalidTWAPSecondsAgo();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol)

### <a name="NC-18"></a>[NC-18] Take advantage of Custom Error's return value property

An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (57)*:

```solidity
File: contracts/facets/BidOrdersFacet.sol

87:         if (eth < LibAsset.minBidEth(asset)) revert Errors.OrderUnderMinimumSize();

90:         if (s.vaultUser[Asset.vault][sender].ethEscrowed < eth) revert Errors.InsufficientETHEscrowed();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)

```solidity
File: contracts/facets/BridgeRouterFacet.sol

64:         if (amount < C.MIN_DEPOSIT) revert Errors.UnderMinimumDeposit();

83:         if (msg.value < C.MIN_DEPOSIT) revert Errors.UnderMinimumDeposit();

102:         if (dethAmount == 0) revert Errors.ParameterIsZero();

134:         if (dethAmount == 0) revert Errors.ParameterIsZero();

164:             if (vault == 0) revert Errors.InvalidBridge();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

```solidity
File: contracts/facets/ExitShortFacet.sol

53:         if (buybackAmount > ercDebt || buybackAmount == 0) revert Errors.InvalidBuyback();

99:         if (buybackAmount == 0 || buybackAmount > ercDebt) revert Errors.InvalidBuyback();

103:             if (AssetUser.ercEscrowed < buybackAmount) revert Errors.InsufficientERCEscrowed();

174:         if (e.buybackAmount == 0 || e.buybackAmount > e.ercDebt) revert Errors.InvalidBuyback();

178:             if (ethAmount > e.collateral) revert Errors.InsufficientCollateral();

188:         if (e.ethFilled == 0) revert Errors.ExitShortPriceTooLow();

201:             if (short.ercDebt < LibAsset.minShortErc(asset)) revert Errors.CannotLeaveDustAmount();

204:             if (getCollateralRatioNonPrice(short) < e.beforeExitCR) revert Errors.PostExitCRLtPreExitCR();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

```solidity
File: contracts/facets/RedemptionFacet.sol

60:         if (proposalInput.length > type(uint8).max) revert Errors.TooManyProposals();

66:         if (redemptionAmount < minShortErc) revert Errors.RedemptionUnderMinShortErc();

68:         if (redeemerAssetUser.ercEscrowed < redemptionAmount) revert Errors.InsufficientERCEscrowed();

71:         if (redeemerAssetUser.SSTORE2Pointer != address(0)) revert Errors.ExistingProposedRedemptions();

110:                 if (shortOrder.shortRecordId != p.shortId || shortOrder.addr != p.shorter) revert Errors.InvalidShortOrder();

141:         if (p.totalAmountProposed < minShortErc) revert Errors.RedemptionUnderMinShortErc();

203:         if (redemptionFee > maxRedemptionFee) revert Errors.RedemptionFeeTooHigh();

206:         if (VaultUser.ethEscrowed < redemptionFee) revert Errors.InsufficientETHEscrowed();

227:         if (redeemer == msg.sender) revert Errors.CannotDisputeYourself();

233:         if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();

235:         if (LibOrders.getOffsetTime() >= redeemerAssetUser.timeToDispute) revert Errors.TimeToDisputeHasElapsed();

242:                 revert Errors.CannotDisputeWithRedeemerProposal();

249:         if (!validRedemptionSR(disputeSR, d.redeemer, disputeShorter, minShortErc)) revert Errors.InvalidRedemption();

297:             revert Errors.InvalidRedemptionDispute();

312:         if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();

313:         if (LibOrders.getOffsetTime() < redeemerAssetUser.timeToDispute) revert Errors.TimeToDisputeHasNotElapsed();

351:         if (redeemerAssetUser.SSTORE2Pointer == address(0)) revert Errors.InvalidRedemption();

352:         if (redeemerAssetUser.timeToDispute > LibOrders.getOffsetTime()) revert Errors.TimeToDisputeHasNotElapsed();

359:         if (claimProposal.shorter != msg.sender && claimProposal.shortId != id) revert Errors.CanOnlyClaimYourShort();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/facets/ShortOrdersFacet.sol

52:             revert Errors.InvalidCR();

59:         if (ercAmount < p.minShortErc || p.eth < p.minAskEth) revert Errors.OrderUnderMinimumSize();

62:         if (s.vaultUser[Asset.vault][msg.sender].ethEscrowed < p.eth.mul(cr)) revert Errors.InsufficientETHEscrowed();

81:             revert Errors.BelowRecoveryModeCR();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ShortOrdersFacet.sol)

```solidity
File: contracts/libraries/LibBridgeRouter.sol

73:                     revert Errors.MustUseExistingBridgeCredit();

103:                     revert Errors.MustUseExistingBridgeCredit();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBridgeRouter.sol)

```solidity
File: contracts/libraries/LibOracle.sol

25:         if (address(oracle) == address(0)) revert Errors.InvalidAsset();

60:                 if (roundID == 0 || price == 0 || timeStamp > block.timestamp) revert Errors.InvalidPrice();

128:         if (invalidFetchData) revert Errors.InvalidPrice();

134:         if (twapPrice == 0) revert Errors.InvalidTwapPrice();

139:         if (wethBal < 100 ether) revert Errors.InsufficientEthInLiquidityPool();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

778:             revert Errors.BadShortHint();

850:         revert Errors.BadHintIdArray();

859:         if (orderType == O.Cancelled || orderType == O.Matched) revert Errors.NotActiveOrder();

874:             revert Errors.NotActiveOrder();

887:         if (orderType == O.Cancelled || orderType == O.Matched) revert Errors.NotActiveOrder();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

```solidity
File: contracts/libraries/LibSRMin.sol

21:             if (shortOrder.shortRecordId != shortRecordId || shortOrder.addr != shorter) revert Errors.InvalidShortOrder();

48:             if (shortOrder.shortRecordId != shortRecordId || shortOrder.addr != shorter) revert Errors.InvalidShortOrder();

59:                 if (shortOrder.ercAmount + shortRecord.ercDebt < minShortErc) revert Errors.CannotLeaveDustAmount();

62:             revert Errors.CannotLeaveDustAmount();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRMin.sol)

```solidity
File: contracts/libraries/LibSRTransfer.sol

20:         if (short.status == SR.Closed) revert Errors.OriginalShortRecordCancelled();

21:         if (short.ercDebt == 0) revert Errors.OriginalShortRecordRedeemed();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRTransfer.sol)

```solidity
File: contracts/libraries/UniswapOracleLibrary.sol

52:         if (secondsAgo <= 0) revert Errors.InvalidTWAPSecondsAgo();

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol)

### <a name="NC-19"></a>[NC-19] Internal and private variables and functions names should begin with an underscore

According to the Solidity Style Guide, Non-`external` variable and function names should begin with an [underscore](https://docs.soliditylang.org/en/latest/style-guide.html#underscore-prefix-for-non-external-functions-and-variables)

*Instances (62)*:

```solidity
File: contracts/facets/BidOrdersFacet.sol

130:     function bidMatchAlgo(

215:     function matchlowestSell(

275:     function matchIncomingBid(

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)

```solidity
File: contracts/facets/BridgeRouterFacet.sol

148:     function maybeUpdateYield(uint256 vault, uint88 amount) private {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

```solidity
File: contracts/facets/ExitShortFacet.sol

213:     function getCollateralRatioNonPrice(STypes.ShortRecord storage short) internal view returns (uint256 cRatio) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

```solidity
File: contracts/facets/RedemptionFacet.sol

29:     function validRedemptionSR(STypes.ShortRecord storage shortRecord, address proposer, address shorter, uint256 minShortErc)

380:     function calculateRedemptionFee(address asset, uint88 colRedeemed, uint88 ercDebtRedeemed)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibBridgeRouter.sol

20:     function addDeth(uint256 vault, uint256 bridgePointer, uint88 amount) internal {

37:     function assessDeth(uint256 vault, uint256 bridgePointer, uint88 amount, address rethBridge, address stethBridge)

111:     function withdrawalFeePct(uint256 bridgePointer, address rethBridge, address stethBridge) internal view returns (uint256 fee) {

141:     function transferBridgeCredit(address asset, address from, address to, uint88 collateral) internal {

194:     function removeDeth(uint256 vault, uint88 amount, uint88 fee) internal {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBridgeRouter.sol)

```solidity
File: contracts/libraries/LibBytes.sol

11:     function readProposalData(address SSTORE2Pointer, uint8 slateLength) internal view returns (MTypes.ProposalData[] memory) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBytes.sol)

```solidity
File: contracts/libraries/LibOracle.sol

19:     function getOraclePrice(address asset) internal view returns (uint256) {

69:     function baseOracleCircuitBreaker(

117:     function oracleCircuitBreaker(

131:     function twapCircuitBreaker() private view returns (uint256 twapPriceInEth) {

149:     function setPriceAndTime(address asset, uint256 oraclePrice, uint32 oracleTime) internal {

156:     function getTime(address asset) internal view returns (uint256 creationTime) {

162:     function getPrice(address asset) internal view returns (uint80 oraclePrice) {

168:     function getSavedOrSpotOraclePrice(address asset) internal view returns (uint256) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

30:     function getOffsetTime() internal view returns (uint32 timeInSeconds) {

35:     function convertCR(uint16 cr) internal pure returns (uint256) {

40:     function increaseSharesOnMatch(address asset, STypes.Order memory order, MTypes.Match memory matchTotal, uint88 eth) internal {

55:     function currentOrders(mapping(address => mapping(uint16 => STypes.Order)) storage orders, address asset)

78:     function isShort(STypes.Order memory order) internal pure returns (bool) {

82:     function addBid(address asset, STypes.Order memory order, MTypes.OrderHint[] memory orderHintArray) internal {

103:     function addAsk(address asset, STypes.Order memory order, MTypes.OrderHint[] memory orderHintArray) internal {

128:     function addShort(address asset, STypes.Order memory order, MTypes.OrderHint[] memory orderHintArray) internal {

153:     function addSellOrder(STypes.Order memory incomingOrder, address asset, MTypes.OrderHint[] memory orderHintArray) private {

173:     function addOrder(

231:     function verifyBidId(address asset, uint16 _prevId, uint256 _newPrice, uint16 _nextId)

260:     function verifySellId(

289:     function cancelOrder(mapping(address => mapping(uint16 => STypes.Order)) storage orders, address asset, uint16 id) internal {

314:     function matchOrder(mapping(address => mapping(uint16 => STypes.Order)) storage orders, address asset, uint16 id) internal {

362:     function findPrevOfIncomingId(

402:     function verifyId(

420:     function normalizeOrderType(O o) private pure returns (O newO) {

440:     function getOrderId(

474:     function updateBidOrdersOnMatch(

499:     function updateSellOrdersOnMatch(address asset, MTypes.BidMatchAlgo memory b) internal {

556:     function sellMatchAlgo(

628:     function matchIncomingSell(address asset, STypes.Order memory incomingOrder, MTypes.Match memory matchTotal) private {

652:     function matchIncomingAsk(address asset, STypes.Order memory incomingAsk, MTypes.Match memory matchTotal) private {

668:     function matchIncomingShort(address asset, STypes.Order memory incomingShort, MTypes.Match memory matchTotal) private {

705:     function matchHighestBid(

783:     function updateOracleAndStartingShortViaThreshold(

803:     function updateOracleAndStartingShortViaTimeBidOnly(address asset, uint16[] memory shortHintArray) internal {

810:     function updateStartingShortIdViaShort(address asset, STypes.Order memory incomingShort) internal {

826:     function findOrderHintId(

854:     function cancelBid(address asset, uint16 id) internal {

868:     function cancelAsk(address asset, uint16 id) internal {

882:     function cancelShort(address asset, uint16 id) internal {

955:     function handlePriceDiscount(address asset, uint80 price) internal {

985:     function min(uint256 a, uint256 b) internal pure returns (uint256) {

989:     function max(uint256 a, uint256 b) internal pure returns (uint256) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

```solidity
File: contracts/libraries/LibSRMin.sol

13:     function checkCancelShortOrder(address asset, SR initialStatus, uint16 shortOrderId, uint8 shortRecordId, address shorter)

36:     function checkShortMinErc(address asset, SR initialStatus, uint16 shortOrderId, uint8 shortRecordId, address shorter)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRMin.sol)

```solidity
File: contracts/libraries/LibSRRecovery.sol

17:     function checkRecoveryModeViolation(address asset, uint256 shortRecordCR, uint256 oraclePrice)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRRecovery.sol)

```solidity
File: contracts/libraries/LibSRTransfer.sol

14:     function transferShortRecord(address from, address to, uint40 tokenId) internal {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRTransfer.sol)

```solidity
File: contracts/libraries/UniswapOracleLibrary.sol

28:     function getQuoteAtTick(int24 tick, uint128 baseAmount, address baseToken, address quoteToken)

47:     function estimateTWAP(uint128 amountIn, uint32 secondsAgo, address pool, address baseToken, address quoteToken)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol)

### <a name="NC-20"></a>[NC-20] Constants should be defined rather than using magic numbers

*Instances (6)*:

```solidity
File: contracts/libraries/LibBytes.sol

32:                 shorter := shr(96, fullWord) // 0x60 = 96 (256-160)

34:                 shortId := and(0xff, shr(88, fullWord)) // 0x58 = 88 (96-8), mask of bytes1 = 0xff * 1

36:                 CR := and(0xffffffffffffffff, shr(24, fullWord)) // 0x18 = 24 (88-64), mask of bytes8 = 0xff * 8

38:                 fullWord := mload(add(slate, add(offset, 29))) // (29 offset)

40:                 ercDebtRedeemed := shr(168, fullWord) // (256-88 = 168)

42:                 colRedeemed := add(0xffffffffffffffffffffff, shr(80, fullWord)) // (256-88-88 = 80), mask of bytes11 = 0xff * 11

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBytes.sol)

### <a name="NC-21"></a>[NC-21] Variables need not be initialized to zero

The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (6)*:

```solidity
File: contracts/facets/RedemptionFacet.sol

76:         for (uint8 i = 0; i < proposalInput.length; i++) {

240:         for (uint256 i = 0; i < decodedProposalData.length; i++) {

319:         for (uint256 i = 0; i < decodedProposalData.length; i++) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibBytes.sol

18:         for (uint256 i = 0; i < slateLength; i++) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBytes.sol)

```solidity
File: contracts/libraries/LibOrders.sol

71:         for (uint256 i = 0; i < size; i++) {

743:             for (uint256 i = 0; i < shortHintArray.length;) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

## Low Issues

| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | Missing checks for `address(0)` when assigning values to address state variables | 3 |
| [L-2](#L-2) | Division by zero not prevented | 4 |
| [L-3](#L-3) | External call recipient may consume all transaction gas | 1 |
| [L-4](#L-4) | Signature use at deadlines should be allowed | 4 |
| [L-5](#L-5) | Loss of precision | 3 |
| [L-6](#L-6) | Solidity version 0.8.20+ may not work on other chains due to `PUSH0` | 12 |
| [L-7](#L-7) | Consider using OpenZeppelin's SafeCast library to prevent unexpected overflows when downcasting | 13 |
| [L-8](#L-8) | Upgradeable contract not initialized | 1 |

### <a name="L-1"></a>[L-1] Missing checks for `address(0)` when assigning values to address state variables

*Instances (3)*:

```solidity
File: contracts/facets/BridgeRouterFacet.sol

30:         rethBridge = _rethBridge;

31:         stethBridge = _stethBridge;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

```solidity
File: contracts/facets/ExitShortFacet.sol

29:         dusd = _dusd;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

### <a name="L-2"></a>[L-2] Division by zero not prevented

The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (4)*:

```solidity
File: contracts/libraries/LibOracle.sol

93:                 uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);

141:         uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

36:         return (uint256(cr) * 1 ether) / C.TWO_DECIMAL_PLACES;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

```solidity
File: contracts/libraries/UniswapOracleLibrary.sol

62:         int24 tick = int24(tickCumulativesDelta / int32(secondsAgo));

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol)

### <a name="L-3"></a>[L-3] External call recipient may consume all transaction gas

There is no limit specified on the amount of gas used, so the recipient can use up all of the transaction's gas, causing it to revert. Use `addr.call{gas: <amount>}("")` or [this](https://github.com/nomad-xyz/ExcessivelySafeCall) library instead.

*Instances (1)*:

```solidity
File: contracts/facets/RedemptionFacet.sol

288:                 LibOrders.max(LibAsset.callerFeePct(d.asset), (currentProposal.CR - disputeCR).div(currentProposal.CR)), 0.33 ether

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

### <a name="L-4"></a>[L-4] Signature use at deadlines should be allowed

According to [EIP-2612](https://github.com/ethereum/EIPs/blob/71dc97318013bf2ac572ab63fab530ac9ef419ca/EIPS/eip-2612.md?plain=1#L58), signatures used on exactly the deadline timestamp are supposed to be allowed. While the signature may or may not be used for the exact EIP-2612 use case (transfer approvals), for consistency's sake, all deadlines should follow this semantic. If the timestamp is an expiration rather than a deadline, consider whether it makes more sense to include the expiration timestamp as a valid timestamp, as is done for deadlines.

*Instances (4)*:

```solidity
File: contracts/libraries/LibOracle.sol

60:                 if (roundID == 0 || price == 0 || timeStamp > block.timestamp) revert Errors.InvalidPrice();

76:         bool invalidFetchData = roundId == 0 || timeStamp == 0 || timeStamp > block.timestamp || chainlinkPrice <= 0

125:         bool invalidFetchData = roundId == 0 || timeStamp == 0 || timeStamp > block.timestamp || chainlinkPrice <= 0

126:             || baseRoundId == 0 || baseTimeStamp == 0 || baseTimeStamp > block.timestamp || baseChainlinkPrice <= 0;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

### <a name="L-5"></a>[L-5] Loss of precision

Division by large numbers may result in the result being zero, due to solidity not supporting fractions. Consider requiring a minimum amount for the numerator to ensure that it is always larger than the denominator

*Instances (3)*:

```solidity
File: contracts/libraries/LibOracle.sol

93:                 uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);

141:         uint256 twapPriceNormalized = twapPrice * (1 ether / C.DECIMAL_USDC);

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

36:         return (uint256(cr) * 1 ether) / C.TWO_DECIMAL_PLACES;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

### <a name="L-6"></a>[L-6] Solidity version 0.8.20+ may not work on other chains due to `PUSH0`

The compiler for Solidity 0.8.20 switches the default target EVM version to [Shanghai](https://blog.soliditylang.org/2023/05/10/solidity-0.8.20-release-announcement/#important-note), which includes the new `PUSH0` op code. This op code may not yet be implemented on all L2s, so deployment on these chains will fail. To work around this issue, use an earlier [EVM](https://docs.soliditylang.org/en/v0.8.20/using-the-compiler.html?ref=zaryabs.com#setting-the-evm-version-to-target) [version](https://book.getfoundry.sh/reference/config/solidity-compiler#evm_version). While the project itself may or may not compile with 0.8.20, other projects with which it integrates, or which extend this project may, and those projects will have problems deploying these contracts/libraries.

*Instances (12)*:

```solidity
File: contracts/facets/BidOrdersFacet.sol

2: pragma solidity 0.8.21;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BidOrdersFacet.sol)

```solidity
File: contracts/facets/BridgeRouterFacet.sol

2: pragma solidity 0.8.21;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

```solidity
File: contracts/facets/ExitShortFacet.sol

2: pragma solidity 0.8.21;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ExitShortFacet.sol)

```solidity
File: contracts/facets/RedemptionFacet.sol

2: pragma solidity 0.8.21;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/facets/ShortOrdersFacet.sol

2: pragma solidity 0.8.21;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/ShortOrdersFacet.sol)

```solidity
File: contracts/libraries/LibBridgeRouter.sol

2: pragma solidity 0.8.21;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBridgeRouter.sol)

```solidity
File: contracts/libraries/LibBytes.sol

2: pragma solidity 0.8.21;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibBytes.sol)

```solidity
File: contracts/libraries/LibOracle.sol

2: pragma solidity 0.8.21;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

2: pragma solidity 0.8.21;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

```solidity
File: contracts/libraries/LibSRMin.sol

2: pragma solidity 0.8.21;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRMin.sol)

```solidity
File: contracts/libraries/LibSRRecovery.sol

2: pragma solidity 0.8.21;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRRecovery.sol)

```solidity
File: contracts/libraries/LibSRTransfer.sol

2: pragma solidity 0.8.21;

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibSRTransfer.sol)

### <a name="L-7"></a>[L-7] Consider using OpenZeppelin's SafeCast library to prevent unexpected overflows when downcasting

Downcasting from `uint256`/`int256` in Solidity does not revert on overflow. This can result in undesired exploitation or bugs, since developers usually assume that overflows raise errors. [OpenZeppelin's SafeCast library](https://docs.openzeppelin.com/contracts/3.x/api/utils#SafeCast) restores this intuition by reverting the transaction when such an operation overflows. Using this library eliminates an entire class of bugs, so it's recommended to use it always. Some exceptions are acceptable like with the classic `uint256(uint160(address(variable)))`

*Instances (13)*:

```solidity
File: contracts/facets/BridgeRouterFacet.sol

68:         uint88 dethAmount = uint88(IBridge(bridge).deposit(msg.sender, amount)); // @dev(safe-cast)

87:         uint88 dethAmount = uint88(IBridge(bridge).depositEth{value: msg.value}()); // Assumes 1 ETH = 1 DETH

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/BridgeRouterFacet.sol)

```solidity
File: contracts/facets/RedemptionFacet.sol

131:                 bytes8(uint64(p.currentCR)),

131:                 bytes8(uint64(p.currentCR)),

181:             redeemerAssetUser.timeToDispute = protocolTime + uint32((m.mul(p.currentCR - 1.7 ether) + 3 ether) * 1 hours / 1 ether);

185:                 protocolTime + uint32((m.mul(p.currentCR - 1.5 ether) + 1.5 ether) * 1 hours / 1 ether);

189:                 protocolTime + uint32((m.mul(p.currentCR - 1.3 ether) + 0.75 ether) * 1 hours / 1 ether);

193:                 protocolTime + uint32((m.mul(p.currentCR - 1.2 ether) + C.ONE_THIRD) * 1 hours / 1 ether);

196:             redeemerAssetUser.timeToDispute = protocolTime + uint32(m.mul(p.currentCR - 1.1 ether) * 1 hours / 1 ether);

397:         Asset.baseRate = uint64(newBaseRate);

400:         return uint88(redemptionRate.mul(colRedeemed));

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

```solidity
File: contracts/libraries/LibOracle.sol

151:         s.bids[asset][C.HEAD].ercAmount = uint80(oraclePrice);

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

```solidity
File: contracts/libraries/LibOrders.sol

903:             uint88 minShortErc = uint88(LibAsset.minShortErc(asset));

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

### <a name="L-8"></a>[L-8] Upgradeable contract not initialized

Upgradeable contracts are initialized via an initializer function rather than by a constructor. Leaving such a contract uninitialized may lead to it being taken over by a malicious user

*Instances (1)*:

```solidity
File: contracts/libraries/LibOrders.sol

752:                     if (shortOrderType == O.Cancelled || shortOrderType == O.Matched || shortOrderType == O.Uninitialized) {

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOrders.sol)

## Medium Issues

| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Fees can be set to be greater than 100%. | 1 |
| [M-2](#M-2) | Library function isn't `internal` or `private` | 1 |
| [M-3](#M-3) | Chainlink's `latestRoundData` might return stale or incorrect results | 2 |
| [M-4](#M-4) | Missing checks for whether the L2 Sequencer is active | 2 |

### <a name="M-1"></a>[M-1] Fees can be set to be greater than 100%

There should be an upper limit to reasonable fees.
A malicious owner can keep the fee rate at zero, but if a large value transfer enters the mempool, the owner can jack the rate up to the maximum and sandwich attack a user.

*Instances (1)*:

```solidity
File: contracts/facets/RedemptionFacet.sol

380:     function calculateRedemptionFee(address asset, uint88 colRedeemed, uint88 ercDebtRedeemed)
             internal
             returns (uint88 redemptionFee)
         {
             STypes.Asset storage Asset = s.asset[asset];
             uint32 protocolTime = LibOrders.getOffsetTime();
             uint256 secondsPassed = uint256((protocolTime - Asset.lastRedemptionTime)) * 1 ether;
             uint256 decayFactor = C.SECONDS_DECAY_FACTOR.pow(secondsPassed);
             uint256 decayedBaseRate = Asset.baseRate.mulU64(decayFactor);
             // @dev Calculate Asset.ercDebt prior to proposal
             uint104 totalAssetErcDebt = (ercDebtRedeemed + Asset.ercDebt).mulU104(C.BETA);
             // @dev Derived via this forumula: baseRateNew = baseRateOld + redeemedLUSD / (2 * totalLUSD)
             uint256 redeemedDUSDFraction = ercDebtRedeemed.div(totalAssetErcDebt);
             uint256 newBaseRate = decayedBaseRate + redeemedDUSDFraction;
             newBaseRate = LibOrders.min(newBaseRate, 1 ether); // cap baseRate at a maximum of 100%
             assert(newBaseRate > 0); // Base rate is always non-zero after redemption
             // Update the baseRate state variable
             Asset.baseRate = uint64(newBaseRate);
             Asset.lastRedemptionTime = protocolTime;
             uint256 redemptionRate = LibOrders.min((Asset.baseRate + 0.005 ether), 1 ether);
             return uint88(redemptionRate.mul(colRedeemed));

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/facets/RedemptionFacet.sol)

### <a name="M-2"></a>[M-2] Library function isn't `internal` or `private`

In a library, using an external or public visibility means that we won't be going through the library with a DELEGATECALL but with a CALL. This changes the context and should be done carefully.

*Instances (1)*:

```solidity
File: contracts/libraries/UniswapOracleLibrary.sol

11:     function observe(uint32[] calldata secondsAgos)

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/UniswapOracleLibrary.sol)

### <a name="M-3"></a>[M-3] Chainlink's `latestRoundData` might return stale or incorrect results

- This is a common issue: <https://github.com/code-423n4/2022-12-tigris-findings/issues/655>, <https://code4rena.com/reports/2022-10-inverse#m-17-chainlink-oracle-data-feed-is-not-sufficiently-validated-and-can-return-stale-price>, <https://app.sherlock.xyz/audits/contests/41#issue-m-12-chainlinks-latestrounddata--return-stale-or-incorrect-result> and many more occurrences.

`latestRoundData()` is used to fetch the asset price from a Chainlink aggregator, but it's missing additional validations to ensure that the round is complete. If there is a problem with Chainlink starting a new round and finding consensus on the new value for the oracle (e.g. Chainlink nodes abandon the oracle, chain congestion, vulnerability/attacks on the Chainlink system) consumers of this contract may continue using outdated stale data / stale prices.

More bugs related to chainlink here: [Chainlink Oracle Security Considerations](https://medium.com/cyfrin/chainlink-oracle-defi-attacks-93b6cb6541bf#99af)

*Instances (2)*:

```solidity
File: contracts/libraries/LibOracle.sol

35:                 (
                        uint80 roundID,
                        int256 price,
                        /*uint256 startedAt*/
                        ,

52:                 (
                        uint80 roundID,
                        int256 price,
                        /*uint256 startedAt*/
                        ,

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)

### <a name="M-4"></a>[M-4] Missing checks for whether the L2 Sequencer is active

Chainlink recommends that users using price oracles, check whether the Arbitrum Sequencer is [active](https://docs.chain.link/data-feeds/l2-sequencer-feeds#arbitrum). If the sequencer goes down, the Chainlink oracles will have stale prices from before the downtime, until a new L2 OCR transaction goes through. Users who submit their transactions via the [L1 Dealyed Inbox](https://developer.arbitrum.io/tx-lifecycle#1b--or-from-l1-via-the-delayed-inbox) will be able to take advantage of these stale prices. Use a [Chainlink oracle](https://blog.chain.link/how-to-use-chainlink-price-feeds-on-arbitrum/#almost_done!_meet_the_l2_sequencer_health_flag) to determine whether the sequencer is offline or not, and don't allow operations to take place while the sequencer is offline.

*Instances (2)*:

```solidity
File: contracts/libraries/LibOracle.sol

35:                 (
                        uint80 roundID,
                        int256 price,
                        /*uint256 startedAt*/
                        ,

52:                 (
                        uint80 roundID,
                        int256 price,
                        /*uint256 startedAt*/
                        ,

```

[Link to code](https://github.com/code-423n4/2024-03-dittoeth/blob/main/contracts/libraries/LibOracle.sol)
