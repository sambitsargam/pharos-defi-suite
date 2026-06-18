# Reference: Oracle

Setup as in `tokens.md`. Prices are USD scaled to 1e18 (e.g. `$2000 = 2000e18`).

---

## SimpleOracle
Owner-administered price feed. Good for testnets and as a fallback; do NOT use as the sole
price source for real collateral.

### Deploy & use
```bash
forge create src/oracle/SimpleOracle.sol:SimpleOracle --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $OWNER
cast send $ORACLE "setPrice(address,uint256)" $TOKEN $(cast to-wei 2000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $ORACLE "setPrices(address[],uint256[])" "[$TOK_A,$TOK_B]" "[$(cast to-wei 1 ether),$(cast to-wei 2000 ether)]" \
  --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $ORACLE "getPrice(address)(uint256)" $TOKEN --rpc-url $RPC
```
Used by `LendingPool` and `CDPEngine` (pass the oracle address at their deploy).

---

## DexTWAPOracle
Manipulation-resistant time-weighted average price from a DexPair's cumulative accumulators.

### Deploy & use
```bash
# pair, period(sec) — e.g. 3600 for a 1-hour TWAP
forge create src/oracle/DexTWAPOracle.sol:DexTWAPOracle --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $PAIR 3600
# call update() once per period (e.g. via a keeper), then consult
cast send $TWAP "update()" --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $TWAP "consult(address,uint256)(uint256)" $TOKEN $(cast to-wei 1 ether) --rpc-url $RPC
```
`update()` reverts with `TWAP: period not elapsed` if called before `period` seconds pass. The
pair must have had at least one interaction in the window for accumulators to advance.
