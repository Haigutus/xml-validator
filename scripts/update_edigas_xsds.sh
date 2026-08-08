#!/usr/bin/env bash
# Replace XSD/ENTSOG_EDIGAS/5.1 and/or 6.1 with latest Edig@s full packages.
#
# Usage:
#   ./scripts/update_edigas_xsds.sh          # both
#   ./scripts/update_edigas_xsds.sh 5.1
#   ./scripts/update_edigas_xsds.sh 6.1
#
# Source: https://edigas.org/edigas/downloads/
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DOWNLOADS_PAGE="https://edigas.org/edigas/downloads/"
FALLBACK_5_1="https://edigas.org/_files/downloads/25_Edigas_5.1_full_2025-07-30.zip"
FALLBACK_6_1="https://edigas.org/_files/downloads/9_Edigas_6.1_full_2026-07-31.zip"
WANT="${1:-both}"

_fetch() {
  echo "    GET $1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$2" "$1"
  else
    wget -q -O "$2" "$1"
  fi
}

_discover_urls() {
  local tmp u5 u6
  tmp="$(mktemp)"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$DOWNLOADS_PAGE" -o "$tmp" 2>/dev/null || true
  else
    wget -q -O "$tmp" "$DOWNLOADS_PAGE" 2>/dev/null || true
  fi
  [[ -s "$tmp" ]] || { rm -f "$tmp"; return 0; }
  u5="$(grep -oE 'href="[^"]*Edigas_5\.1_full_[0-9]{4}-[0-9]{2}-[0-9]{2}\.zip"' "$tmp" \
        | head -1 | sed -E 's/^href="//;s/"$//' || true)"
  u6="$(grep -oE 'href="[^"]*Edigas_6\.1_full_[0-9]{4}-[0-9]{2}-[0-9]{2}\.zip"' "$tmp" \
        | head -1 | sed -E 's/^href="//;s/"$//' || true)"
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

eval "$(_discover_urls)"
EDIGAS_5_1_URL="${EDIGAS_5_1_URL:-$FALLBACK_5_1}"
EDIGAS_6_1_URL="${EDIGAS_6_1_URL:-$FALLBACK_6_1}"

_install_zip() {
  local ver="$1" url="$2"
  local dest="XSD/ENTSOG_EDIGAS/${ver}"
  local tmp archive extract cur tops

  tmp="$(mktemp -d)"
  archive="$tmp/pkg.zip"
  extract="$tmp/out"
  mkdir -p "$extract"

  echo "==> Downloading Edig@s ${ver} -> ${dest}"
  _fetch "$url" "$archive"
  unzip -qo "$archive" -d "$extract"
  chmod -R u+rwX "$extract" 2>/dev/null || true

  cur="$extract"
  for _ in 1 2 3; do
    shopt -s nullglob
    tops=("$cur"/*)
    if ((${#tops[@]} == 1)) && [[ -d "${tops[0]}" ]] && ! compgen -G "$cur"/*.xsd > /dev/null; then
      cur="${tops[0]}"
    else
      break
    fi
  done

  rm -rf "$dest"
  mkdir -p "$dest"
  cp -a "$cur"/. "$dest"/
  chmod -R u+rwX "$dest" 2>/dev/null || true

  {
    echo "source_url=$url"
    echo "version=$ver"
    echo "fetched_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  } > "$dest/.package_source"

  echo "    Replaced ${dest} ($(find "$dest" -name '*.xsd' | wc -l | tr -d ' ') XSD file(s))"
  rm -rf "$tmp"
}

echo "==> Edig@s → XSD/ENTSOG_EDIGAS/{5.1,6.1}"
echo "    5.1: $EDIGAS_5_1_URL"
echo "    6.1: $EDIGAS_6_1_URL"

case "$WANT" in
  both)       _install_zip "5.1" "$EDIGAS_5_1_URL"; _install_zip "6.1" "$EDIGAS_6_1_URL" ;;
  5.1|5)      _install_zip "5.1" "$EDIGAS_5_1_URL" ;;
  6.1|6)      _install_zip "6.1" "$EDIGAS_6_1_URL" ;;
  *) echo "Usage: $0 [both|5.1|6.1]" >&2; exit 2 ;;
esac

echo "==> Done. Restart the app to rebuild the XSD index."
