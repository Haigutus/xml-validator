#!/usr/bin/env bash
# Deploy to Google Cloud Run optimized for free-tier / scale-to-zero cold starts.
#
# Prerequisites:
#   gcloud auth login && gcloud config set project YOUR_PROJECT_ID
#   gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com
#
# Usage:
#   ./scripts/deploy-cloudrun.sh
#   REGION=europe-west1 SERVICE=xml-validator ./scripts/deploy-cloudrun.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PROJECT="${GCP_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"
REGION="${REGION:-europe-west1}"
SERVICE="${SERVICE:-xml-validator}"
REPO="${ARTIFACT_REPO:-cloud-run-source-deploy}"
export GIT_COMMIT_COUNT="${GIT_COMMIT_COUNT:-$(git rev-list --count HEAD 2>/dev/null || echo 0)}"
TAG="${TAG:-$(git rev-parse --short HEAD 2>/dev/null || echo latest)}"

# Sizing tuned for free-tier cold starts (override as needed)
MEMORY="${MEMORY:-512Mi}"
CPU="${CPU:-1}"
MAX_INSTANCES="${MAX_INSTANCES:-2}"
CONCURRENCY="${CONCURRENCY:-40}"
TIMEOUT="${TIMEOUT:-60}"

if [[ -z "$PROJECT" || "$PROJECT" == "(unset)" ]]; then
  echo "ERROR: set GCP project: gcloud config set project YOUR_PROJECT_ID" >&2
  exit 1
fi

IMAGE="${REGION}-docker.pkg.dev/${PROJECT}/${REPO}/${SERVICE}:${TAG}"

echo "==> Project=$PROJECT Region=$REGION Service=$SERVICE"
echo "==> Image=$IMAGE (app version 0.2.$GIT_COMMIT_COUNT)"
echo "==> Cold-start profile: min=0 cpu-boost memory=$MEMORY concurrency=$CONCURRENCY"

gcloud artifacts repositories describe "$REPO" --location="$REGION" >/dev/null 2>&1 || \
  gcloud artifacts repositories create "$REPO" \
    --repository-format=docker \
    --location="$REGION" \
    --description="Cloud Run images"

echo "==> Cloud Build (XSD baked into image)"
gcloud builds submit \
  --config=cloudbuild.yaml \
  --substitutions="_IMAGE=${IMAGE},_GIT_COMMIT_COUNT=${GIT_COMMIT_COUNT}"

echo "==> Deploy Cloud Run (scale-to-zero free-tier best practices)"
# Notes:
#   --min-instances=0     free-tier friendly (cold starts OK)
#   --cpu-boost           extra CPU during container startup (faster boot)
#   --cpu / --memory      small footprint; 512Mi is enough with lazy XSD index
#   --concurrency=40      share one instance across parallel Dash users
#   --max-instances=2     cap cost if traffic spikes
#   --timeout=60          request budget; validation is usually fast
#   --cpu-throttling      default (CPU only while handling requests) — cheapest
#   --no-cpu-throttling   would cost more; do not use for free tier
#   health: /healthz      does not build XSD index
gcloud run deploy "$SERVICE" \
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
  --set-env-vars "XSD_DIR=/app/XSD,PORT=8080,MAX_XML_BYTES=10485760,PYTHONDONTWRITEBYTECODE=1,PYTHONUNBUFFERED=1" \
  --startup-probe="httpGet.path=/healthz,httpGet.port=8080,initialDelaySeconds=0,timeoutSeconds=3,periodSeconds=2,failureThreshold=15" \
  --liveness-probe="httpGet.path=/healthz,httpGet.port=8080,timeoutSeconds=3,periodSeconds=30,failureThreshold=3"

URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
echo "==> Live: $URL"
echo "    Map xsd.cimtools.eu: Cloud Run → Manage custom domains"
echo "    Cold start: first request after idle builds the XSD index lazily on first validate."
