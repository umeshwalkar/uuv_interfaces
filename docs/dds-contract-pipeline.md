# DDS contract pipeline: architecture, conventions, gotchas

Working notes from setting up and debugging the `xl300-dds-v2` -> `uuv_interfaces`
-> `*-manager` pipeline (2026-08-27 through 2026-09-07). Not a replacement for each
repo's own README/CLAUDE.md -- this is the cross-repo picture and the operational
gotchas that aren't obvious from any single repo.

## The three layers, and why each exists

```
xl300-dds-v2          uuv_interfaces              xl300-ctd-manager (+ svp/ins managers)
(normative contract)  (C++ codegen/build layer)    (consuming app)
  idl/*.idl       -->    generated/*.{h,cxx}  -->    add_subdirectory(uuv_interfaces)
  config/*.yaml          (committed, fastddsgen      target_link_libraries(... xl300_dds_types)
  qos/*.xml               output + contract_
                           constants.hpp)
```

- **`xl300-dds-v2`** is the contract only: IDL, QoS profiles, topic/domain config,
  docs. No CMakeLists, no committed generated code. Touching it requires
  `fastddsgen` + a JDK.
- **`uuv_interfaces`** exists specifically so consuming apps *never need
  `fastddsgen`/a JDK installed at all* -- it submodules `xl300-dds-v2`, runs
  `gen.sh` over the **entire** `idl/` tree (not a per-app curated subset), commits
  the generated `.h`/`.cxx`, and builds it into one `xl300_dds_types` static lib
  target. Every consumer links the same library and uses whichever structs it
  needs.
- **`*-manager` apps** submodule `uuv_interfaces` and `add_subdirectory()` it --
  generated code is compiled once per consuming app's own build tree (same
  compiler/Fast-DDS version, since every repo builds inside the same pinned
  `xl300-dev-base` image), not shared as a prebuilt binary. Considered and
  rejected doing a prebuilt `.a` instead: the generated `*CdrAux.ipp` files are
  header-only/inline templates, so consumers would still need matching headers
  ABI-locked to the binary -- little actual win, real ABI risk.

**Do not collapse `xl300-dds-v2` and `uuv_interfaces`, and do not have
`*-manager` repos submodule `xl300-dds-v2` directly.** That would push the
`fastddsgen`/JDK dependency, the `gen.sh` path-mirroring workaround, the
`CMakeLists.txt` static-lib recipe, and the CI build-verify gate into every
consuming repo instead of paying for each once.

## Version-pairing convention

`uuv_interfaces` tags itself 1:1 with the `xl300-dds-v2` tag its `generated/`
was built from (`v0.1.0`, `v0.1.1`, `v0.1.2`, ...) so a consumer pinning a
`uuv_interfaces` version knows exactly which contract version it's building
against. `v0.1.0` was deliberately **not** back-tagged on `uuv_interfaces` --
that `xl300-dds-v2` commit predates a real fastddsgen bug fix (relative vs.
bare-filename `#include`s) and was never actually a working generated state.

## The automated sync pipeline

`uuv_interfaces/.github/workflows/sync-contract.yml`: on trigger, checks
`xl300-dds-v2` for a tag newer than the one pinned; if found, bumps the
submodule, regenerates + build-verifies inside the pinned `xl300-dev-base`
image, and opens a PR (bump + regenerated code together) -- nothing lands that
didn't actually build.

Two triggers:
- **Push-based** (primary): `xl300-dds-v2/.github/workflows/notify-uuv-interfaces.yml`
  fires a `repository_dispatch` (`xl300-dds-v2-tagged`) on every `v*` tag push,
  using a fine-grained PAT (`UUV_INTERFACES_DISPATCH_TOKEN` secret, scoped only
  to `uuv_interfaces`, Contents: read/write) since GitHub Actions can't natively
  trigger across repos without one.
