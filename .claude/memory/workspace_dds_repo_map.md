---
name: workspace-dds-repo-map
description: "Where each repo in the D:\\Projects\\LnT\\XL300\\workspace-dds\\ tree lives on GitHub/Docker Hub and what it's for."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 9b811257-c8e6-4b22-866c-9d7d619f4638
  modified: 2026-09-07T15:38:15.002Z
---

All under GitHub user `umeshwalkar` unless noted:

- `xl300-dds-v2` -- normative DDS contract (IDL/QoS/config), no build system.
  `references/promp-1.md` inside it is the authoritative subsystem/sensor
  brief for anything not yet built.
- `uuv_interfaces` -- C++ codegen/build layer over `xl300-dds-v2` (submodule).
  See [[dds-pipeline-architecture]].
- `xl300-ctd-manager`, `xl300-svp-manager`, `xl300-ins-manager` -- consuming
  apps, submodule `uuv_interfaces`. Only `xl300-ctd-manager` was actually
  wired up as of 2026-08-29.
- `xl300-dev-base` -- the shared toolchain Docker image (fastddsgen/JDK,
  Fast-DDS, cmake, ccache). Published to **Docker Hub**
  (`docker.io/umeshwalkar/xl300-dev-base`), not GHCR (GHCR packages default
  private, see [[dds-pipeline-gotchas]]). Its own
  `.github/workflows/build-and-push.yml` publishes on `Dockerfile` pushes to
  `main`.
- `D:\Projects\LnT\XL300\workspace-mqtt\` -- the real, currently-running MQTT
  implementation (separate workspace, ground truth for real sensor payloads
  when grounding new DDS IDL).
- `D:\Projects\LnT\XL300\workspace-dds\xl300-dds\` -- first, superseded DDS
  attempt (Tier-0/Tier-1/k3s shape not used in v2).

**How to apply:** use this to resolve "which repo" before searching --
especially the Docker Hub vs GHCR distinction, which has bitten CI once
already.
