#!/usr/bin/env bash
# Run the container locally.
#
# Usage:
#   ./scripts/run.sh                  # baked-in XSD (Cloud Run-like)
#   ./scripts/run.sh --host-xsd       # mount ./XSD over baked schemas
#   HOST_PORT=8030 ./scripts/run.sh
#   ./scripts/run.sh --detach
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/lib/load-env.sh
source "$ROOT/scripts/lib/load-env.sh"

IMAGE="${IMAGE:-${LOCAL_IMAGE:-xml-validator:latest}}"
HOST_PORT="${HOST_PORT:-8030}"
NAME="${CONTAINER_NAME:-xml-validator}"
DETACH=()
HOST_XSD=0

for arg in "$@"; do
  case "$arg" in
    --host-xsd|-H) HOST_XSD=1 ;;
    --detach|-d)   DETACH=(-d) ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
  esac
done

if command -v podman >/dev/null 2>&1; then
  RUNTIME=podman
elif command -v docker >/dev/null 2>&1; then
  RUNTIME=docker
else
  echo "ERROR: need podman or docker" >&2
  exit 1
fi

# Stop previous instance with same name (ignore errors)
$RUNTIME rm -f "$NAME" 2>/dev/null || true

VOL=()
if [[ "$HOST_XSD" == "1" ]]; then
  if [[ ! -d "$ROOT/XSD" ]]; then
    echo "ERROR: ./XSD not found for --host-xsd" >&2
    exit 1
  fi
  echo "==> Mounting host XSD/ over image schemas (read-only)"
  VOL=(-v "$ROOT/XSD:/app/XSD:ro")
else
  echo "==> Using XSD baked into the image"
fi

echo "==> Running $IMAGE on http://127.0.0.1:${HOST_PORT}"
$RUNTIME run --rm "${DETACH[@]}" \
  --name "$NAME" \
  -p "${HOST_PORT}:8080" \
  -e PORT=8080 \
  -e XSD_DIR=/app/XSD \
  "${VOL[@]}" \
  "$IMAGE"
