# SQK test properties

The suite tests `src/SqueekToken.sol` through its public interface. The expected
supply is independently fixed at `1_000_000_000 * 10 ** 18`; it is not derived from
the implementation's `INITIAL_SUPPLY` getter. No token storage is overwritten and
no test-only mint function is added to the token.

`SqueekToken.t.sol` retains the existing deployment, metadata, transfer, approval,
event, failure-path and unavailable-admin-call tests. `SqueekToken.properties.t.sol`
adds allowance boundaries and sequences, rollback properties, exact round trips,
and all five identity partitions of owner, spender and recipient. Each stateless
fuzz property runs 1,024 cases. Plain tests pin zero, one base unit, the entire
supply, `uint256.max - 1`, and `uint256.max` where applicable.

The invariant review considered these five perspectives from the supplied testing
references. These are properties of this fixed-supply ERC-20, not assumptions about
vaults, prices, or an external AMM:

| Perspective | Property and source | Test coverage |
| --- | --- | --- |
| Conservation | The constructor mints exactly the requested supply once (`src/SqueekToken.sol:11-14`); transfers preserve it. | Sum of all tracked balances and total supply equal the independently specified supply after every handler call. |
| State transitions | Approvals replace a specific owner's permission for a specific spender; finite allowances are consumed and failed calls are atomic (`ERC20.sol:127-153,280-310`). | Full allowance matrix checked against a ghost model, including replacement, revocation, exhaustion, identity aliasing and rollback. |
| Round trips | Exact integer transfers have no fees or decimal conversion (`ERC20.sol:183-210`). | Direct and delegated round trips restore balances exactly; intermediate balances are checked so no-op transfers cannot pass. |
| Adversarial sequences | Approval cannot create funds or bypass another holder's authorization (`ERC20.sol:188-195,301-310`). | Overspending, insufficient approval, overfunded approvals with insufficient balances, refill after exhaustion and nontransitive permissions. |
| Token semantics | Zero recipients and zero spenders are invalid; a full-balance transfer remains possible (`ERC20.sol:166-173,280-287`). | Invalid-address calls mixed with valid calls, and guaranteed full-balance moves between distinct actors. |

Here `ERC20.sol` refers to the vendored
`lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol`. Infinite allowance
behavior is grounded in that dependency's documented convention; only
`uint256.max`, not `uint256.max - 1`, is the infinite sentinel.

The existing four-actor invariant model is extended with six actions. A funded
actor is selected for full-balance moves, nonzero approve-and-spend operations and
round trips. These run alongside independently generated approvals and delegated
spends, so the campaign reaches useful transfers as well as stale permissions.
Invalid-recipient, invalid-spender and underfunded delegated calls require specific
errors; balances and allowances must still match the model afterward. Expected
reverts are handled explicitly, and an unexpected handler revert fails the run.

Only the handler is targeted. Every valid recipient belongs to the tracked actor
set, making the balance sum complete. Assertions that the test, handler and token
contract have zero balances describe this closed test population; they do not
claim that ERC-20 transfers to contracts are forbidden. Inline configuration sets
256 invariant sequences of depth 128, with `fail-on-revert` enabled.

Run the build and suite without downloading dependencies:

```sh
forge build --offline --out test/scratch/out --cache-path test/scratch/cache
FOUNDRY_FUZZ_SEED=0x1d442710552a838389548a7f5974926cb99f2c3fe3f192b3665d26dfd747ada1 forge test --offline --out test/scratch/out --cache-path test/scratch/cache
```

The scratch paths are only compiler output and cache destinations. No delivered
test imports from scratch. All Solidity dependencies are already vendored in the
project. These are local token tests; they do not execute the external factory,
Merkle distributor or Uniswap pool integration in the protected launch harness.
