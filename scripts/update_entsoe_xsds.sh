#!/usr/bin/env bash
# Replace XSD/ENTSOE_ESMP with the latest ENTSO-E ESMP / CIM XSD package.
#
# Usage:
#   ./scripts/update_entsoe_xsds.sh
#   ENTSOE_XSD_URL=https://.../CIM_xsd_package_vYYYY.7z ./scripts/update_entsoe_xsds.sh
#
# Source: https://www.entsoe.eu/publications/electronic-data-interchange-edi-library/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEST="XSD/ENTSOE_ESMP"
DEFAULT_URL="https://www.entsoe.eu/Documents/EDI/Library/CIM_xsd_package_v2026.7z"
ENTSOE_XSD_URL="${ENTSOE_XSD_URL:-$DEFAULT_URL}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

ARCHIVE="$TMPDIR/package"
EXTRACT="$TMPDIR/extract"
mkdir -p "$EXTRACT"

echo "==> Downloading ENTSO-E ESMP / CIM XSDs"
echo "    $ENTSOE_XSD_URL"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL -o "$ARCHIVE" "$ENTSOE_XSD_URL"
else
  wget -q -O "$ARCHIVE" "$ENTSOE_XSD_URL"
fi

_extract_7z() {
  if command -v 7z >/dev/null 2>&1 || command -v 7za >/dev/null 2>&1; then
    "$(command -v 7z || command -v 7za)" x -y -o"$EXTRACT" "$ARCHIVE" >/dev/null
    return
  fi
  if command -v uv >/dev/null 2>&1; then
    echo "    (extracting with uv + py7zr)"
    uv run --with py7zr python - "$ARCHIVE" "$EXTRACT" <<'PY'
import sys
from pathlib import Path
import py7zr
archive, out = Path(sys.argv[1]), Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
with py7zr.SevenZipFile(archive, mode="r") as z:
    z.extractall(path=out)
PY
    return
  fi
  echo "ERROR: need p7zip (7z) or uv for .7z" >&2
  exit 1
}

kind="$(file -b "$ARCHIVE" 2>/dev/null || echo unknown)"
case "$kind" in
  *7-zip*|*7z*) _extract_7z ;;
  *Zip*|*zip*)  unzip -qo "$ARCHIVE" -d "$EXTRACT" ;;
  *)            _extract_7z ;;
esac

chmod -R u+rwX "$EXTRACT" 2>/dev/null || true

# Unwrap single-directory wrappers
cur="$EXTRACT"
for _ in 1 2 3; do
  shopt -s nullglob
  tops=("$cur"/*)
  if ((${#tops[@]} == 1)) && [[ -d "${tops[0]}" ]] && ! compgen -G "$cur"/*.xsd > /dev/null; then
    cur="${tops[0]}"
  else
    break
  fi
done

rm -rf "$DEST"
mkdir -p "$DEST"
cp -a "$cur"/. "$DEST"/
chmod -R u+rwX "$DEST" 2>/dev/null || true

{
  echo "source_url=$ENTSOE_XSD_URL"
  echo "fetched_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} > "$DEST/.package_source"

count="$(find "$DEST" -name '*.xsd' | wc -l | tr -d ' ')"
echo "==> Replaced $DEST ($count XSD file(s))"
echo "    Restart the app to rebuild the XSD index."
