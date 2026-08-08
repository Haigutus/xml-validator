#!/usr/bin/env bash
# Build and run locally (default: baked XSD).
# Usage:
#   ./scripts/up.sh
#   ./scripts/up.sh --host-xsd
#   ./scripts/up.sh --detach
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

"$ROOT/scripts/build.sh"
exec "$ROOT/scripts/run.sh" "$@"
