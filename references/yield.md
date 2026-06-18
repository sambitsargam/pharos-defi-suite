# Reference: Yield

Setup as in `tokens.md`.

---

## StakingRewards
Synthetix-style single-asset staking; rewards stream linearly over a period.

### Deploy
```bash
forge create src/yield/StakingRewards.sol:StakingRewards --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $STAKING_TOKEN $REWARD_TOKEN $OWNER
```

### Operations
```bash
# fund rewards: transfer reward tokens to the contract, then start a period
cast send $REWARD_TOKEN "transfer(address,uint256)" $STAKING $(cast to-wei 7000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $STAKING "notifyRewardAmount(uint256)" $(cast to-wei 7000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY  # owner

# user: approve + stake, then claim
cast send $STAKING_TOKEN "approve(address,uint256)" $STAKING $(cast to-wei 1000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $STAKING "stake(uint256)" $(cast to-wei 1000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $STAKING "earned(address)(uint256)" $OWNER --rpc-url $RPC
cast send $STAKING "getReward()" --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $STAKING "exit()" --rpc-url $RPC --private-key $PRIVATE_KEY   # withdraw all + claim
```
Default `rewardsDuration` = 7 days (owner can change between periods).

---

## MasterChef
Multi-pool farm; `rewardToken` distributed per block by pool weight. Rewards are pre-funded.

### Deploy
```bash
forge create src/yield/MasterChef.sol:MasterChef --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $REWARD_TOKEN $(cast to-wei 1 ether) $OWNER   # rewardPerBlock
# fund it: transfer reward tokens to the MasterChef address
```

### Operations
```bash
# owner adds a pool (allocPoint, lpToken, withUpdate)
cast send $CHEF "add(uint256,address,bool)" 100 $LP_TOKEN true --rpc-url $RPC --private-key $PRIVATE_KEY
# user: approve + deposit into pool 0
cast send $LP_TOKEN "approve(address,uint256)" $CHEF $(cast to-wei 100 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $CHEF "deposit(uint256,uint256)" 0 $(cast to-wei 100 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $CHEF "pendingReward(uint256,address)(uint256)" 0 $OWNER --rpc-url $RPC
cast send $CHEF "withdraw(uint256,uint256)" 0 $(cast to-wei 100 ether) --rpc-url $RPC --private-key $PRIVATE_KEY  # claims + withdraws
cast send $CHEF "emergencyWithdraw(uint256)" 0 --rpc-url $RPC --private-key $PRIVATE_KEY  # forfeit rewards
```

---

## YieldVault (ERC4626)
Tokenized vault: deposit an asset, receive shares; value grows as the vault accrues yield.

### Deploy
```bash
forge create src/yield/YieldVault.sol:YieldVault --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $ASSET "Vault Token" "vTKN"
```

### Operations
```bash
cast send $ASSET "approve(address,uint256)" $VAULT $(cast to-wei 1000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $VAULT "deposit(uint256,address)" $(cast to-wei 1000 ether) $OWNER --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $VAULT "previewRedeem(uint256)(uint256)" $(cast to-wei 100 ether) --rpc-url $RPC
cast send $VAULT "redeem(uint256,address,address)" $(cast to-wei 100 ether) $OWNER $OWNER --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $VAULT "harvest(uint256)" $(cast to-wei 50 ether) --rpc-url $RPC --private-key $PRIVATE_KEY  # donate yield (approve first)
```

---

## NFTStaking
Stake ERC721s, earn `rewardToken` per NFT per second (pre-funded).

### Deploy
```bash
forge create src/yield/NFTStaking.sol:NFTStaking --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $NFT $REWARD_TOKEN $(cast to-wei 0.001 ether) $OWNER   # rewardPerSecond per NFT
```

### Operations
```bash
cast send $NFT "approve(address,uint256)" $NFTSTAKING $TOKEN_ID --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $NFTSTAKING "stake(uint256)" $TOKEN_ID --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $NFTSTAKING "pending(uint256)(uint256)" $TOKEN_ID --rpc-url $RPC
cast send $NFTSTAKING "claim(uint256)" $TOKEN_ID --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $NFTSTAKING "unstake(uint256)" $TOKEN_ID --rpc-url $RPC --private-key $PRIVATE_KEY
```
