# squeek (SQK)

An immutable, fixed-supply ERC-20 built with OpenZeppelin Contracts. The entire
supply is minted once to the immediate deployer in the constructor.

## Token and deployment parameters

| Parameter | Value |
| --- | --- |
| Solidity contract | `SqueekToken` |
| Source | `src/SqueekToken.sol` |
| Token name | `squeek` |
| Symbol | `SQK` |
| Decimals | `18` |
| Supply in SQK | `1,000,000,000` |
| Supply in base units | `1000000000000000000000000000` (`10^27`) |
| Supply constant | `INITIAL_SUPPLY` |
| Constructor arguments | None (empty argument list) |
| Deployment native currency value | `0` |
| Initial recipient | Constructor `msg.sender` |
| Owner / administrator | None |
| Initialization or configuration calls | None |
| Intended launch chain | Ethereum, chain ID `1` |

Deploy the creation bytecode of `src/SqueekToken.sol:SqueekToken`. Its constructor
takes no addresses, strings, external services, or other parameters and makes no
external calls. It emits one `Transfer` event from the zero address for the full
supply. It works with both `CREATE` and `CREATE2`; there are no linked libraries.

When a factory creates the token, the factory receives all tokens, rather than
the account that called the factory. An EOA deploying directly receives the
whole supply itself. The contract does not use `tx.origin`.

For the IdentityMD launch, the separate factory and manifest process handles
distribution, the contributor share, pool creation, and the remainder. This
project supplies only the token: it does not preallocate tokens, open a pool,
implement a distributor, or create a launch manifest. The deployed contract is
ready for transfers immediately after construction.

## Behavior and assumptions

The requested token uses ordinary ERC-20 transfer and allowance semantics. No
tax, fee, burn, rebase, pause, blacklist, seizure, mint role, permit, proxy, or
upgrade mechanism is added. The deployer retains no special permissions after
receiving the initial supply. The supply remains constant for the contract's
entire lifetime.

- `transfer` and `transferFrom` deliver the exact amount and return `true` on
  success. Invalid operations revert with OpenZeppelin ERC-6093 custom errors.
- Zero-value transfers are valid and emit `Transfer`. Transfers to the zero
  address revert, including for zero amounts. Self-transfers retain the same
  balance but still require sufficient funds.
- `approve` replaces the caller's allowance for one spender and emits
  `Approval`. Zero revokes it. A zero-address spender is rejected; holders may
  approve without currently holding tokens.
- `transferFrom` requires the caller's allowance, even if the caller is also the
  source holder. Finite allowances decrease by the amount spent. An allowance
  of `type(uint256).max` remains unchanged. A transfer that reverts leaves both
  balances and allowances unchanged.
- OpenZeppelin v5 does not emit `Approval` when `transferFrom` consumes an
  allowance. Integrations should query `allowance` for its current value.
- Transfers do not call recipients or external services. Contracts can receive
  SQK without implementing a callback.
- There is no payable entry point, fallback handler, or asset recovery function.

All values passed to token functions use 18-decimal base units: one SQK is
`1000000000000000000` units. The test-only factories, addresses, and handlers in
`test/` are not deployment contracts or production configuration.

## Build and check

The root Foundry configuration pins Solidity `0.8.26`, the Cancun EVM target,
optimizer enabled with `200` runs, and `bytecode_hash = "none"`. The compiler
must be installed in the build environment. All Solidity dependencies are
vendored as ordinary files under `lib/`, with their licenses; no package
installation, Git submodules, RPC, keys, FFI, or filesystem permissions are
needed to compile or test. See [DEPENDENCIES.md](DEPENDENCIES.md) for pinned
upstream commits.

```sh
forge build
FOUNDRY_FUZZ_SEED=0x1d442710552a838389548a7f5974926cb99f2c3fe3f192b3665d26dfd747ada1 forge test
forge fmt --check
```

The seed above is the assignment's verifier seed. No seed is pinned in the
configuration, so the caller may override it. Default fuzzing uses 1,024 cases
per fuzz test. Stateful invariants run 256 sequences of depth 64, with unexpected
handler reverts treated as failures. Tests do not read or mutate environment
variables, call an RPC, depend on time, or rely on test order.

`test/SqueekToken.t.sol` tests metadata, the mint event and recipient, `CREATE2`
factory deployment, exact distribution and claim transfers, ordinary transfers,
approvals and revocation, finite/infinite allowances, failures and their state
rollback, and the absence of privileged entry points. Five fuzz tests exercise
amounts and allowances, including their boundaries.

`test/SqueekToken.invariant.t.sol` executes transfers, approvals, revocations,
delegated transfers, and rejected overspends among four actors. It checks total
supply, each balance, and every actor-to-actor allowance against an independent
model after each action.

Local distribution tests cover the token movements used by the launch. They do
not simulate Uniswap price discovery, liquidity accounting, or swaps. The supplied
protected suite depends on the network's separate launch harness and is run by
that verifier, not by this standalone project.

## After launch

There are no owner settings, setters, initialization steps, recurring jobs, or
administrative keys to maintain for this token.

The launch operator is responsible for deploying the intended compiled artifact,
verifying its source, confirming metadata and supply, and executing the launch's
external distribution and liquidity operations. Confirm the initial holder is
the deploying factory before those operations. Preserve the compiler settings
above when reproducing bytecode. Independent adversarial review and the launch
integration checks remain release responsibilities.

Holders are responsible for recipient addresses and spender approvals. Approve
only trusted spenders and suitable amounts; an unlimited allowance lets that
spender use all current and future tokens until revoked. When changing an
existing nonzero allowance, clients should revoke it, wait for confirmation, and
then set the new allowance to reduce the standard ERC-20 allowance-change race.
Revocation cannot undo spending already executed.

Transfers are final. SQK or other assets sent to this token contract, an
incompatible contract, or an inaccessible address cannot be rescued by an
administrator. Native currency forced into the contract cannot be withdrawn.

## Review scope

The local source review confirmed that only the constructor calls `_mint`, no
runtime entry point can mint or burn, and transfer/approval paths make no
external calls. Balance and allowance accounting is the unmodified pinned
OpenZeppelin implementation. Arithmetic uses integer base units, and no oracle,
randomness, signatures, or upgrade storage is involved.

Foundry build, unit tests, fuzz tests, stateful invariants, and formatting checks
are the local verification tools. Slither and Mythril were not run. These checks
are not an independent security audit.

