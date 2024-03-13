# Migration Guide

## Helpful Tips

1. See example in `migrations/0X_example_migration/`
2. Remember to review storage variable and slot layouts before migration
3. Remember to run `FOUNDRY_PROFILE=deploy-mainnet forge build` before copying bytecode artifact from `foundry/artifacts-gas/`
4. Adjust `EtherscanDiamondImpl.sol` if there are any API changes
   a. Deploy new `EtherscanDiamondImpl.sol`
   b. Set new dummy implementation in `DiamondEtherscanFacet.sol`
5. Proposals can be submitted via Tally
   a. Standard diamondCut upgrades or parameter updates
   b. Ditto Treasury grant
6. Emergency transactions can be submitted to the timelock via Safe Wallet
   a. Emergency diamondCut upgrade
7. Verify any deployed contracts using:

   ```sh
   forge verify-contract \
   --chain-id 1 \
   --num-of-optimizations 100000 \
   --watch \
   --compiler-version v0.8.21+commit.d9974bed \
   --constructor-args 0x0000000000000000000000000000000000000000000000000000000000000000 \
   0xDeploymentAddress \
   contracts/facets/Contract.sol:Contract
   ```

   - Make sure `ETHERSCAN_API_KEY` is set in `.env`
   - Replace constructor args with output from `abi.encode(args1, args2);`
   - Replace `0xDeploymentAddress` with address where contract was deployed
   - Replace `contracts/facets/Contract.sol:Contract` with appropriate path