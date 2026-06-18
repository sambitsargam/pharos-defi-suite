# Pharos DeFi Suite

A [Pharos Skill Engine](https://github.com/PharosNetwork/pharos-skill-engine) skill that lets
an AI agent (or you) deploy and operate a full DeFi stack on Pharos using `cast`/`forge` — 25
contracts across 8 modules, no SDK required.

## What it can do

Ask the agent in plain English, or run the commands in `references/<module>.md` yourself.

**Tokens** — create an ERC20 (mintable/burnable/capped), deploy via a factory, wrap/unwrap
native PHRS (WPHRS), run a testnet faucet, deploy an ERC721 NFT collection or an ERC1155.

**DEX / AMM** — launch a Uniswap-V2 DEX, create pairs, add/remove liquidity (token or native),
swap with multi-hop routing, read price quotes.

**Yield** — single-asset staking with rewards, a multi-pool MasterChef farm, an ERC4626 vault,
and NFT staking.

**Lending** — supply/borrow money market with collateral factors and liquidation, a
MakerDAO-style stablecoin minted against collateral (CDP), and ERC-3156 flash loans.

**Payments** — token vesting (cliff + linear), per-second payment streams, Merkle airdrops,
revenue splitting, and trustless OTC swaps.

**Fundraising** — fixed-price token sale / IDO, all-or-nothing crowdfunding with refunds, and
a liquidity locker.

**Governance** — an ERC20Votes token, a Governor + Timelock DAO, and an m-of-n multisig.

**Oracle** — an admin-set price feed and a DEX TWAP oracle.

## How to use it

### 1. Install & build
```bash
curl -L https://foundry.paradigm.xyz | bash && foundryup
forge install foundry-rs/forge-std OpenZeppelin/openzeppelin-contracts@v5.0.2
forge build
```

### 2. Set your key & network
```bash
export PRIVATE_KEY=0xYOUR_KEY
export RPC=https://atlantic.dplabs-internal.com   # Atlantic testnet (688689); mainnet: https://rpc.pharos.xyz
```

### 3. Use it as a skill
Point your agent at `SKILL.md`. The agent reads the **Capability Index**, matches your request
to the right `references/<module>.md`, and runs the exact `cast`/`forge` command. Example:

> "Create a token called Gold (GLD), deploy a DEX, and add 1000 GLD / 1 PHRS of liquidity."

The agent deploys `StandardERC20`, the `DexFactory`/`DexRouter`, then calls `addLiquidityNative`.

### 4. …or run commands directly
Every operation has a copy-paste template. Example — create a token via the factory:
```bash
cast send $FACTORY "createToken(string,string,uint256,uint256)" "Gold" "GLD" $(cast to-wei 1000000 ether) 0 \
  --rpc-url $RPC --private-key $PRIVATE_KEY
```
Example — deploy the core stack in one shot:
```bash
forge script script/DeploySuite.s.sol:DeploySuite --rpc-url $RPC --broadcast --private-key $PRIVATE_KEY
```

## Where each command lives

| Module | Contracts | Commands |
|--------|-----------|----------|
| Tokens | StandardERC20, ERC20Factory, WrappedNative, Faucet, NFTCollection, MultiToken | `references/tokens.md` |
| DEX | DexFactory, DexPair, DexRouter | `references/dex.md` |
| Yield | StakingRewards, MasterChef, YieldVault, NFTStaking | `references/yield.md` |
| Lending | LendingPool, Stablecoin, CDPEngine, FlashLender | `references/lending.md` |
| Payments | TokenVesting, PaymentStream, MerkleDistributor, RevenueSplitter, OTCSwap | `references/payments.md` |
| Fundraising | TokenSale, Crowdfunding, LiquidityLocker | `references/fundraising.md` |
| Governance | GovernanceToken, DefiGovernor, DefiTimelock, MultiSigWallet | `references/governance.md` |
| Oracle | SimpleOracle, DexTWAPOracle | `references/oracle.md` |
| Deploy/verify/read/write | — | `references/contract.md` |

## Networks

| Network | chainId | RPC |
|---------|---------|-----|
| Atlantic testnet (default) | 688689 | `https://atlantic.dplabs-internal.com` |
| Mainnet | 1672 | `https://rpc.pharos.xyz` |

A live core deployment (factory, WPHRS, DEX, oracle) on Atlantic is listed in
[DEPLOYMENT.md](DEPLOYMENT.md).

## Notes

- Built on OpenZeppelin v5; Solidity 0.8.24; `via_ir` enabled in `foundry.toml`.
- Lending/CDP assume 18-decimal tokens and 1e18 USD oracle prices. Use `DexTWAPOracle` (not a
  spot read) for production collateral pricing.
- Reference implementations for testnet/hackathon use — audit before mainnet value.

## License
MIT
