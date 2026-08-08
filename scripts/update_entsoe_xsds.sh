#!/usr/bin/env bash
# Download the latest ENTSO-E ESMP / CIM XSD package into XSD/ without removing older packages.
#
# Usage:
#   ./scripts/update_entsoe_xsds.sh
#   ENTSOE_XSD_URL=https://.../CIM_xsd_package_vYYYY.7z ./scripts/update_entsoe_xsds.sh
#
# Source: https://www.entsoe.eu/publications/electronic-data-interchange-edi-library/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p XSD

DEFAULT_URL="https://www.entsoe.eu/Documents/EDI/Library/CIM_xsd_package_v2026.7z"
ENTSOE_XSD_URL="${ENTSOE_XSD_URL:-$DEFAULT_URL}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

ARCHIVE="$TMPDIR/package"
echo "==> Downloading ENTSO-E CIM/ESMP XSDs"
echo "    $ENTSOE_XSD_URL"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL -o "$ARCHIVE" "$ENTSOE_XSD_URL"
elif command -v wget >/dev/null 2>&1; then
  wget -q -O "$ARCHIVE" "$ENTSOE_XSD_URL"
else
  echo "ERROR: need curl or wget" >&2
  exit 1
fi

# Derive folder name from URL filename
base="$(basename "$ENTSOE_XSD_URL")"
base="${base%%\?*}"
name="${base%.*}"   # strip .7z / .zip
# Prefer a stable prefix
dest_name="ENTSOE_${name}"
DEST="XSD/${dest_name}"

if [[ -d "$DEST" ]]; then
  echo "==> Destination already exists: $DEST"
  echo "    Skipping extract (delete the folder to re-download)."
  exit 0
fi

EXTRACT="$TMPDIR/extract"
mkdir -p "$EXTRACT"

_extract() {
  local kind
  kind="$(file -b "$ARCHIVE" 2>/dev/null || echo unknown)"
  case "$kind" in
    *7-zip*|*7z*)
      if ! command -v 7z >/dev/null 2>&1 && ! command -v 7za >/dev/null 2>&1; then
        echo "ERROR: need p7zip (7z) for .7z archives" >&2
        exit 1
      fi
      "$(command -v 7z || command -v 7za)" x -y -o"$EXTRACT" "$ARCHIVE" >/dev/null
      ;;
    *Zip*|*zip*)
      unzip -qo "$ARCHIVE" -d "$EXTRACT"
      ;;
    *)
      if command -v 7z >/dev/null 2>&1 || command -v 7za >/dev/null 2>&1; then
        "$(command -v 7z || command -v 7za)" x -y -o"$EXTRACT" "$ARCHIVE" >/dev/null
      else
        unzip -qo "$ARCHIVE" -d "$EXTRACT"
      fi
      ;;
  esac
}

_extract

mkdir -p "$DEST"
shopt -s nullglob
# If archive has a single top-level directory, use its contents
tops=("$EXTRACT"/*)
if ((${#tops[@]} == 1)) && [[ -d "${tops[0]}" ]]; then
  # If it already looks like CIM_*, keep that name as subfolder note in README via dest_name
  mv "${tops[0]}"/* "$DEST/" 2>/dev/null || mv "${tops[0]}" "$DEST/content"
else
  mv "$EXTRACT"/* "$DEST/" 2>/dev/null || true
fi

count="$(find "$DEST" -name '*.xsd' | wc -l | tr -d ' ')"
echo "==> Installed $count XSD file(s) -> $DEST"
echo "    Older ENTSO-E trees (e.g. XSD/CIM_*) were left unchanged."
echo "    Restart the app to rebuild the in-memory XSD index."
