# Local helpers. Config: .env (from .env.example). CI: GitHub Variables + WIF.

.PHONY: help env sync dev build run run-host-xsd up up-host deploy logs clean update-xsds vendor-ace

ifneq (,$(wildcard .env))
  include .env
  export
endif

help:
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "  %-14s %s\n", $$1, $$2}'

env: ## create .env from example
	@test -f .env || cp .env.example .env

sync: ## uv sync
	uv sync

dev: ## run on host
	uv run python app.py

build: ## build local image
	./scripts/build.sh

run: ## run container
	./scripts/run.sh

run-host-xsd: ## run with ./XSD mount
	./scripts/run.sh --host-xsd

up: build run ## build + run

up-host: build run-host-xsd ## build + run with host XSD

deploy: ## local Cloud Run deploy (prefer push to main)
	./scripts/deploy-cloudrun.sh

logs: ## Cloud Run logs
	gcloud run services logs read $(SERVICE_NAME) --project=$(GCP_PROJECT) --region=$(GCP_REGION) --limit=50

update-xsds: ## refresh XSD packages
	./scripts/update_xsds.sh

vendor-ace: ## re-vendor Ace
	./scripts/vendor_ace.sh

clean: ## remove local container
	-podman rm -f $(CONTAINER_NAME) 2>/dev/null || true
	-docker rm -f $(CONTAINER_NAME) 2>/dev/null || true
