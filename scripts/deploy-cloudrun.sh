#!/usr/bin/env bash
# Optional *local* build → Artifact Registry → Cloud Run.
# Production path: push to main (GitHub Actions + WIF).
#
# Prerequisites:
#   gcloud auth login
#   cp .env.example .env   # optional local config
#
# Usage:
#   ./scripts/deploy-cloudrun.sh
#   make deploy
#   SKIP_BUILD=1 SKIP_PUSH=1 ./scripts/deploy-cloudrun.sh   # redeploy existing tag
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/lib/load-env.sh
source "$ROOT/scripts/lib/load-env.sh"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' not found" >&2
    exit 1
  }
}
need gcloud

NAME="${SERVICE_NAME:-xml-validator-cimtools}"
PROJECT="${GCP_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"
PROJECT="${PROJECT:-$NAME}"
REGION="${GCP_REGION:-${REGION:-europe-west1}}"
SERVICE="${SERVICE:-$NAME}"
REPO="${AR_REPO:-${ARTIFACT_REPO:-$NAME}}"
IMAGE_NAME="${IMAGE_NAME:-$NAME}"
DOMAIN="${DOMAIN:-}"

GIT_COMMIT_COUNT="${GIT_COMMIT_COUNT:-$(git rev-list --count HEAD 2>/dev/null || echo 0)}"
TAG="${TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo latest)}"

MEMORY="${MEMORY:-512Mi}"
CPU="${CPU:-1}"
MAX_INSTANCES="${MAX_INSTANCES:-2}"
CONCURRENCY="${CONCURRENCY:-40}"
TIMEOUT="${TIMEOUT:-60}"

if [[ -z "$PROJECT" || "$PROJECT" == "(unset)" ]]; then
  echo "ERROR: set GCP project in .env (GCP_PROJECT=…) or: gcloud config set project ID" >&2
  exit 1
fi
gcloud config set project "$PROJECT" >/dev/null

IMAGE="${REGION}-docker.pkg.dev/${PROJECT}/${REPO}/${IMAGE_NAME}:${TAG}"
IMAGE_LATEST="${REGION}-docker.pkg.dev/${PROJECT}/${REPO}/${IMAGE_NAME}:latest"

if command -v podman >/dev/null 2>&1; then
  CTR=podman
elif command -v docker >/dev/null 2>&1; then
  CTR=docker
else
  echo "ERROR: need podman or docker for local image build" >&2
  exit 1
fi

echo "==> Account:  $(gcloud config get-value account)"
echo "==> Project:  $PROJECT"
echo "==> Region:   $REGION"
echo "==> Service:  $SERVICE"
echo "==> Builder:  $CTR"
echo "==> Image:    $IMAGE"
echo "==> Version:  0.2.$GIT_COMMIT_COUNT"
echo "==> Profile:  min=0 cpu-boost memory=$MEMORY concurrency=$CONCURRENCY"
echo "    (Prefer: git push to main → GitHub Actions WIF deploy)"

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  echo "==> Build ($CTR)"
  "$CTR" build \
    -f Containerfile \
    --build-arg "GIT_COMMIT_COUNT=${GIT_COMMIT_COUNT}" \
    -t "$IMAGE" \
    -t "$IMAGE_LATEST" \
    .
fi

if [[ "${SKIP_PUSH:-0}" != "1" ]]; then
  echo "==> Registry auth: ${REGION}-docker.pkg.dev"
  gcloud auth configure-docker "${REGION}-docker.pkg.dev" --quiet
  if [[ "$CTR" == "podman" ]]; then
    gcloud auth print-access-token | podman login -u oauth2accesstoken --password-stdin \
      "${REGION}-docker.pkg.dev"
  fi
  echo "==> Push $IMAGE"
  "$CTR" push "$IMAGE"
  "$CTR" push "$IMAGE_LATEST" || echo "    (latest push optional)"
fi

echo "==> Deploy Cloud Run"
gcloud run deploy "$SERVICE" \
  --project="$PROJECT" \
  --image "$IMAGE" \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --memory "$MEMORY" \
  --cpu "$CPU" \
  --cpu-boost \
  --min-instances 0 \
  --max-instances "$MAX_INSTANCES" \
  --concurrency "$CONCURRENCY" \
  --timeout "$TIMEOUT" \
  --execution-environment gen1 \
  --set-env-vars "XSD_DIR=/app/XSD,MAX_XML_BYTES=10485760,PYTHONDONTWRITEBYTECODE=1,PYTHONUNBUFFERED=1" \
  --startup-probe="httpGet.path=/healthz,httpGet.port=8080,initialDelaySeconds=0,timeoutSeconds=2,periodSeconds=3,failureThreshold=15" \
  --liveness-probe="httpGet.path=/healthz,httpGet.port=8080,timeoutSeconds=3,periodSeconds=30,failureThreshold=3"

URL="$(gcloud run services describe "$SERVICE" --project="$PROJECT" --region="$REGION" --format='value(status.url)')"
echo "==> Live: $URL"
echo "    Custom domain (if mapped): https://xsd.cimtools.eu"

if [[ -n "$DOMAIN" ]]; then
  echo "==> Domain mapping: $DOMAIN"
  if ! gcloud beta run domain-mappings describe --domain="$DOMAIN" --region="$REGION" --project="$PROJECT" >/dev/null 2>&1; then
    gcloud beta run domain-mappings create \
      --service="$SERVICE" --domain="$DOMAIN" --region="$REGION" --project="$PROJECT"
  fi
  gcloud beta run domain-mappings describe --domain="$DOMAIN" --region="$REGION" --project="$PROJECT"
fi
