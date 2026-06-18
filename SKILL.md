---
name: pharos-defi-suite
description: >
  The complete DeFi toolkit for the Pharos blockchain. Deploy and operate a full on-chain
  financial stack via cast/forge: ERC20/ERC721/ERC1155 tokens, a Uniswap-V2 AMM (swap, add/
  remove liquidity), staking, yield farms (MasterChef), ERC4626 vaults, NFT staking, a
  Compound-style lending market, a MakerDAO-style stablecoin/CDP, ERC3156 flash loans, token
  vesting, payment streaming, Merkle airdrops, revenue splitters, OTC swaps, IDO/token sales,
  crowdfunding, liquidity lockers, ERC20Votes governance with Governor+Timelock, multisig, and
  price oracles (manual + DEX TWAP). Invoke whenever the user wants to do ANY DeFi action on
  Pharos / PHRS / PROS / atlantic-testnet: create a token, launch a DEX, provide liquidity,
  swap, stake, farm, lend, borrow, mint a stablecoin, take a flash loan, vest tokens, stream
  payments, run an airdrop, hold an IDO, set up a DAO, or lock liquidity.
version: 1.0.0
requires:
  anyBins:
  - cast
  - forge
---

# Pharos DeFi Suite

A complete, audited-pattern DeFi protocol suite for the Pharos blockchain, built on
OpenZeppelin v5 and deployed/operated through Foundry (`cast` / `forge`). Every module is a
self-contained skill: deploy the contract, then drive it with the command templates in the
matching `references/<module>.md` file.

## Prerequisites

1. **Install Foundry** (MANDATORY before any action):
   - Run `which cast`. If not found, install:
     ```bash
     curl -L https://foundry.paradigm.xyz | bash
     source ~/.zshenv && foundryup
     cast --version
     ```
   - If installation fails, inform the user and STOP.
2. **Build the contracts** (this repo uses OpenZeppelin + `via_ir`):
   ```bash
   forge install foundry-rs/forge-std OpenZeppelin/openzeppelin-contracts@v5.0.2
   forge build
   ```
3. **Configure a private key** for write operations: pass `--private-key $PRIVATE_KEY`
   explicitly on every `cast send` / `forge` command (Foundry does NOT read env vars
   automatically). Never log or commit the key.

## Network Configuration

Network info lives in `assets/networks.json` (Atlantic testnet + mainnet).

- **Default**: `atlantic-testnet` (chainId **688689**, native **PHRS**), used unless the user
  says otherwise.
- **Switching**: when the user says `mainnet`, read that entry's `rpcUrl` (chainId **1672**,
  native **PROS**) and warn prominently before any write.
- **Usage**: read `assets/networks.json` and fill `rpcUrl` into each `--rpc-url`. Verification
  also needs `chainId` and `explorerApiUrl`.

```bash
RPC_URL=$(jq -r '.networks[] | select(.name=="atlantic-testnet") | .rpcUrl' assets/networks.json)
```

## Module Map

| Module | Contracts | Reference |
|--------|-----------|-----------|
| Tokens | StandardERC20, ERC20Factory, WrappedNative (WPHRS), Faucet, NFTCollection (721), MultiToken (1155) | `references/tokens.md` |
| DEX / AMM | DexFactory, DexPair, DexRouter | `references/dex.md` |
| Yield | StakingRewards, MasterChef, YieldVault (ERC4626), NFTStaking | `references/yield.md` |
| Lending | LendingPool, Stablecoin, CDPEngine, FlashLender (ERC3156) | `references/lending.md` |
| Payments | TokenVesting, PaymentStream, MerkleDistributor, RevenueSplitter, OTCSwap | `references/payments.md` |
| Fundraising | TokenSale (IDO), Crowdfunding, LiquidityLocker | `references/fundraising.md` |
| Governance | GovernanceToken, DefiGovernor, DefiTimelock, MultiSigWallet | `references/governance.md` |
| Oracle | SimpleOracle, DexTWAPOracle | `references/oracle.md` |
| Generic | deploy / verify / read / write / script-gen | `references/contract.md` |

## Capability Index

Load the matching reference file for full command templates.

### Tokens
| User Need | Capability | Detailed Instructions |
|-----------|-----------|----------------------|
| Create / deploy an ERC20 token (mintable, burnable, capped) | `forge create StandardERC20` | → `references/tokens.md#standarderc20` |
| One-click token via factory | `cast send ERC20Factory.createToken` | → `references/tokens.md#erc20factory` |
| Wrap / unwrap native PHRS (WPHRS) | `cast send WrappedNative.deposit/withdraw` | → `references/tokens.md#wrappednative-wphrs` |
| Testnet token faucet | `cast send Faucet.claim` | → `references/tokens.md#faucet` |
| Deploy an NFT collection (ERC721) | `forge create NFTCollection` | → `references/tokens.md#nftcollection-erc721` |
| Deploy a multi-token (ERC1155) | `forge create MultiToken` | → `references/tokens.md#multitoken-erc1155` |

