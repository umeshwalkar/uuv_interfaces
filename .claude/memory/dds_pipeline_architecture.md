---
name: dds-pipeline-architecture
description: "Why xl300-dds-v2 -> uuv_interfaces -> *-manager is three layers, not two, and the version-pairing tag convention between the first two."
metadata: 
  node_type: memory
  type: project
  originSessionId: 9b811257-c8e6-4b22-866c-9d7d619f4638
  modified: 2026-09-07T15:37:53.912Z
---

`xl300-dds-v2` (normative IDL/QoS/config contract, no build system) ->
`uuv_interfaces` (submodules it, runs fastddsgen over the full idl/ tree,
commits generated/*.{h,cxx}, builds one xl300_dds_types static lib target) ->
`xl300-ctd-manager`/`xl300-svp-manager`/`xl300-ins-manager` (submodule
uuv_interfaces, add_subdirectory() it, same compiler/Fast-DDS version since
every repo builds inside the same pinned xl300-dev-base image).

**Why:** `uuv_interfaces` exists so consuming apps never need fastddsgen/a JDK
installed -- explicitly considered and rejected collapsing it into
`xl300-dds-v2` directly, and rejected prebuilding it as a shared `.a` (the
generated `*CdrAux.ipp` files are header-only/inline templates, so a prebuilt
binary would still need ABI-matched headers -- little win, real ABI risk).

`uuv_interfaces` tags itself 1:1 with the `xl300-dds-v2` tag its `generated/`
was built from (v0.1.0, v0.1.1, v0.1.2, ...), so a pinned `uuv_interfaces`
version tells you exactly which contract version it's built against.
`sync-contract.yml` in `uuv_interfaces` auto-bumps+regenerates+build-verifies
via PR on new `xl300-dds-v2` tags (push-triggered via repository_dispatch,
6h poll as fallback), but tagging `uuv_interfaces` to match after merge, and
bumping the submodule pointer in each `*-manager` repo, both stay manual.

**How to apply:** full writeup (with the CI gotchas hit setting this up) lives
in `uuv_interfaces/docs/dds-contract-pipeline.md` in the repo itself -- read
that first for anything touching this pipeline, since it travels with the
repo and this memory may go stale. See also [[dds-pipeline-gotchas]] and
[[workspace-dds-repo-map]].
