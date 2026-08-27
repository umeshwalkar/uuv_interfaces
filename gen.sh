#!/usr/bin/env bash
# Generate type-support code from the FULL XL300 v2 IDL tree (xl300-dds-v2
# submodule) with Fast DDS Gen -- every .idl file in the contract, not a curated
# subset, so every app links one library and uses whatever types it needs.
#   git submodule update --init   (first time, or after the submodule pointer moves)
#   ./gen.sh                      -> generate C++ type support into ./generated
# Requires fastddsgen on PATH -- provided by umeshwalkar/xl300-dev-base:0.1.0
# (NOT uuv-dev-base, which is the MQTT-only toolchain image).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
IDL_DIR="${HERE}/xl300-dds-v2/idl"
OUT="${HERE}/generated"

if [[ ! -d "${IDL_DIR}" ]]; then
  echo "FATAL: ${IDL_DIR} not found -- run 'git submodule update --init' first." >&2
  exit 1
fi

# Clean re-run, flat output (same gotcha as xl300-dds-v2/gen.sh itself): fastddsgen
# mirrors any directory component of the INPUT path into its output dir, so cd into
# each file's own directory and pass a bare filename. rm -rf first so a stale
# nested layout from a previous run doesn't linger.
rm -rf "${OUT}"
mkdir -p "${OUT}"

# -I "${IDL_DIR}" so every file's #include "../common.idl" (etc.) resolves
# regardless of which subdirectory the input file lives in.
while IFS= read -r -d '' idl; do
  dir="$(dirname "${idl}")"
  file="$(basename "${idl}")"
  echo "[gen] ${idl#${IDL_DIR}/}"
  ( cd "${dir}" && fastddsgen -replace -d "${OUT}" -I "${IDL_DIR}" "${file}" )
done < <(find "${IDL_DIR}" -name '*.idl' -print0 | sort -z)

# contract_constants.hpp: domain id, topic name strings, QoS profile names,
# partition names -- generated from xl300-dds-v2's config/*.yaml, same
# single-source-of-truth treatment as the IDL types above. See
# gen_contract_constants.py's own docstring for why this parses the two YAML
# files by hand instead of depending on PyYAML.
python3 "${HERE}/gen_contract_constants.py" \
  "${HERE}/xl300-dds-v2/config/dds_domain.yaml" \
  "${HERE}/xl300-dds-v2/config/topic_registry.yaml" \
  "${OUT}/contract_constants.hpp"

echo "[OK] Generated into ${OUT}"
