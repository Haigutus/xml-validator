#!/usr/bin/env bash
# Deploy to Google Cloud Run (scale-to-zero / free-tier friendly).
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

if [[ -z "$PROJECT" || "$PROJECT" == "(unset)" ]]; then
  echo "ERROR: set GCP project: gcloud config set project YOUR_PROJECT_ID" >&2
  exit 1
fi

IMAGE="${REGION}-docker.pkg.dev/${PROJECT}/${REPO}/${SERVICE}:${TAG}"

echo "==> Project=$PROJECT Region=$REGION Service=$SERVICE"
echo "==> Image=$IMAGE (app version 0.2.$GIT_COMMIT_COUNT)"

gcloud artifacts repositories describe "$REPO" --location="$REGION" >/dev/null 2>&1 || \
  gcloud artifacts repositories create "$REPO" \
    --repository-format=docker \
    --location="$REGION" \
    --description="Cloud Run images"

echo "==> Cloud Build (XSD baked into image)"
gcloud builds submit \
  --config=cloudbuild.yaml \
  --substitutions="_IMAGE=${IMAGE},_GIT_COMMIT_COUNT=${GIT_COMMIT_COUNT}"

echo "==> Deploy Cloud Run (min-instances=0)"
gcloud run deploy "$SERVICE" \
  --image "$IMAGE" \
  --region "$REGION" \
  --platform managed \
  --allow-unauthenticated \
  --port 8080 \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 3 \
  --concurrency 80 \
  --set-env-vars "XSD_DIR=/app/XSD,PORT=8080"

URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
echo "==> Live: $URL"
echo "    Map xsd.cimtools.eu: Cloud Run → Manage custom domains"
