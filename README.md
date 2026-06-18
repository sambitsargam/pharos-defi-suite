# Pharos DeFi Suite

> A complete, end-to-end **DeFi protocol suite** packaged as a [Pharos Skill Engine](https://github.com/PharosNetwork/pharos-skill-engine)
> skill. 25 audited-pattern contracts across 8 modules — every major DeFi primitive — that an
> AI agent can deploy and operate on Pharos through `cast`/`forge`.

Built on **OpenZeppelin v5** + **Foundry**, matching the official Pharos skill format
(`SKILL.md` frontmatter + capability index, `references/` command templates, `assets/`
config & script templates).

## Modules (25 contracts)

| Module | Contracts |
|--------|-----------|
| **Tokens** | `StandardERC20` (mint/burn/cap/permit), `ERC20Factory`, `WrappedNative` (WPHRS), `Faucet`, `NFTCollection` (ERC721), `MultiToken` (ERC1155) |
| **DEX / AMM** | `DexFactory`, `DexPair` (x*y=k, 0.30% fee, TWAP accumulators), `DexRouter` (liquidity + multi-hop swaps + native) |
| **Yield** | `StakingRewards` (Synthetix), `MasterChef` (multi-pool farm), `YieldVault` (ERC4626), `NFTStaking` |
| **Lending** | `LendingPool` (Compound-style money market), `Stablecoin` + `CDPEngine` (MakerDAO-style CDP), `FlashLender` (ERC-3156) |
| **Payments** | `TokenVesting` (cliff+linear), `PaymentStream` (Sablier-style), `MerkleDistributor` (airdrop), `RevenueSplitter`, `OTCSwap` |
| **Fundraising** | `TokenSale` (IDO), `Crowdfunding` (goal+refund), `LiquidityLocker` |
| **Governance** | `GovernanceToken` (ERC20Votes), `DefiGovernor` (Governor), `DefiTimelock`, `MultiSigWallet` |
| **Oracle** | `SimpleOracle`, `DexTWAPOracle` |

## How it works as a Skill

An AI agent reads [`SKILL.md`](SKILL.md) → matches the user's intent in the **Capability
Index** → opens the matching `references/<module>.md` → runs the exact `cast`/`forge` command.
No bespoke SDK — just Foundry CLI + this knowledge package.

## Quickstart

```bash
# 1) Foundry
curl -L https://foundry.paradigm.xyz | bash && foundryup
# 2) deps (OpenZeppelin pinned to a Paris-compatible release)
forge install foundry-rs/forge-std OpenZeppelin/openzeppelin-contracts@v5.0.2
# 3) build & test
forge build
forge test
```

### Deploy the core stack to Pharos
```bash
export PRIVATE_KEY=0xYOUR_KEY
forge script script/DeploySuite.s.sol:DeploySuite \
  --rpc-url https://atlantic.dplabs-internal.com --broadcast --private-key $PRIVATE_KEY
```
This deploys `ERC20Factory`, `WrappedNative`, `DexFactory`, `DexRouter`, and `SimpleOracle`.
Deploy individual modules with the `forge create` commands in each `references/*.md`.

## Networks

| Network | chainId | RPC | Native |
|---------|---------|-----|--------|
| Atlantic testnet (default) | 688689 | `https://atlantic.dplabs-internal.com` | PHRS |
| Mainnet | 1672 | `https://rpc.pharos.xyz` | PROS |

(See `assets/networks.json`.)

## Testing

`test/DefiSuite.t.sol` runs end-to-end integration tests across the core modules:

```
[PASS] test_DexAddLiquidityAndSwap   — add liquidity + constant-product swap
[PASS] test_StakingRewardsAccrue     — Synthetix reward accrual over time
[PASS] test_LendingSupplyBorrow      — supply collateral, borrow to the collateral-factor limit
[PASS] test_CDPMintAgainstCollateral — mint stablecoin within the 150% ratio, revert past it
```

## Security notes

- Built on **OpenZeppelin v5** (ReentrancyGuard, SafeERC20, Ownable, ERC4626, Governor,
  TimelockController, ERC20Votes, MerkleProof, ERC-3156 interfaces).
- Reentrancy guards on all value-moving flows; checks-effects-interactions throughout.
- **Assumptions** (documented per module): lending/CDP assume 18-decimal tokens and 1e18 USD
  oracle prices; `SimpleOracle` is admin-set — use `DexTWAPOracle` or a robust feed for
  production collateral pricing.
- Reference implementations for a hackathon/testnet. Get a professional audit before mainnet
  use with real value.

## License
MIT
