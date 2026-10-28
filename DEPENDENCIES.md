# Vendored dependencies

These are ordinary source files, not submodules. Both dependencies were obtained
from their official repositories at the commits below. Upstream source files and
license text are unmodified. No dependency download is required during a build.

## OpenZeppelin Contracts v5.1.0

- Repository: <https://github.com/OpenZeppelin/openzeppelin-contracts>
- Commit: `69c8def5f222ff96f2b5beff05dfba996368aa79`
- Source: <https://github.com/OpenZeppelin/openzeppelin-contracts/tree/69c8def5f222ff96f2b5beff05dfba996368aa79>
- Location: `lib/openzeppelin-contracts/`
- License: MIT, included as `lib/openzeppelin-contracts/LICENSE`
- Included: only `ERC20.sol` and its transitive source dependencies:
  `IERC20.sol`, `IERC20Metadata.sol`, `Context.sol`, and `draft-IERC6093.sol`.
- Remapping: `@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/`
- Downloaded commit archive SHA-256:
  `b0d8bc73b249cee906d596cf8e63c6ea71a4311c4e2a45a0b253e060d6dd3ae8`

## forge-std v1.9.6

- Repository: <https://github.com/foundry-rs/forge-std>
- Commit: `3b20d60d14b343ee4f908cb8079495c07f5e8981`
- Source: <https://github.com/foundry-rs/forge-std/tree/3b20d60d14b343ee4f908cb8079495c07f5e8981>
- Location: `lib/forge-std/`
- License: MIT or Apache-2.0, included as `LICENSE-MIT` and `LICENSE-APACHE`
  in that directory.
- Included: complete upstream `src/` directory (test support only).
- Remapping: `forge-std/=lib/forge-std/src/`
- Downloaded commit archive SHA-256:
  `eb94c3bd026342ae6955ce08f76aad648c586c003acebf5ee5d9b419a417076c`

The archive hashes describe the exact GitHub codeload archives fetched while
vendoring. The upstream commit IDs and checked-in files define the dependency
versions; archives and compiler binaries are not included.