- **Scheduled poll** (fallback net, every 6h): covers a silently-failed dispatch
  (expired token, API hiccup) so the repo doesn't drift from the contract
  unnoticed.

**What's still manual by design:** after the bump PR merges, tag `uuv_interfaces`
to match, then bump the `uuv_interfaces` submodule pointer in every consuming
`*-manager` repo separately. A contract bump reaching `uuv_interfaces` isn't the
same event as it reaching an app that ships on the vehicle.

## Gotchas hit and fixed (all in `sync-contract.yml`'s history)

1. **GHCR pulls return `denied` even for a "public" repo.** GHCR container
   packages default to *private* visibility independent of the source repo's
   own visibility. A different repo's Actions workflow pulling anonymously gets
   exactly this error. Fixed by publishing `xl300-dev-base` to Docker Hub
   (`docker.io/umeshwalkar/xl300-dev-base`) instead, which doesn't have this
   default-private behavior.
2. **`xl300-dev-base:0.1.0`'s `fastddsgen` is permanently broken** -- confirmed
   by pulling it fresh and testing directly: `/usr/local/bin/fastddsgen` (what
   actually resolves via `PATH`) points at a jar path
   (`/usr/local/share/fastddsgen/java/fastddsgen.jar`) that doesn't exist in
   that image at all. `0.1.1`'s `fastddsgen` resolves to
   `/opt/fastdds/.../scripts/fastddsgen` instead, which works. **Never re-pin to
   `0.1.0`** -- it's not a transient issue, that tag's content is just broken.
3. **`docker run` writes as root by default.** Regenerated files
   (`generated/*.{h,cxx}`) land on the GitHub runner's filesystem owned by
   root. The later PR-creation step's `git checkout` runs as the unprivileged
   `runner` user and can't unlink root-owned files ("Permission denied").
   Fixed with `sudo chown -R "$(id -u):$(id -g)" "${{ github.workspace }}"`
   right after the docker step (`ubuntu-latest` has passwordless sudo) --
   simpler and more robust than trying to run the container itself as a
   matched non-root UID (which has its own `$HOME`/passwd-entry edge cases).
4. **"GitHub Actions is not permitted to create or approve pull requests."**
   Repo setting, not a workflow bug: Settings -> Actions -> General ->
   "Workflow permissions" -> enable "Allow GitHub Actions to create and approve
   pull requests".
5. **Re-running a workflow via "Re-run jobs" reuses the original triggering
   commit SHA** -- it does *not* re-read the workflow file from the current
   branch tip. To actually test a fix to the workflow file itself, trigger a
   fresh run (Actions -> workflow name -> "Run workflow"), not a re-run of an
   old one.
6. **Git tags pushed to a local clone aren't on GitHub until explicitly
   pushed** (`git push origin <tag>`) -- `sync-contract.yml`'s
   `git fetch --tags origin` in a fresh CI checkout only sees what's actually
   on the remote.

## Local repro recipe

To reproduce `sync-contract.yml`'s regenerate+build step locally (Windows,
Docker Desktop, Git Bash):

```bash
cd uuv_interfaces
rm -rf build generated
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd):/work" -w /work \
  docker.io/umeshwalkar/xl300-dev-base:0.1.1 \
  bash -c "set -euo pipefail; chmod +x ./gen.sh && ./gen.sh && \
           cmake -B build -DCMAKE_BUILD_TYPE=Release && \
           cmake --build build -j4"
# afterwards, restore working tree to committed state:
rm -rf build generated
git checkout -- generated/ xl300-dds-v2
git submodule update xl300-dds-v2
```

`MSYS_NO_PATHCONV=1` avoids Git Bash mangling the `-v` mount path. Note: testing
`--user <uid>:<gid>` locally on Windows/Docker Desktop is not representative of
the native-Linux GitHub Actions runner (Docker Desktop's VM layer maps host UIDs
differently) -- don't trust a local pass/fail on that specific flag either way.
