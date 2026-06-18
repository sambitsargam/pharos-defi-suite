# Live Deployment — Pharos Atlantic Testnet

Network: **Pharos Atlantic Testnet** · chainId **688689** · RPC `https://atlantic.dplabs-internal.com` · Explorer `https://atlantic.pharosscan.xyz`

## Core stack (deployed & smoke-tested on-chain)

| Contract | Address |
|----------|---------|
| ERC20Factory | `0xe2eAcD348aa10d97551E02Ae7CD6AD735d535C8c` |
| WrappedNative (WPHRS) | `0xe18979a6d32652ddbfB96B3C64e6f56A04d77dEf` |
| DexFactory | `0x463F145De4CCD58DC15C7404E37A662731f34626` |
| DexRouter | `0x68C304093B0Ef178bd7c6bB935C85650eb2D4b3e` |
| SimpleOracle | `0xBf16Fd6167881034BA6ab25D542de2aE41cf2E45` |

## Live smoke test (verifiable on the explorer)

1. `ERC20Factory.createToken("Defi Gold","DGLD", 1,000,000, uncapped)` → token `0xeC14C09C61D40548a944ADB5Ab5B76aB68b19a8A` (1M minted to deployer).
2. `SimpleOracle.setPrice(DGLD, $2)` → reads back 2e18.
3. `DexFactory.createPair(DGLD, WPHRS)` → pair `0x0D7594E9ACCA62eea35917e1Ff5CC1F006185Cf2` (allPairsLength = 1).

Deployer: `0x218996B33147B62FC86e59200455708FBf25225d` (throwaway testnet key).

Deploy the remaining 20 modules with the `forge create` commands in `references/*.md`, or the
core stack via `script/DeploySuite.s.sol`.
