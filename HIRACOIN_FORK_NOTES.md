# Hiracoin Fork Notes

This tree is a first-pass HTMLCOIN-based fork configured for:

- Coin name: Hiracoin
- Symbol: HIR
- Maximum money range: 500,000,000,000 HIR
- Consensus style: HTMLCOIN-style hybrid PoW/PoS retained
- Target block spacing in this code pass: 1 second
- Decimal precision: 7 places (`COIN = 10000000`)

## Important Block-Time Note

The requested block time was 0.1 seconds. HTMLCOIN's inherited consensus
parameters and block timestamps are integer seconds (`uint32_t nTime`), so a
literal 0.1 second target cannot be represented by changing only
`nPowTargetSpacing` and related chain parameters.

This pass uses the practical minimum of 1 second. A true 0.1 second chain would
require deeper protocol work, including sub-second timestamps, difficulty and
staking logic changes, network relay tuning, mempool/DB pressure testing, and
wallet/explorer compatibility checks.

## Amount Precision Note

The requested maximum supply is 500,000,000,000 HIR. With the inherited
Bitcoin/HTMLCOIN 8-decimal base unit this would overflow the signed 64-bit
`CAmount` type. Hiracoin is therefore configured with 7 decimal places so the
full requested supply fits safely inside `CAmount`.

## Main Changes Made

- `src/amount.h`
  - `MAX_MONEY` set to `500000000000 * COIN`.
- `src/validation.cpp`
  - Removed HTMLCOIN-specific early premine/reimbursement subsidy.
  - Set base subsidy to `1000 * COIN`.
  - Removed the one-off HTMLCOIN `GetSubsidy` payout.
- `src/chainparams.cpp`
  - Replaced genesis timestamp text with Hiracoin text.
  - Set main/test/regtest network magic bytes to Hiracoin-specific values.
  - Set P2P ports:
    - mainnet: `5888`
    - testnet: `15888`
    - regtest: `25888`
  - Set target spacing to `1` second and adjustment windows to `60` blocks.
  - Cleared HTMLCOIN DNS/fixed seeds.
  - Replaced checkpoints with height-0 dynamic genesis checkpoints.
  - Set Bech32 prefixes:
    - mainnet: `hir`
    - testnet: `thir`
    - regtest: `rhir`
- `src/chainparamsbase.cpp`
  - Set RPC ports:
    - mainnet: `5889`
    - testnet: `15889`
    - regtest: `25889`
- `src/util/system.cpp`
  - Config file changed to `hiracoin.conf`.
  - Data directories changed to `Hiracoin` / `.hiracoin`.
- `src/util/validation.cpp`
  - Signed-message prefix changed to `Hiracoin Signed Message:\n`.
- `src/qt/bitcoinunits.cpp`
  - Display units changed from HTML/HTMLCOIN to HIR/Hiracoin.
- `configure.ac`
  - Binary names changed to `hiracoind`, `hiracoin-cli`, `hiracoin-qt`,
    `hiracoin-tx`, and `hiracoin-wallet`.
- `contrib/hiracoin-genesis.ps1`
  - Added a PowerShell helper to reproduce the genesis coinbase merkle root and
    search candidate nonces.

## Genesis Handling

The code currently computes `consensus.hashGenesisBlock = genesis.GetHash()` at
startup and asserts the genesis merkle root. The exact genesis hash assert was
removed for the fork because this workspace does not have the C++ build
toolchain needed to compile and print HTMLCOIN's final serialized block-header
hash.

Before public launch, build the daemon and log/print the computed
`consensus.hashGenesisBlock` for mainnet, testnet, and regtest, then replace the
dynamic height-0 checkpoints with fixed literal hashes.

## Next Required Steps Before Public Use

1. Build on Linux with the HTMLCOIN dependency set.
2. Start regtest and confirm block generation and staking behavior.
3. Print and pin mainnet/testnet/regtest genesis hashes.
4. Replace checkpoint public keys with Hiracoin-owned keys.
5. Add Hiracoin DNS seeds or static bootnodes.
6. Rebuild fixed seeds after bootnodes are stable.
7. Audit the 1-second target under multi-node testnet load.
8. Decide whether to keep smart-contract functionality enabled.
