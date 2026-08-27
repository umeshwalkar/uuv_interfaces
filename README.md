# uuv_interfaces

The DDS-generated-code distribution point for the XL300 DDS contract. **Not** the
contract itself — `xl300-dds-v2` (`DDS_Topic_Contract.md`) stays the normative
source; this repo holds a synced copy of just the IDL/QoS files needed so far,
plus their `fastddsgen` output, committed to git so consuming apps never need
`fastddsgen`/a JDK installed at all — just the Fast-DDS runtime libs to link
against.

| Path | What it is |
|---|---|
| `idl/*.idl` | Synced copies of `xl300-dds-v2/idl/{common,health}.idl` and `xl300-dds-v2/idl/sensors/ctd.idl` (flattened — see each file's header comment). |
| `qos/xl300_profiles.xml` | Synced copy of `xl300-dds-v2/qos/xl300_profiles.xml`. |
| `gen.sh` | Runs `fastddsgen` over `idl/` -> `generated/`. |
| `generated/*.{h,cxx,...}` | Committed `fastddsgen` output — **consumers compile this**, they don't need to run `gen.sh` themselves unless the IDL changed. |
| `CMakeLists.txt` | Builds `generated/*.cxx` into a `xl300_dds_types` static library target. |

**Only `common`/`health`/`ctd` are synced so far** — this repo grows one IDL at a
time, as each sensor/subsystem actually gets built against `xl300-dds-v2`, the
same grounding discipline that repo itself follows (see its `CLAUDE.md`: nothing
gets modeled until a real implementation exists to ground it in). Don't
pre-populate every IDL in `xl300-dds-v2/idl/` speculatively.

## Resyncing from xl300-dds-v2
When `xl300-dds-v2`'s `CtdSample`, `Heartbeat`, `CommonHeader`, or the QoS
profiles change (or a new sensor/subsystem IDL needs adding here):
1. Copy the affected file(s) verbatim from `xl300-dds-v2` into `idl/`/`qos/` here
   (flattening any `idl/sensors/`-style subdirectory — keep everything flat).
2. Update `#include` paths inside the copied `.idl` file if it moved out of a
   subdirectory (drop any `../`).
3. Add a `// SYNCED COPY -- sourced from ...` header comment to the file, same
   style as the existing ones — do not silently drop this, it's the only thing
   that tells a future reader where to fix a bug for real.
4. `./gen.sh` (needs `fastddsgen` — see below), then commit both the changed
   `idl/`/`qos/` file and the regenerated `generated/` output together.

## Generate (only needed after a resync, or on first clone if `generated/` isn't
already committed for some reason)
```bash
./gen.sh
```
Requires `fastddsgen` on `PATH` — provided by `umeshwalkar/xl300-dev-base:0.1.0`.
**Not** `uuv-dev-base` — that's a different, smaller local image (built from
`workspace-mqtt\xl300-dev-base`) with only MQTT deps (`libmosquitto`), no
Fast-DDS/fastddsgen at all. See `xl300-ctd-manager/CLAUDE.md` for how this
naming mix-up was found and confirmed (2026-08-27).

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
`#include "common.h"`, `#include "health.h"`, `#include "healthPubSubTypes.h"`,
`#include "ctd.h"`, `#include "ctdPubSubTypes.h"` then resolve. Point
`FASTRTPS_DEFAULT_PROFILES_FILE` at `uuv_interfaces/qos/xl300_profiles.xml`.

**v1 scope note:** this still compiles `generated/*.cxx` once per consuming app's
build tree via `add_subdirectory` — it is not yet a single prebuilt binary shared
byte-for-byte across every app (that would need a real release/artifact pipeline
with ABI/compiler-version matching, e.g. baked into the `xl300-dev-base` Docker
image alongside Fast-DDS itself). This still gets the big win — one source of
truth, no per-app `fastddsgen`, no manual IDL copy-paste — cheaply. Revisit the
prebuilt-binary-in-the-dev-image idea once the submodule-and-compile-once pattern
is actually in use by more than one app.

## Provenance
Seeded 2026-08-27 from `xl300-dds-v2`'s `idl/common.idl`, `idl/health.idl`,
`idl/sensors/ctd.idl`, and `qos/xl300_profiles.xml` — the same three files
`xl300-ctd-manager/dds/` had vendored a flat, per-app copy of. This repo exists so
that vendoring only has to happen once, centrally, instead of once per app.
`xl300-ctd-manager` has not yet been migrated to consume this repo instead of its
own local copy.
