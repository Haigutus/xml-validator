# Local helpers for xml-validator.
# Config: copy .env.example → .env (gitignored). CI uses GitHub Variables + WIF.
#
#   make help
#   make run
#   make deploy   # optional local path; preferred prod path is push to main

.PHONY: help env sync run dev build up up-host deploy logs clean update-xsds vendor-ace

ifneq (,$(wildcard .env))
  include .env
  export
endif

HOST_PORT       ?= 8030
LOCAL_IMAGE     ?= xml-validator:latest
CONTAINER_NAME  ?= xml-validator
GCP_PROJECT     ?= $(shell gcloud config get-value project 2>/dev/null)
GCP_REGION      ?= europe-west1
SERVICE_NAME    ?= xml-validator
AR_REPO         ?= xml-validator

export GCP_PROJECT GCP_REGION SERVICE_NAME AR_REPO HOST_PORT LOCAL_IMAGE CONTAINER_NAME
export IMAGE ?= $(LOCAL_IMAGE)

help: ## Show targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

env: ## Create .env from example if missing
	@if [[ -f .env ]]; then echo ".env already exists"; \
	else cp .env.example .env && echo "Created .env — set GCP_PROJECT and names"; fi

sync: ## Install Python deps with uv
	uv sync

dev: ## Run app on host (uv) → default :8030
	uv run python app.py

build: ## Build local container image (XSD baked in)
	./scripts/build.sh $(LOCAL_IMAGE)

run: ## Run container (baked XSD) → http://127.0.0.1:$(HOST_PORT)
	IMAGE=$(LOCAL_IMAGE) HOST_PORT=$(HOST_PORT) CONTAINER_NAME=$(CONTAINER_NAME) \
	  ./scripts/run.sh

run-host-xsd: ## Run container with ./XSD mounted over baked schemas
	IMAGE=$(LOCAL_IMAGE) HOST_PORT=$(HOST_PORT) CONTAINER_NAME=$(CONTAINER_NAME) \
	  ./scripts/run.sh --host-xsd

up: build run ## Build + run (baked XSD)

up-host: ## Build + run with host XSD mount
	./scripts/build.sh $(LOCAL_IMAGE)
	IMAGE=$(LOCAL_IMAGE) HOST_PORT=$(HOST_PORT) CONTAINER_NAME=$(CONTAINER_NAME) \
	  ./scripts/run.sh --host-xsd

deploy: ## Local build/push/deploy to Cloud Run (optional; prefer git push to main)
	@test -n "$(GCP_PROJECT)" || (echo "ERROR: set GCP_PROJECT in .env or gcloud config" >&2; exit 1)
	./scripts/deploy-cloudrun.sh

logs: ## Tail Cloud Run logs
	@test -n "$(GCP_PROJECT)" || (echo "ERROR: set GCP_PROJECT in .env" >&2; exit 1)
	gcloud run services logs read $(SERVICE_NAME) \
	  --project=$(GCP_PROJECT) --region=$(GCP_REGION) --limit=50

update-xsds: ## Refresh ENTSO-E + Edig@s XSD packages
	./scripts/update_xsds.sh

vendor-ace: ## Re-vendor Ace editor assets
	./scripts/vendor_ace.sh

clean: ## Remove local container if running
	-podman rm -f $(CONTAINER_NAME) 2>/dev/null || true
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
