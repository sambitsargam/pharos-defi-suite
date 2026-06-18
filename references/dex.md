# Reference: DEX / AMM (Uniswap-V2 style)

Setup as in `tokens.md`. The router handles native PHRS via WPHRS. Always pass a `deadline`
(use `$(($(date +%s) + 1200))` for +20 min).

---

## Deploy the DEX
```bash
# 1) factory (feeToSetter = owner)
forge create src/dex/DexFactory.sol:DexFactory --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $OWNER
export FACTORY=<deployed>

# 2) wrapped native (if not already deployed)
forge create src/tokens/WrappedNative.sol:WrappedNative --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast
export WPHRS=<deployed>

# 3) router
forge create src/dex/DexRouter.sol:DexRouter --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $FACTORY $WPHRS
export ROUTER=<deployed>
```

---

## Create a pair
```bash
cast send $FACTORY "createPair(address,address)" $TOKEN_A $TOKEN_B --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $FACTORY "getPair(address,address)(address)" $TOKEN_A $TOKEN_B --rpc-url $RPC
```
The router auto-creates a pair on first `addLiquidity` if none exists.

---

## Add liquidity
```bash
# approve the router for both tokens first
cast send $TOKEN_A "approve(address,uint256)" $ROUTER $(cast to-wei 1000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $TOKEN_B "approve(address,uint256)" $ROUTER $(cast to-wei 1000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY

DL=$(( $(date +%s) + 1200 ))
cast send $ROUTER "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)" \
  $TOKEN_A $TOKEN_B $(cast to-wei 1000 ether) $(cast to-wei 1000 ether) 0 0 $OWNER $DL \
  --rpc-url $RPC --private-key $PRIVATE_KEY

# native pair (token + PHRS): send PHRS as --value
cast send $ROUTER "addLiquidityNative(address,uint256,uint256,uint256,address,uint256)" \
  $TOKEN_A $(cast to-wei 1000 ether) 0 0 $OWNER $DL \
  --value $(cast to-wei 1 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Remove liquidity
```bash
# approve the router for the LP token (the pair address) first
cast send $PAIR "approve(address,uint256)" $ROUTER $(cast to-wei 100 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $ROUTER "removeLiquidity(address,address,uint256,uint256,uint256,address,uint256)" \
  $TOKEN_A $TOKEN_B $(cast to-wei 100 ether) 0 0 $OWNER $DL --rpc-url $RPC --private-key $PRIVATE_KEY
```

---

## Swap
```bash
# exact tokens -> tokens (path can be multi-hop: A,B,C)
cast send $ROUTER "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)" \
  $(cast to-wei 100 ether) 1 "[$TOKEN_A,$TOKEN_B]" $OWNER $DL --rpc-url $RPC --private-key $PRIVATE_KEY

# exact native -> tokens (path[0] must be WPHRS)
cast send $ROUTER "swapExactNativeForTokens(uint256,address[],address,uint256)" \
  1 "[$WPHRS,$TOKEN_A]" $OWNER $DL --value $(cast to-wei 0.5 ether) --rpc-url $RPC --private-key $PRIVATE_KEY

# exact tokens -> native (path[last] must be WPHRS)
cast send $ROUTER "swapExactTokensForNative(uint256,uint256,address[],address,uint256)" \
  $(cast to-wei 100 ether) 1 "[$TOKEN_A,$WPHRS]" $OWNER $DL --rpc-url $RPC --private-key $PRIVATE_KEY
```
Always set a real `amountOutMin` from a quote (below) to protect against slippage; `1` is
shown only for examples.

---

## Quote
```bash
cast call $ROUTER "getAmountsOut(uint256,address[])(uint256[])" $(cast to-wei 100 ether) "[$TOKEN_A,$TOKEN_B]" --rpc-url $RPC
cast call $ROUTER "getAmountsIn(uint256,address[])(uint256[])"  $(cast to-wei 100 ether) "[$TOKEN_A,$TOKEN_B]" --rpc-url $RPC
cast call $PAIR "getReserves()(uint112,uint112,uint32)" --rpc-url $RPC
```

### Common reverts
`DEX: EXPIRED` (deadline passed) · `DEX: INSUFFICIENT_OUTPUT_AMOUNT` (slippage) ·
`DEX: INSUFFICIENT_LIQUIDITY` (empty/thin pool) · `DEX: K` (invariant broken) ·
`DEX: PAIR_EXISTS`. Fee is a flat 0.30% per hop.
