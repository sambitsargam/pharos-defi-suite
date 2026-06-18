# Reference: Governance

Setup as in `tokens.md`. A standard DAO = GovernanceToken + DefiTimelock + DefiGovernor, where
the Timelock owns the protocol and the Governor is the Timelock's proposer.

---

## GovernanceToken
ERC20 with vote delegation (ERC20Votes) + permit.

### Deploy & use
```bash
forge create src/governance/GovernanceToken.sol:GovernanceToken --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args "Pharos Gov" "gPHRS" $(cast to-wei 1000000 ether) $OWNER
# voting power is inactive until delegated (delegate to self to activate):
cast send $GOV_TOKEN "delegate(address)" $OWNER --rpc-url $RPC --private-key $PRIVATE_KEY
cast call $GOV_TOKEN "getVotes(address)(uint256)" $OWNER --rpc-url $RPC
```

---

## DefiGovernor + DefiTimelock
On-chain proposals executed through a timelock.

### Deploy
```bash
# 1) timelock: minDelay(sec), proposers, executors, admin
forge create src/governance/DefiTimelock.sol:DefiTimelock --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args 172800 "[]" "[0x0000000000000000000000000000000000000000]" $OWNER
export TIMELOCK=<deployed>
# 2) governor
forge create src/governance/DefiGovernor.sol:DefiGovernor --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args $GOV_TOKEN $TIMELOCK
export GOVERNOR=<deployed>
# 3) wire roles: grant PROPOSER_ROLE to the governor, then renounce admin (see TimelockController)
PROPOSER=$(cast call $TIMELOCK "PROPOSER_ROLE()(bytes32)" --rpc-url $RPC)
cast send $TIMELOCK "grantRole(bytes32,address)" $PROPOSER $GOVERNOR --rpc-url $RPC --private-key $PRIVATE_KEY
```

### Lifecycle
```bash
# propose(targets, values, calldatas, description)
cast send $GOVERNOR "propose(address[],uint256[],bytes[],string)" "[$TARGET]" "[0]" "[$CALLDATA]" "My proposal" \
  --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $GOVERNOR "castVote(uint256,uint8)" $PROPOSAL_ID 1 --rpc-url $RPC --private-key $PRIVATE_KEY  # 0=against,1=for,2=abstain
cast call $GOVERNOR "state(uint256)(uint8)" $PROPOSAL_ID --rpc-url $RPC
cast send $GOVERNOR "queue(address[],uint256[],bytes[],bytes32)" "[$TARGET]" "[0]" "[$CALLDATA]" $DESC_HASH --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $GOVERNOR "execute(address[],uint256[],bytes[],bytes32)" "[$TARGET]" "[0]" "[$CALLDATA]" $DESC_HASH --rpc-url $RPC --private-key $PRIVATE_KEY
```
Defaults: voting delay 1 block, voting period ~50400 blocks (~1 week), quorum 4%.
`DESC_HASH = cast keccak "My proposal"`.

---

## MultiSigWallet
m-of-n multisig that holds PHRS and can call any contract.

### Deploy & use
```bash
forge create src/governance/MultiSigWallet.sol:MultiSigWallet --rpc-url $RPC --private-key $PRIVATE_KEY --broadcast \
  --constructor-args "[$OWNER1,$OWNER2,$OWNER3]" 2   # 2-of-3
cast send $MS "submit(address,uint256,bytes)" $TO $(cast to-wei 1 ether) 0x --rpc-url $RPC --private-key $PRIVATE_KEY
cast send $MS "confirm(uint256)" 0 --rpc-url $RPC --private-key $PRIVATE_KEY   # each owner
cast send $MS "execute(uint256)" 0 --rpc-url $RPC --private-key $PRIVATE_KEY   # after >= required confirmations
```
