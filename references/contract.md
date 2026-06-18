# Reference: Generic Contract Ops (deploy / verify / read / write)

Read `assets/networks.json` for `rpcUrl`, `chainId`, `explorerApiUrl`. Default network is
`atlantic-testnet` (688689).

## Deploy
```bash
forge create src/<path>.sol:<Contract> \
  --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args <arg1> <arg2> ...
```
Note: this repo builds with `via_ir = true` (set in `foundry.toml`) and OpenZeppelin v5.0.2.
Run `forge build` once before deploying.

## Verify (Blockscout / PharosScan)
```bash
sleep 10
forge verify-contract <ADDRESS> src/<path>.sol:<Contract> \
  --verifier blockscout \
  --verifier-url https://atlantic.pharosscan.xyz/api \
  --compiler-version 0.8.24 \
  --constructor-args $(cast abi-encode "constructor(<types>)" <args>)
```
If the verify API is bot-gated, verify via the explorer web UI using a flattened source:
`forge flatten src/<path>.sol:<Contract> > flat.sol`.

## Reads
```bash
cast balance <addr> --rpc-url $RPC --ether                       # native PHRS
cast call $TOKEN "balanceOf(address)(uint256)" <addr> --rpc-url $RPC
cast call $C "someView(uint256)(address)" 42 --rpc-url $RPC
cast tx <hash> --rpc-url $RPC
cast receipt <hash> status --rpc-url $RPC                        # 1 = success
cast logs --rpc-url $RPC --address $C "EventName(uint256,address)" --from-block 0
```

## Writes
```bash
cast send $C "fn(type1,type2)" arg1 arg2 --rpc-url $RPC --private-key $PRIVATE_KEY
cast send <to> --value $(cast to-wei 0.1 ether) --rpc-url $RPC --private-key $PRIVATE_KEY   # native transfer
cast estimate $C "fn(uint256)" 1 --rpc-url $RPC                                             # gas estimate
```
Simulate risky writes first with `cast call $C "fn(...)" ... --from $OWNER`; only `cast send`
if it succeeds.

## Script generation
JS (ethers v6), TS (viem), and Python (web3.py) interaction-script templates live in
`assets/templates/`. Read a template, substitute the RPC URL / chain ID (from
`assets/networks.json`), contract address, ABI, and method, and write a ready-to-run script.

## Common errors
`insufficient funds` (need PHRS for gas) · `execution reverted` (extract the revert reason) ·
`nonce too low` (retry) · command missing `--private-key` (configure the key).
