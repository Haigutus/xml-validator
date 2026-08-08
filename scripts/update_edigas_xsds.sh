#!/usr/bin/env bash
# Download Edig@s 5.1 and 6.1 whole packages into XSD/ without removing older packages.
#
# Usage:
#   ./scripts/update_edigas_xsds.sh
#   ./scripts/update_edigas_xsds.sh 5.1          # only 5.1
#   ./scripts/update_edigas_xsds.sh 6.1          # only 6.1
#   EDIGAS_5_1_URL=... EDIGAS_6_1_URL=... ./scripts/update_edigas_xsds.sh
#
# Source: https://edigas.org/edigas/downloads/
# Official packages use dated filenames; this script scrapes the downloads page for the
# newest 5.1 / 6.1 full zips, with fallbacks if scraping fails.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p XSD

DOWNLOADS_PAGE="https://edigas.org/edigas/downloads/"
# Fallbacks (update if scrape fails and names change)
FALLBACK_5_1="https://edigas.org/_files/downloads/25_Edigas_5.1_full_2025-07-30.zip"
FALLBACK_6_1="https://edigas.org/_files/downloads/9_Edigas_6.1_full_2026-07-31.zip"

WANT="${1:-both}"   # both | 5.1 | 6.1

_fetch() {
  local url="$1" out="$2"
  echo "    GET $url"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$out" "$url"
  else
    wget -q -O "$out" "$url"
  fi
}

_discover_urls() {
  # Print: EDIGAS_5_1_URL=... and EDIGAS_6_1_URL=... if found on the page
  local html tmp
  tmp="$(mktemp)"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$DOWNLOADS_PAGE" -o "$tmp" 2>/dev/null || true
  else
    wget -q -O "$tmp" "$DOWNLOADS_PAGE" 2>/dev/null || true
  fi
  if [[ ! -s "$tmp" ]]; then
    rm -f "$tmp"
    return 0
  fi
  # Prefer absolute or site-relative links to full packages
  # e.g. /_files/downloads/25_Edigas_5.1_full_2025-07-30.zip
  local u5 u6
  u5="$(grep -oE '[^"[:space:]]*Edigas_5\.1_full_[0-9]{4}-[0-9]{2}-[0-9]{2}\.zip' "$tmp" | head -1 || true)"
  u6="$(grep -oE '[^"[:space:]]*Edigas_6\.1_full_[0-9]{4}-[0-9]{2}-[0-9]{2}\.zip' "$tmp" | head -1 || true)"
  rm -f "$tmp"
  if [[ -n "$u5" ]]; then
    [[ "$u5" != http* ]] && u5="https://edigas.org${u5}"
    echo "EDIGAS_5_1_URL=$u5"
  fi
  if [[ -n "$u6" ]]; then
    [[ "$u6" != http* ]] && u6="https://edigas.org${u6}"
    echo "EDIGAS_6_1_URL=$u6"
  fi
}

# Resolve URLs
eval "$(_discover_urls)"
EDIGAS_5_1_URL="${EDIGAS_5_1_URL:-$FALLBACK_5_1}"
EDIGAS_6_1_URL="${EDIGAS_6_1_URL:-$FALLBACK_6_1}"

_install_zip() {
  local label="$1" url="$2"
  local base stamp dest archive extract

  base="$(basename "$url")"
  base="${base%%\?*}"
  # Edigas_6.1_full_2026-07-31.zip -> EDIGAS_6.1_2026-07-31
  stamp="$(echo "$base" | sed -E 's/.*_full_([0-9]{4}-[0-9]{2}-[0-9]{2})\.zip/\1/')"
  if [[ "$stamp" == "$base" ]]; then
    stamp="$(date -u +%Y-%m-%d)"
  fi
  dest="XSD/${label}_${stamp}"

  if [[ -d "$dest" ]]; then
    echo "==> Already present: $dest (skip)"
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"
  archive="$tmp/pkg.zip"
  extract="$tmp/out"
  mkdir -p "$extract"

  echo "==> Downloading $label -> $dest"
  _fetch "$url" "$archive"
  unzip -qo "$archive" -d "$extract"

  mkdir -p "$dest"
  shopt -s nullglob
  local tops=("$extract"/*)
  if ((${#tops[@]} == 1)) && [[ -d "${tops[0]}" ]]; then
    # Prefer moving the single root folder's contents
    mv "${tops[0]}"/* "$dest/" 2>/dev/null || {
      rmdir "$dest" 2>/dev/null || true
      mv "${tops[0]}" "$dest"
    }
  else
    mv "$extract"/* "$dest/" 2>/dev/null || true
  fi
  rm -rf "$tmp"

  local count
  count="$(find "$dest" -name '*.xsd' 2>/dev/null | wc -l | tr -d ' ')"
  echo "    $count XSD file(s) in $dest"
}

echo "==> Edig@s XSD update (keeps existing trees: EAP-Schemas, older EDIGAS_*)"
echo "    5.1 URL: $EDIGAS_5_1_URL"
echo "    6.1 URL: $EDIGAS_6_1_URL"

case "$WANT" in
  both)
    _install_zip "EDIGAS_5.1" "$EDIGAS_5_1_URL"
    _install_zip "EDIGAS_6.1" "$EDIGAS_6_1_URL"
    ;;
  5.1|5)
    _install_zip "EDIGAS_5.1" "$EDIGAS_5_1_URL"
    ;;
  6.1|6)
    _install_zip "EDIGAS_6.1" "$EDIGAS_6_1_URL"
    ;;
  *)
    echo "Usage: $0 [both|5.1|6.1]" >&2
    exit 2
    ;;
esac

echo "==> Done. Legacy XSD/EAP-Schemas and any previous EDIGAS_* folders were left in place."
echo "    Restart the app to rebuild the in-memory XSD index."
echo "    Commit new XSD/EDIGAS_* trees if you want them in git."
