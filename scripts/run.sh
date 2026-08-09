#!/usr/bin/env bash
# Run local container. Flags: --host-xsd  --detach
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/lib/load-env.sh
source "$ROOT/scripts/lib/load-env.sh"

IMAGE="${IMAGE:-${LOCAL_IMAGE:?set LOCAL_IMAGE}}"
HOST_PORT="${HOST_PORT:?set HOST_PORT}"
NAME="${CONTAINER_NAME:?set CONTAINER_NAME}"
DETACH=()
HOST_XSD=0

for arg in "$@"; do
  case "$arg" in
    --host-xsd|-H) HOST_XSD=1 ;;
    --detach|-d) DETACH=(-d) ;;
  esac
done

if command -v podman >/dev/null; then CTR=podman
elif command -v docker >/dev/null; then CTR=docker
else echo "need podman or docker" >&2; exit 1
fi

$CTR rm -f "$NAME" 2>/dev/null || true

VOL=()
[[ "$HOST_XSD" == 1 ]] && VOL=(-v "$ROOT/XSD:/app/XSD:ro")

$CTR run --rm "${DETACH[@]}" --name "$NAME" \
  -p "${HOST_PORT}:8080" \
  -e PORT=8080 -e XSD_DIR=/app/XSD \
  "${VOL[@]}" \
  "$IMAGE"
