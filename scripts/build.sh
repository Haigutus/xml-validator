#!/usr/bin/env bash
# Build local image (XSD baked in).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/lib/load-env.sh
source "$ROOT/scripts/lib/load-env.sh"

IMAGE="${1:-${LOCAL_IMAGE:?set LOCAL_IMAGE or pass image tag}}"
COUNT="${GIT_COMMIT_COUNT:-$(git rev-list --count HEAD 2>/dev/null || echo 0)}"

if command -v podman >/dev/null; then CTR=podman
elif command -v docker >/dev/null; then CTR=docker
else echo "need podman or docker" >&2; exit 1
fi

"$CTR" build -t "$IMAGE" -f Containerfile --build-arg "GIT_COMMIT_COUNT=$COUNT" .
