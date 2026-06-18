# Reference: Fundraising

Setup as in `tokens.md`.

---

## TokenSale (IDO / presale)
Fixed-price sale: buyers pay native PHRS, receive sale tokens at a fixed rate.

### Deploy & use
```bash
# token, tokensPerNative (1e18-scaled tokens per 1 PHRS), start, end, hardCap (native, 0=uncapped), owner
forge create src/fundraising/TokenSale.sol:TokenSale --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $TOKEN $(cast to-wei 1000 ether) $(date +%s) $(( $(date +%s) + 604800 )) $(cast to-wei 100 ether) $OWNER
# fund: transfer sale tokens to the contract
cast send $SALE "buy()" --value $(cast to-wei 1 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $SALE "withdrawProceeds(address)" $OWNER --rpc-url $RPC --private-key $PRIVATE_KEY     # owner
cast send $SALE "withdrawUnsold(address,uint256)" $OWNER $(cast to-wei 1000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
```
`tokensPerNative` of `1000e18` means 1 PHRS buys 1000 tokens. Reverts: `sale closed`,
`hard cap reached`.

---

## Crowdfunding
All-or-nothing native PHRS crowdfunding with refunds if the goal is missed.

### Deploy & use
```bash
forge create src/fundraising/Crowdfunding.sol:Crowdfunding --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $BENEFICIARY $(cast to-wei 50 ether) $(( $(date +%s) + 1209600 ))   # goal, deadline
cast send $CF "pledge()" --value $(cast to-wei 5 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
# after the deadline:
cast send $CF "claim()" --rpc-url $RPC --private-key $PRIVATE_KEY     # beneficiary, if goal met
cast send $CF "refund()" --rpc-url $RPC --private-key $PRIVATE_KEY    # backer, if goal missed
```

---

## LiquidityLocker
Time-locks ERC20/LP tokens to prove liquidity can't be rugged.

### Deploy & use
```bash
forge create src/fundraising/LiquidityLocker.sol:LiquidityLocker --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast
cast send $LP "approve(address,uint256)" $LOCKER $(cast to-wei 1000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
# token, amount, unlockTime
cast send $LOCKER "lock(address,uint256,uint64)" $LP $(cast to-wei 1000 ether) $(( $(date +%s) + 31536000 )) \
  --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $LOCKER "withdraw(uint256)" 0 --rpc-url $RPC --private-key $PRIVATE_KEY   # after unlock
cast send $LOCKER "extend(uint256,uint64)" 0 $(( $(date +%s) + 63072000 )) --rpc-url $RPC --private-key $PRIVATE_KEY
```
