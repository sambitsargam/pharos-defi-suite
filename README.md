# Pharos DeFi Suite

**Pharos DeFi Suite** is a complete DeFi protocol stack you operate through an AI agent on the
Pharos blockchain — **25 OpenZeppelin-v5 smart contracts across 8 modules**, deployed and
driven entirely with `cast`/`forge`. Ask in plain English and the agent deploys a token,
launches a DEX, provides liquidity, lends/borrows, mints a stablecoin, runs an airdrop, holds
an IDO, or stands up a DAO — no SDK, no glue code.

## What you can do

| Module | Capabilities |
|--------|--------------|
| **Tokens** | Create an ERC20 (mintable/burnable/capped), deploy via a factory, wrap/unwrap native PHRS (WPHRS), run a faucet, deploy an ERC721 collection or an ERC1155. |
| **DEX / AMM** | Launch a Uniswap-V2 DEX, create pairs, add/remove liquidity (token or native), multi-hop swaps, price quotes. |
| **Yield** | Single-asset staking with rewards, a multi-pool MasterChef farm, an ERC4626 vault, NFT staking. |
| **Lending** | Supply/borrow money market with collateral factors + liquidation, a MakerDAO-style stablecoin minted against collateral (CDP), ERC-3156 flash loans. |
| **Payments** | Token vesting (cliff + linear), per-second payment streams, Merkle airdrops, revenue splitting, OTC swaps. |
| **Fundraising** | Fixed-price token sale / IDO, all-or-nothing crowdfunding with refunds, liquidity locker. |
| **Governance** | ERC20Votes token, Governor + Timelock DAO, m-of-n multisig. |
| **Oracle** | Admin-set price feed, DEX TWAP oracle. |

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

### 3. Run it
Point your agent at [`SKILL.md`](SKILL.md). It reads the **Capability Index**, opens the
matching [`references/<module>.md`](references/), and runs the exact `cast`/`forge` command.
You can also run any command directly from the reference files.

## Examples

**Talk to the agent in plain English:**

| You say | The agent does |
|---------|----------------|
| "Create a token Gold (GLD) with 1,000,000 supply" | deploys `StandardERC20` |
| "Launch a DEX and add 1000 GLD / 1 PHRS of liquidity" | deploys `DexFactory` + `DexRouter`, calls `addLiquidityNative` |
| "Swap 100 GLD for PHRS" | `swapExactTokensForNative` |
| "Stake my LP tokens to earn rewards" | deploys/uses `StakingRewards` or `MasterChef` |
| "Supply 1000 USDC and borrow 500 DAI" | `LendingPool.supply` then `borrow` |
| "Mint 1000 pUSD against 1 WETH collateral" | `CDPEngine.deposit` + `mint` |
| "Airdrop these 5000 addresses" | deploys `MerkleDistributor` |
| "Set up a DAO with a 2-day timelock" | deploys `GovernanceToken` + `DefiTimelock` + `DefiGovernor` |

**Or run commands directly:**
```bash
# Create a token via the factory
cast send $FACTORY "createToken(string,string,uint256,uint256)" "Gold" "GLD" $(cast to-wei 1000000 ether) 0 \
  --rpc-url $RPC --private-key $PRIVATE_KEY

# Deploy the core stack (factory, WPHRS, DEX, oracle) in one shot
forge script script/DeploySuite.s.sol:DeploySuite --rpc-url $RPC --broadcast --private-key $PRIVATE_KEY
```

Every operation, with parameters and error notes, is documented in
[`references/`](references/). Live core deployment on Atlantic is in [DEPLOYMENT.md](DEPLOYMENT.md).
