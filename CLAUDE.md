# uuv_interfaces

**Identity:** the C++ codegen/build layer between `xl300-dds-v2` (the
normative DDS contract) and every consuming app (`xl300-ctd-manager`,
`xl300-svp-manager`, `xl300-ins-manager`). Submodules `xl300-dds-v2`, runs
`fastddsgen` over its **entire** `idl/` tree, commits the generated
`.h`/`.cxx` output, and builds it into one `xl300_dds_types` static lib
target. Exists specifically so consuming apps never need `fastddsgen`/a JDK
installed themselves. Full architecture writeup, version-pairing convention,
and every CI gotcha hit setting up `sync-contract.yml` (GHCR default-private
packages, the permanently-broken `xl300-dev-base:0.1.0` tag, Docker-writes-
as-root breaking git checkout, the PR-creation permission setting, "Re-run
jobs" reusing the original commit) live in
[`docs/dds-contract-pipeline.md`](docs/dds-contract-pipeline.md) — **read
that before touching `sync-contract.yml`, `gen.sh`, or the submodule/tag
relationship with `xl300-dds-v2`.**

## Non-negotiables
- Don't collapse this repo into `xl300-dds-v2` (making `*-manager` apps
  submodule the contract directly), and don't replace the `add_subdirectory()`
  pattern with a prebuilt shared `.a` — both were deliberately considered and
  rejected. See `docs/dds-contract-pipeline.md` for why.
- Tag this repo 1:1 with the `xl300-dds-v2` tag `generated/` was built from
  (`v0.1.0`, `v0.1.1`, `v0.1.2`, ...). Do this only after the auto-opened
  bump PR is reviewed and merged — never tag ahead of what's actually merged.
- `xl300-dev-base:0.1.0` on Docker Hub has a permanently broken `fastddsgen`
  install (missing jar). Never re-pin `sync-contract.yml` or the local repro
  recipe back to `0.1.0` — use `0.1.1` or newer.
- After a version bump lands here, bumping the submodule pointer in each
  consuming `*-manager` repo stays a deliberate, separate, manual step — a
  contract bump reaching this repo isn't the same event as it reaching an app
  that ships on the vehicle.

## Where things are
- `xl300-dds-v2/` — git submodule, the contract itself. Never hand-edited here.
- `gen.sh` — runs `fastddsgen` over `xl300-dds-v2/idl/**/*.idl` -> `generated/`.
- `generated/*.{h,cxx,...}` — committed `fastddsgen` output; consumers compile
  this, they don't run `gen.sh` themselves.
- `.github/workflows/sync-contract.yml` — polls/dispatches on new
  `xl300-dds-v2` tags, regenerates + build-verifies inside
  `docker.io/umeshwalkar/xl300-dev-base`, opens a PR.
- `docs/dds-contract-pipeline.md` — the detailed reference this file points to.
