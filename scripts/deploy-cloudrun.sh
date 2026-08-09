#!/usr/bin/env bash
# Local build → AR → Cloud Run. Prefer: push to main (Actions + WIF).
# Requires .env (see .env.example) or exported GCP_* / SERVICE_NAME / AR_REPO.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/lib/load-env.sh
source "$ROOT/scripts/lib/load-env.sh"

command -v gcloud >/dev/null || { echo "need gcloud" >&2; exit 1; }

PROJECT="${GCP_PROJECT:-${GCP_PROJECT_ID:-}}"
REGION="${GCP_REGION:?set GCP_REGION}"
SERVICE="${SERVICE_NAME:?set SERVICE_NAME}"
REPO="${AR_REPO:?set AR_REPO}"
IMAGE_NAME="${IMAGE_NAME:-$SERVICE}"
TAG="${TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo latest)}"
COUNT="${GIT_COMMIT_COUNT:-$(git rev-list --count HEAD 2>/dev/null || echo 0)}"

[[ -n "$PROJECT" ]] || { echo "set GCP_PROJECT" >&2; exit 1; }
gcloud config set project "$PROJECT" >/dev/null

IMAGE="${REGION}-docker.pkg.dev/${PROJECT}/${REPO}/${IMAGE_NAME}:${TAG}"
IMAGE_LATEST="${REGION}-docker.pkg.dev/${PROJECT}/${REPO}/${IMAGE_NAME}:latest"

if command -v podman >/dev/null; then CTR=podman
elif command -v docker >/dev/null; then CTR=docker
else echo "need podman or docker" >&2; exit 1
fi

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  "$CTR" build -f Containerfile --build-arg "GIT_COMMIT_COUNT=$COUNT" -t "$IMAGE" -t "$IMAGE_LATEST" .
fi

if [[ "${SKIP_PUSH:-0}" != "1" ]]; then
  gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
  [[ "$CTR" == podman ]] && gcloud auth print-access-token | podman login -u oauth2accesstoken --password-stdin "${REGION}-docker.pkg.dev"
  "$CTR" push "$IMAGE"
  "$CTR" push "$IMAGE_LATEST" || true
fi

gcloud run deploy "$SERVICE" \
  --project="$PROJECT" \
  --image "$IMAGE" \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --memory "${MEMORY:-512Mi}" \
  --cpu "${CPU:-1}" \
  --cpu-boost \
  --min-instances 0 \
  --max-instances "${MAX_INSTANCES:-2}" \
  --concurrency "${CONCURRENCY:-40}" \
  --timeout "${TIMEOUT:-60}" \
  --execution-environment gen1 \
  --set-env-vars "XSD_DIR=/app/XSD,MAX_XML_BYTES=10485760,PYTHONDONTWRITEBYTECODE=1,PYTHONUNBUFFERED=1" \
  --startup-probe="httpGet.path=/healthz,httpGet.port=8080,initialDelaySeconds=0,timeoutSeconds=2,periodSeconds=3,failureThreshold=15" \
  --liveness-probe="httpGet.path=/healthz,httpGet.port=8080,timeoutSeconds=3,periodSeconds=30,failureThreshold=3"

gcloud run services describe "$SERVICE" --project="$PROJECT" --region="$REGION" --format='value(status.url)'
