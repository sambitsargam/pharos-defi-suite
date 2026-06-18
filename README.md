# Pharos DeFi Suite

A Pharos Skill Engine skill that lets an AI agent deploy and operate a full DeFi stack on
Pharos via `cast`/`forge` — tokens, an AMM DEX, yield, lending, a CDP stablecoin, flash loans,
payments, fundraising, governance, and oracles.

## How to use it

1. Install & build

```bash
curl -L https://foundry.paradigm.xyz | bash && foundryup
forge install foundry-rs/forge-std OpenZeppelin/openzeppelin-contracts@v5.0.2
forge build
```

2. Set your key & network

```bash
export PRIVATE_KEY=0xYOUR_KEY
export RPC=https://atlantic.dplabs-internal.com   # Atlantic testnet (688689); mainnet: https://rpc.pharos.xyz
```

3. Run it

Point your agent at [`SKILL.md`](SKILL.md) — it maps your request to the right
`references/<module>.md` and runs the `cast`/`forge` command. Or run any command directly from
the reference files.
