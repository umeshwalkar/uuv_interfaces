#!/usr/bin/env bash
# Generate type-support code from the synced XL300 v2 IDLs with Fast DDS Gen.
#   ./gen.sh              -> generate C++ type support into ./generated
# Requires fastddsgen on PATH -- provided by umeshwalkar/xl300-dev-base:0.1.0
# (NOT uuv-dev-base, which is the MQTT-only toolchain image -- see this repo's
# README.md).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
IDL_DIR="${HERE}/idl"
OUT="${HERE}/generated"

# Clean re-run, flat output (same gotcha as xl300-dds-v2/gen.sh): fastddsgen mirrors
# any directory component of the INPUT path into its output dir, so cd into idl/
# and pass a bare filename.
rm -rf "${OUT}"
mkdir -p "${OUT}"

for idl in common health ctd; do
  echo "[gen] ${idl}.idl"
  ( cd "${IDL_DIR}" && fastddsgen -replace -d "${OUT}" -I . "${idl}.idl" )
done

echo "[OK] Generated into ${OUT}"