### DEX / AMM
| User Need | Capability | Detailed Instructions |
|-----------|-----------|----------------------|
| Launch a DEX (factory + router) | `forge create DexFactory` + `DexRouter` | → `references/dex.md#deploy-the-dex` |
| Create a trading pair | `cast send DexFactory.createPair` | → `references/dex.md#create-a-pair` |
| Add / remove liquidity (token or native) | `cast send DexRouter.addLiquidity*/removeLiquidity*` | → `references/dex.md#add-liquidity` |
| Swap tokens / native (exact in/out, multi-hop) | `cast send DexRouter.swap*` | → `references/dex.md#swap` |
| Quote a price / amounts out | `cast call DexRouter.getAmountsOut` | → `references/dex.md#quote` |

### Yield
| User Need | Capability | Detailed Instructions |
|-----------|-----------|----------------------|
| Single-asset staking with rewards | `forge create StakingRewards` | → `references/yield.md#stakingrewards` |
| Multi-pool yield farm | `forge create MasterChef` | → `references/yield.md#masterchef` |
| ERC4626 tokenized vault | `forge create YieldVault` | → `references/yield.md#yieldvault-erc4626` |
| Stake NFTs for rewards | `forge create NFTStaking` | → `references/yield.md#nftstaking` |

### Lending & Stablecoin
| User Need | Capability | Detailed Instructions |
|-----------|-----------|----------------------|
| Supply / borrow money market | `forge create LendingPool` | → `references/lending.md#lendingpool` |
| Mint a stablecoin against collateral (CDP) | `forge create Stablecoin` + `CDPEngine` | → `references/lending.md#stablecoin--cdpengine` |
| Flash loan (ERC3156) | `forge create FlashLender` | → `references/lending.md#flashlender` |

### Payments & Distribution
| User Need | Capability | Detailed Instructions |
|-----------|-----------|----------------------|
| Token vesting (cliff + linear) | `forge create TokenVesting` | → `references/payments.md#tokenvesting` |
| Payment streaming (per second) | `forge create PaymentStream` | → `references/payments.md#paymentstream` |
| Merkle airdrop | `forge create MerkleDistributor` | → `references/payments.md#merkledistributor` |
| Revenue / payment split | `forge create RevenueSplitter` | → `references/payments.md#revenuesplitter` |
| OTC / P2P token swap | `forge create OTCSwap` | → `references/payments.md#otcswap` |

### Fundraising
| User Need | Capability | Detailed Instructions |
|-----------|-----------|----------------------|
| Token sale / IDO / presale | `forge create TokenSale` | → `references/fundraising.md#tokensale` |
| Crowdfunding (goal + refund) | `forge create Crowdfunding` | → `references/fundraising.md#crowdfunding` |
| Lock liquidity / tokens | `forge create LiquidityLocker` | → `references/fundraising.md#liquiditylocker` |

### Governance
| User Need | Capability | Detailed Instructions |
|-----------|-----------|----------------------|
| Governance token (ERC20Votes) | `forge create GovernanceToken` | → `references/governance.md#governancetoken` |
| DAO governor + timelock | `forge create DefiTimelock` + `DefiGovernor` | → `references/governance.md#defigovernor--defitimelock` |
| Multisig wallet | `forge create MultiSigWallet` | → `references/governance.md#multisigwallet` |

### Oracle
| User Need | Capability | Detailed Instructions |
|-----------|-----------|----------------------|
| Manual price feed | `forge create SimpleOracle` | → `references/oracle.md#simpleoracle` |
| DEX TWAP oracle | `forge create DexTWAPOracle` | → `references/oracle.md#dextwaporacle` |

### Generic chain ops
| User Need | Capability | Detailed Instructions |
|-----------|-----------|----------------------|
| Deploy / verify any contract | `forge create` / `forge verify-contract` | → `references/contract.md` |
| Read balances / tx / contract calls | `cast balance` / `cast call` / `cast tx` | → `references/contract.md#reads` |
| Send native / write calls | `cast send` | → `references/contract.md#writes` |
| Generate JS/TS/Python interaction scripts | template-based | → `references/contract.md#script-generation` |

## Write Operation Pre-checks (required for all writes)

1. **Private key set?** `[ -n "$PRIVATE_KEY" ] && echo set || echo missing`. If missing, stop and ask.
2. **Derive address**: `cast wallet address --private-key $PRIVATE_KEY`.
3. **Confirm network**: read `assets/networks.json`; for mainnet, warn and require re-confirmation.
4. **Check balance**: `cast balance <addr> --rpc-url $RPC --ether` (need PHRS/PROS for gas).

## Security Reminders

- **Private keys**: pass via `--private-key $PRIVATE_KEY`; never hardcode, log, or commit.
- **Mainnet**: warn prominently and require explicit re-confirmation before any write.
- **Token decimals**: most modules assume 18-decimal tokens and (for lending/CDP) 1e18 USD
  oracle prices — confirm before using non-standard tokens.
- **Approvals**: write flows that pull tokens require a prior `approve` to the target contract.
- **Oracle risk**: `SimpleOracle` is owner-set (testnet/admin). Use `DexTWAPOracle` or a robust
  feed for production; never price collateral off a spot AMM read.
