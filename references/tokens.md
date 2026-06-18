# Reference: Tokens

Common setup:
```bash
export PRIVATE_KEY=0xYOUR_KEY
export RPC=https://atlantic.dplabs-internal.com   # atlantic-testnet, chainId 688689
export OWNER=$(cast wallet address --private-key $PRIVATE_KEY)
```
Convert human amounts (18 decimals): `cast to-wei <amount> ether`.

---

## StandardERC20
Mintable, burnable, EIP-2612 permit ERC20 with an optional supply cap.

### Deploy
```bash
forge create src/tokens/StandardERC20.sol:StandardERC20 \
  --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args "Pharos Gold" "PGD" $(cast to-wei 1000000 ether) 0 $OWNER
```
Args: `name, symbol, initialSupply, cap (0=uncapped), owner`.

### Operations
```bash
cast send $TOKEN "mint(address,uint256)" $TO $(cast to-wei 1000 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $TOKEN "transfer(address,uint256)" $TO $(cast to-wei 50 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $TOKEN "burn(uint256)" $(cast to-wei 10 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $TOKEN "balanceOf(address)(uint256)" $OWNER --rpc-url $RPC
```
Errors: `CapExceeded(attempted,cap)` when a mint would pass the cap; `OwnableUnauthorizedAccount` if a non-owner mints.

---

## ERC20Factory
One-click deployment + registry of StandardERC20 tokens.

### Deploy
```bash
forge create src/tokens/ERC20Factory.sol:ERC20Factory --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast
```

### Operations
```bash
# create a token (caller becomes owner/minter); read the token address from the TokenCreated log
cast send $FACTORY "createToken(string,string,uint256,uint256)" "My Token" "MYT" $(cast to-wei 1000000 ether) 0 \
  --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $FACTORY "allTokensLength()(uint256)" --rpc-url $RPC
cast call $FACTORY "allTokens(uint256)(address)" 0 --rpc-url $RPC
```

---

## WrappedNative (WPHRS)
WETH-style wrapper for native PHRS; required by the DEX router.

### Deploy
```bash
forge create src/tokens/WrappedNative.sol:WrappedNative --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast
```

### Operations
```bash
cast send $WPHRS "deposit()" --value $(cast to-wei 1 ether) --rpc-url $RPC --private-key $PRIVATE_KEY  # wrap
cast send $WPHRS "withdraw(uint256)" $(cast to-wei 1 ether) --rpc-url $RPC --private-key $PRIVATE_KEY  # unwrap
cast call $WPHRS "balanceOf(address)(uint256)" $OWNER --rpc-url $RPC
```

---

## Faucet
Rate-limited ERC20 faucet for testnets.

### Deploy
```bash
forge create src/tokens/Faucet.sol:Faucet --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $TOKEN $(cast to-wei 100 ether) 86400 $OWNER
```
Args: `token, dripAmount, cooldown(sec), owner`. Fund it by transferring `token` to the faucet.

### Operations
```bash
cast send $FAUCET "claim()" --rpc-url $RPC --private-key $PRIVATE_KEY
```
Error: `CooldownActive(readyAt)` if claimed too soon.

---

## NFTCollection (ERC721)
Enumerable ERC721 with paid public mint + max supply.

### Deploy
```bash
forge create src/tokens/NFTCollection.sol:NFTCollection --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args "Pharos Punks" "PPUNK" "ipfs://CID/" 10000 $(cast to-wei 0.05 ether) $OWNER
```
Args: `name, symbol, baseURI, maxSupply (0=unlimited), mintPrice, owner`.

### Operations
```bash
cast send $NFT "mint()" --value $(cast to-wei 0.05 ether) --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $NFT "ownerMint(address)" $TO --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $NFT "withdraw(address)" $TO --rpc-url $RPC --private-key $PRIVATE_KEY
```
Errors: `WrongPrice(sent,required)`, `MaxSupplyReached()`.

---

## MultiToken (ERC1155)
ERC1155 with per-id supply tracking.

### Deploy
```bash
forge create src/tokens/MultiToken.sol:MultiToken --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args "Pharos Items" "ITEM" "ipfs://CID/{id}.json" $OWNER
```

### Operations
```bash
cast send $MT "mint(address,uint256,uint256,bytes)" $TO 1 100 0x --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $MT "balanceOf(address,uint256)(uint256)" $TO 1 --rpc-url $RPC
```
