#!/usr/bin/env bash
# Build the container image (XSD baked in).
# Usage: ./scripts/build.sh [image-tag]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/lib/load-env.sh
source "$ROOT/scripts/lib/load-env.sh"

IMAGE="${1:-${LOCAL_IMAGE:-xml-validator:latest}}"
export GIT_COMMIT_COUNT="${GIT_COMMIT_COUNT:-$(git rev-list --count HEAD 2>/dev/null || echo 0)}"

echo "==> Building $IMAGE (GIT_COMMIT_COUNT=$GIT_COMMIT_COUNT)"
if command -v podman >/dev/null 2>&1; then
  RUNTIME=podman
elif command -v docker >/dev/null 2>&1; then
  RUNTIME=docker
else
  echo "ERROR: need podman or docker" >&2
  exit 1
fi

$RUNTIME build -t "$IMAGE" -f Containerfile \
  --build-arg "GIT_COMMIT_COUNT=$GIT_COMMIT_COUNT" \
  .

echo "==> Built $IMAGE"
$RUNTIME images "$IMAGE"
