# Reference: Payments & Distribution

Setup as in `tokens.md`. Time helpers: `NOW=$(date +%s)`.

---

## TokenVesting
Cliff + linear vesting; the creator funds each schedule up front (approve first).

### Deploy & use
```bash
forge create src/payments/TokenVesting.sol:TokenVesting --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast

cast send $TOKEN "approve(address,uint256)" $VESTING $(cast to-wei 100000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
# token, beneficiary, start, cliffDuration(sec), duration(sec), total, revocable
cast send $VESTING "createSchedule(address,address,uint64,uint64,uint64,uint256,bool)" \
  $TOKEN $BENEFICIARY $(date +%s) 2592000 31536000 $(cast to-wei 100000 ether) true \
  --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $VESTING "releasable(uint256)(uint256)" 0 --rpc-url $RPC
cast send $VESTING "release(uint256)" 0 --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $VESTING "revoke(uint256)" 0 --rpc-url $RPC --private-key $PRIVATE_KEY   # creator only, if revocable
```

---

## PaymentStream
Sablier-style per-second streams; recipient withdraws accrued funds.

### Deploy & use
```bash
forge create src/payments/PaymentStream.sol:PaymentStream --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast

cast send $TOKEN "approve(address,uint256)" $STREAM $(cast to-wei 1000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
# token, recipient, deposit, start, stop  (start >= now)
cast send $STREAM "createStream(address,address,uint256,uint64,uint64)" \
  $TOKEN $RECIPIENT $(cast to-wei 1000 ether) $(date +%s) $(( $(date +%s) + 2592000 )) \
  --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $STREAM "balanceOf(uint256)(uint256)" 0 --rpc-url $RPC   # withdrawable now
cast send $STREAM "withdraw(uint256,uint256)" 0 $(cast to-wei 10 ether) --rpc-url $RPC --private-key $PRIVATE_KEY  # recipient
cast send $STREAM "cancel(uint256)" 0 --rpc-url $RPC --private-key $PRIVATE_KEY   # either party; splits remainder
```

---

## MerkleDistributor
Gas-efficient airdrop. Build a Merkle tree of `keccak256(abi.encodePacked(index,account,amount))`
leaves off-chain; commit the root at deploy.

### Deploy & use
```bash
forge create src/payments/MerkleDistributor.sol:MerkleDistributor --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $TOKEN $MERKLE_ROOT $OWNER
# fund: transfer the airdrop tokens to the distributor
cast send $DISTRIB "claim(uint256,address,uint256,bytes32[])" $INDEX $ACCOUNT $(cast to-wei 100 ether) "[$PROOF1,$PROOF2]" \
  --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $DISTRIB "isClaimed(uint256)(bool)" $INDEX --rpc-url $RPC
cast send $DISTRIB "sweep(address,uint256)" $TO $(cast to-wei 100 ether) --rpc-url $RPC --private-key $PRIVATE_KEY  # owner
```

---

## RevenueSplitter
Splits received native PHRS and ERC20s among payees by fixed shares (pull-based).

### Deploy & use
```bash
forge create src/payments/RevenueSplitter.sol:RevenueSplitter --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args "[$PAYEE_A,$PAYEE_B]" "[60,40]"
# send funds to the splitter (native via plain transfer, or ERC20 transfer)
cast call $SPLIT "releasableToken(address,address)(uint256)" $TOKEN $PAYEE_A --rpc-url $RPC
cast send $SPLIT "releaseToken(address,address)" $TOKEN $PAYEE_A --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $SPLIT "releaseNative(address)" $PAYEE_A --rpc-url $RPC --private-key $PRIVATE_KEY
```

---

## OTCSwap
Trustless P2P token swap; maker escrows what they sell.

### Deploy & use
```bash
forge create src/payments/OTCSwap.sol:OTCSwap --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast

cast send $TOKEN_SELL "approve(address,uint256)" $OTC $(cast to-wei 100 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
# tokenSell, amountSell, tokenBuy, amountBuy, taker (0x0 = open)
cast send $OTC "createOrder(address,uint256,address,uint256,address)" \
  $TOKEN_SELL $(cast to-wei 100 ether) $TOKEN_BUY $(cast to-wei 250 ether) 0x0000000000000000000000000000000000000000 \
  --rpc-url $RPC --private-key $PRIVATE_KEY
# taker approves tokenBuy then fills
cast send $TOKEN_BUY "approve(address,uint256)" $OTC $(cast to-wei 250 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $OTC "fillOrder(uint256)" 0 --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $OTC "cancelOrder(uint256)" 0 --rpc-url $RPC --private-key $PRIVATE_KEY  # maker only
```
