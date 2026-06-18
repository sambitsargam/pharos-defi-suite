# Reference: Lending & Stablecoin

Setup as in `tokens.md`. **Assumption:** listed tokens are 18-decimal and oracle prices are
USD scaled to 1e18. Deploy a price oracle first (see `references/oracle.md`).

---

## LendingPool
Compound-style multi-asset money market: supply to earn, post collateral, borrow, liquidate.

### Deploy
```bash
forge create src/lending/LendingPool.sol:LendingPool --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $ORACLE $OWNER
```

### List reserves (owner)
```bash
# ratePerSecond is 1e18-scaled borrow interest. e.g. ~10% APR ≈ 3170979198 (0.1/31536000 * 1e18)
cast send $POOL "listReserve(address,uint256,uint256)" $TOKEN 3170979198 7500 --rpc-url $RPC --private-key $PRIVATE_KEY
# args: token, ratePerSecond, collateralFactorBps (7500 = 75%)
```

### User actions
```bash
cast send $TOKEN "approve(address,uint256)" $POOL $(cast to-wei 1000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $POOL "supply(address,uint256)" $TOKEN $(cast to-wei 1000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $POOL "borrow(address,uint256)" $DEBT_TOKEN $(cast to-wei 500 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $DEBT_TOKEN "approve(address,uint256)" $POOL $(cast to-wei 500 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $POOL "repay(address,uint256)" $DEBT_TOKEN $(cast to-wei 500 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $POOL "withdraw(address,uint256)" $TOKEN $(cast to-wei 100 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Views & liquidation
```bash
cast call $POOL "accountLiquidity(address)(uint256,uint256)" $USER --rpc-url $RPC  # (collateralUSD, debtUSD)
cast call $POOL "borrowBalance(address,address)(uint256)" $USER $DEBT_TOKEN --rpc-url $RPC
# liquidate when debtUSD > collateralUSD: repay debt, seize collateral + bonus
cast send $POOL "liquidate(address,address,uint256,address)" $BORROWER $DEBT_TOKEN $(cast to-wei 100 ether) $COLLAT_TOKEN \
  --rpc-url $RPC --private-key $PRIVATE_KEY
```
Reverts: `insufficient collateral` (borrow/withdraw breaks health), `borrower healthy` (liquidation).

---

## Stablecoin + CDPEngine
MakerDAO-style single-collateral CDP. Mint a USD stablecoin against collateral.

### Deploy
```bash
forge create src/lending/Stablecoin.sol:Stablecoin --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args "Pharos USD" "pUSD" $OWNER
export STABLE=<deployed>
forge create src/lending/CDPEngine.sol:CDPEngine --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $COLLATERAL $STABLE $ORACLE $OWNER
export CDP=<deployed>
# authorize the engine to mint/burn the stablecoin
cast send $STABLE "setMinter(address)" $CDP --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Operations
```bash
cast send $COLLATERAL "approve(address,uint256)" $CDP $(cast to-wei 1 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $CDP "deposit(uint256)" $(cast to-wei 1 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $CDP "mint(uint256)" $(cast to-wei 1000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY  # needs >=150% ratio
cast call $CDP "collateralRatio(address)(uint256)" $OWNER --rpc-url $RPC  # in BPS
cast send $CDP "burn(uint256)" $(cast to-wei 1000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $CDP "withdraw(uint256)" $(cast to-wei 1 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
# liquidate unsafe vault (ratio < 150%)
cast send $CDP "liquidate(address,uint256)" $USER $(cast to-wei 500 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
```
Reverts: `unsafe` (mint/withdraw drops below min ratio), `user safe` (liquidation).

---

## FlashLender (ERC-3156)
Single-token flash loans with a fee. LPs fund it; borrowers implement `IERC3156FlashBorrower`.

### Deploy
```bash
forge create src/lending/FlashLender.sol:FlashLender --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $TOKEN 9 $OWNER   # feeBps = 9 (0.09%)
# provide liquidity
cast send $TOKEN "approve(address,uint256)" $LENDER $(cast to-wei 100000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $LENDER "deposit(uint256)" $(cast to-wei 100000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Operations (read)
```bash
cast call $LENDER "maxFlashLoan(address)(uint256)" $TOKEN --rpc-url $RPC
cast call $LENDER "flashFee(address,uint256)(uint256)" $TOKEN $(cast to-wei 1000 ether) --rpc-url $RPC
```
`flashLoan(receiver, token, amount, data)` is called by a borrower contract whose
`onFlashLoan` returns `keccak256("ERC3156FlashBorrower.onFlashLoan")` and approves repayment
(amount + fee) back to the lender.
