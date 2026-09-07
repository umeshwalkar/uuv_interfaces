---
name: dds-pipeline-gotchas
description: Specific CI/Docker bugs hit and fixed building sync-contract.yml -- check before re-debugging the same symptom.
metadata: 
  node_type: memory
  type: project
  originSessionId: 9b811257-c8e6-4b22-866c-9d7d619f4638
  modified: 2026-09-07T15:38:04.963Z
---

Debugging `uuv_interfaces/.github/workflows/sync-contract.yml` (2026-08-29)
surfaced several non-obvious bugs. Full detail in
`uuv_interfaces/docs/dds-contract-pipeline.md`; short version:

- **GHCR pulls return `denied` even for a "public" repo**: GHCR container
  packages default to *private* visibility independent of the source repo's
  visibility. Fixed by publishing `xl300-dev-base` to Docker Hub
  (`docker.io/umeshwalkar/xl300-dev-base`) instead.
- **`xl300-dev-base:0.1.0`'s fastddsgen is permanently broken** (not
  transient) -- `/usr/local/bin/fastddsgen`, what PATH actually resolves,
  points at a jar that doesn't exist in that image. `0.1.1`+ works. Never
  re-pin to `0.1.0`.
- **`docker run` writes as root by default** -> regenerated files land
  root-owned on the GH runner -> later `git checkout` (unprivileged `runner`
  user) fails to unlink them. Fix: `sudo chown -R "$(id -u):$(id -g))"
  "${{ github.workspace }}"` right after the docker step, not `--user` on the
  container itself (which has its own $HOME/passwd-entry edge cases and is
  hard to verify locally on Windows/Docker Desktop anyway).
- **"GitHub Actions is not permitted to create or approve pull requests"**:
  repo setting (Settings -> Actions -> General -> Workflow permissions),
  not a workflow bug.
- **"Re-run jobs" reuses the original triggering commit SHA** -- doesn't
  re-read the workflow file from the branch tip. To test a workflow-file fix,
  dispatch fresh ("Run workflow"), don't re-run an old failed run.

**How to apply:** hit any of these symptoms again (denied pull, jarfile error,
permission denied unlink, PR creation refused, a fix that "didn't take")
anywhere in this workspace's CI -- check this list before re-diagnosing from
scratch. See also [[dds-pipeline-architecture]].
