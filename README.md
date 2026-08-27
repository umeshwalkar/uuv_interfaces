# uuv_interfaces

The DDS-generated-code distribution point for the XL300 DDS contract. Submodules
`xl300-dds-v2` (the normative contract — `DDS_Topic_Contract.md`, `idl/`,
`qos/`) directly, generates `fastddsgen` output from its **entire** `idl/` tree
(all 17 files as of `xl300-dds-v2@v0.1.0` — 7 grounded sensor/nav types + 10
provisional ⚠️ subsystem types, same discipline as the contract itself), and
commits that generated code so consuming apps never need `fastddsgen`/a JDK
installed at all — just the Fast-DDS runtime libs to link against.

| Path | What it is |
|---|---|
| `xl300-dds-v2/` | Git submodule, pinned to a specific `xl300-dds-v2` commit/tag. The contract itself lives there — this repo never hand-copies or edits it. |
| `gen.sh` | Runs `fastddsgen` over `xl300-dds-v2/idl/**/*.idl` (every file, not a subset) -> `generated/`. |
| `generated/*.{h,cxx,...}` | Committed `fastddsgen` output — **consumers compile this**, they don't need to run `gen.sh` themselves unless the submodule pointer moved. |
| `CMakeLists.txt` | Builds `generated/*.cxx` into one `xl300_dds_types` static library target, covering every type in the contract. |

## Why one library for everything, not a per-sensor subset
Every app links the same `xl300_dds_types` and uses whichever structs it needs —
simpler than deciding per-app which IDL files to vendor, and it's what
`xl300-dds-v2`'s own `gen.sh` already does (processes the whole `idl/` tree in
one pass). The 10 still-provisional ⚠️ subsystem types (HSS/PSS/CSS/EPDS/MNSS/
PCS/MPS/SES/DLS/TMBS — see `xl300-dds-v2/CLAUDE.md`) compile just as cleanly as
the 7 grounded ones; "provisional" is a field-correctness warning for whoever
implements against them, not a build-time restriction.

## Real bug this design already caught
Generating the full `idl/` tree together (not one file in isolation) surfaced a
genuine `fastddsgen` failure: `idl/actuator/actuator.idl` reaches `common.idl`
via two different include paths in one compile (`../common.idl` directly, and
transitively through `../health.idl` -> `common.idl`), and `fastddsgen` doesn't
dedupe by resolved path — it reprocessed `common.idl`'s module body twice and
failed with "already defined". Fixed upstream in `xl300-dds-v2/idl/common.idl`
with a standard include guard (2026-08-27) — this repo's submodule pointer
should stay at or after that fix.

## Updating the submodule
```bash
cd xl300-dds-v2
git fetch --tags
git checkout v0.1.1     # or whatever the next xl300-dds-v2 tag is
cd ..
git add xl300-dds-v2
./gen.sh
git add generated
git commit -m "Bump xl300-dds-v2 to v0.1.1, regenerate"
```
Always bump the submodule to a **tag**, not a floating branch — see
`xl300-dds-v2`'s own versioning discipline once it has more than one tag.

## Generate (only needed after a submodule bump)
```bash
git submodule update --init   # first clone, or if xl300-dds-v2/ is empty
./gen.sh
```
Requires `fastddsgen` on `PATH` — provided by `umeshwalkar/xl300-dev-base:0.1.0`.
**Not** `uuv-dev-base` — that's a different, smaller local image (built from
`workspace-mqtt\xl300-dev-base`) with only MQTT deps (`libmosquitto`), no
Fast-DDS/fastddsgen at all.

## Consuming from an app repo

Add as a git submodule:
```bash
git submodule add https://github.com/umeshwalkar/uuv_interfaces.git uuv_interfaces
```

In the app's `CMakeLists.txt`, after resolving Fast-DDS/`fastcdr` (or let this
repo's own `CMakeLists.txt` resolve them — it only does so if the consumer
hasn't already):
```cmake
add_subdirectory(uuv_interfaces)
target_link_libraries(my_app PRIVATE xl300_dds_types)
target_include_directories(my_app PRIVATE uuv_interfaces/generated)
```
`#include "common.h"`, `#include "health.h"`/`"healthPubSubTypes.h"`,
`#include "ctd.h"`/`"ctdPubSubTypes.h"`, etc. then resolve for whatever types
the app actually uses. Point `FASTRTPS_DEFAULT_PROFILES_FILE` at
`uuv_interfaces/xl300-dds-v2/qos/xl300_profiles.xml`.

**v1 scope note:** this still compiles `generated/*.cxx` once per consuming app's
build tree via `add_subdirectory` — it is not yet a single prebuilt binary shared
byte-for-byte across every app (that would need a real release/artifact pipeline
with ABI/compiler-version matching, e.g. baked into the `xl300-dev-base` Docker
image alongside Fast-DDS itself). This still gets the big win — one source of
truth, no per-app `fastddsgen`, no manual IDL copy-paste — cheaply.

## Provenance
Seeded 2026-08-27 as a flat copy of 3 files from `xl300-dds-v2` (`common`/
`health`/`ctd` only); restructured the same day to submodule `xl300-dds-v2`
directly and generate its **entire** `idl/` tree, after the full-set generation
run surfaced the `common.idl` include-guard bug above and confirmed the design
scales to all 17 files cleanly. `xl300-ctd-manager` (which still vendors its own
flat copy of `common`/`health`/`ctd` under `dds/`) has not yet been migrated to
consume this repo instead.
