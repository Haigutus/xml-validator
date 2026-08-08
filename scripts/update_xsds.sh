#!/usr/bin/env bash
# Replace ENTSO-E ESMP and/or Edig@s packages under fixed folder names.
#
#   ./scripts/update_xsds.sh           # both
#   ./scripts/update_xsds.sh entsoe
#   ./scripts/update_xsds.sh edigas
#   ./scripts/update_xsds.sh edigas 5.1
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

target="${1:-all}"
shift || true

case "$target" in
  all)
    "$ROOT/scripts/update_entsoe_xsds.sh"
    "$ROOT/scripts/update_edigas_xsds.sh" both
    ;;
  entsoe|cim|esmp)
    "$ROOT/scripts/update_entsoe_xsds.sh"
    ;;
  edigas|edig)
    "$ROOT/scripts/update_edigas_xsds.sh" "${1:-both}"
    ;;
  *)
    echo "Usage: $0 [all|entsoe|edigas] [5.1|6.1]" >&2
    exit 2
    ;;
esac

echo ""
echo "==> XSD top-level trees:"
ls -1 XSD/ | sed 's/^/    /'
