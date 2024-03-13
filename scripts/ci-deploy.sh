#!/bin/bash

(anvil --code-size-limit 40000 --gas-price 10000000000 --gas-limit 30000000 --hardfork shanghai --fork-url=http://100.123.211.55:8545 --chain-id 1 --fork-block-number 18223500) &
my_pid=$!

sleep 1

timeout 11s bun run deploy-local

bun run postdeploy-local

kill -9 $my_pid

exit_code=$?

if [ $exit_code -eq 0 ]; then
  exit 0
fi

exit 1