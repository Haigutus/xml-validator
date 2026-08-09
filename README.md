# XML Validator

Live browser UI to validate **European energy market XML** against a local XSD registry:

- **ENTSO-E ESMP** → `XSD/ENTSOE_ESMP/`
- **Edig@s** 5.1 / 6.1 → `XSD/ENTSOG_EDIGAS/5.1/`, `XSD/ENTSOG_EDIGAS/6.1/`
- CGMES, OPDM, RGCE reporting (static extras)

**In-memory lxml**, vendored Ace UI, **[uv](https://docs.astral.sh/uv/)** deps.  
Default deploy target: **Google Cloud Run** (scale-to-zero / free-tier friendly). Schemas are **baked into the image**; you can still **override** them with a host mount for local work.

Repo: [github.com/Haigutus/xml-validator](https://github.com/Haigutus/xml-validator)

## Version

Header shows **`0.2.<n>`** (`n` = `git rev-list --count HEAD`).  
Container builds: `--build-arg GIT_COMMIT_COUNT=…` → `/app/VERSION`.

## Quick start (uv on host)

```bash
uv sync
uv run python app.py
# → http://0.0.0.0:8030
```

Dependencies: **`pyproject.toml`** + **`uv.lock`** only.

## Local containers (Make / Podman)

```bash
cp .env.example .env    # optional local config (gitignored)
make help
make up                 # build + run baked XSD → :8030
make run-host-xsd       # mount ./XSD over baked schemas
make dev                # host: uv run python app.py
```

Scripts under `scripts/` still work (`./scripts/up.sh`, etc.). Prefer **Make** for day-to-day.

### Local config vs secrets (no cloud IDs in git)

Cloud project names, service account emails, and WIF provider IDs are **not** stored in this repository. You set them per environment.

| Place | In git? | Purpose |
|-------|---------|---------|
| `.env.example` | yes | Empty/placeholder keys only |
| `.env` | **no** | Your local `GCP_PROJECT`, region, service/AR names |
| GitHub **Variables** | repo settings only | Same values for CI deploy |
| GitHub **Secrets** | optional | Prefer Variables for non-key config; never commit SA JSON keys |
| Auth | not in repo | Local: `gcloud auth login` · CI: **WIF** only |

`.env` is ignored by git, Docker, and Podman (never baked into the image).

### Baked XSD vs host mount

| Mode | How | When |
|------|-----|------|
| **Baked (default)** | `COPY XSD` in image | Cloud Run, simple local run |
| **Host override** | `-v ./XSD:/app/XSD:ro` or `./scripts/run.sh --host-xsd` | Local schema experiments without rebuild |

Mounting `./XSD` **replaces** the image directory at `/app/XSD` (standard container bind-mount behaviour).

## Deploy your own (Google Cloud Run)

Image is built and deployed by GitHub Actions on push to **`main`** (WIF, no SA keys in the repo).

### 1) GCP once

Enable APIs: Cloud Run, Artifact Registry, IAM Credentials (for WIF).  
Create an Artifact Registry **docker** repo, a deploy service account, and a **Workload Identity Pool + GitHub OIDC provider** bound so only *your* GitHub repo can impersonate that SA (`roles/iam.workloadIdentityUser`, plus AR writer + Run admin + `iam.serviceAccountUser` on the runtime SA).

### 2) GitHub Actions Variables

Repo → **Settings → Secrets and variables → Actions → Variables**:

| Variable | Example shape (yours will differ) |
|----------|-----------------------------------|
| `GCP_PROJECT_ID` | your GCP project id |
| `GCP_REGION` | e.g. `europe-west1` |
| `SERVICE_NAME` | Cloud Run service name |
| `AR_REPO` | Artifact Registry repository id |
| `GCP_SERVICE_ACCOUNT` | `github-deploy@PROJECT_ID.iam.gserviceaccount.com` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/…/providers/…` |

```bash
# with gh authenticated:
gh variable set GCP_PROJECT_ID --body "YOUR_PROJECT"
gh variable set GCP_REGION --body "europe-west1"
gh variable set SERVICE_NAME --body "xml-validator"
gh variable set AR_REPO --body "xml-validator"
gh variable set GCP_SERVICE_ACCOUNT --body "github-deploy@YOUR_PROJECT.iam.gserviceaccount.com"
gh variable set GCP_WORKLOAD_IDENTITY_PROVIDER --body "projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github/providers/github"
```

Then protect `main` and push. CI fails fast if required variables are missing.

### 3) Optional local deploy

```bash
gcloud auth login
cp .env.example .env   # set GCP_PROJECT, SERVICE_NAME, AR_REPO, …
make deploy
```

### Cold-start practices (in deploy + app)

| Practice | How |
|----------|-----|
| Scale to zero | `--min-instances=0` |
| Startup CPU boost | `--cpu-boost` |
| Gen1 environment | Faster cold start than gen2 for this workload |
| Small instance | **512 MiB**, **1 vCPU**, **max 2** instances |
| Concurrency | **40** requests per instance |
| Fast probes | `/healthz` — no XSD index work |
| Lazy XSD index | Built on **first validate**, not import/health |
| Faster index scan | Root-only `iterparse` per schema file |
| gunicorn | 1 worker, 4 threads; listens ASAP |
| Request-based CPU | Default throttling (no always-on CPU bill) |

Custom domain: Cloud Run domain mapping + DNS at your registrar (optional `DOMAIN=…` for local `make deploy` only).

**Schema updates:** commit refreshed `XSD/` → push to `main` (CI rebuild) or `make deploy` locally.

## XSD registry

| Folder | Content |
|--------|---------|
| `XSD/ENTSOE_ESMP/` | ENTSO-E ESMP / CIM (replaced on update) |
| `XSD/ENTSOG_EDIGAS/5.1/` | Edig@s 5.1 (replaced on update) |
| `XSD/ENTSOG_EDIGAS/6.1/` | Edig@s 6.1 (replaced on update) |
| `XSD/CGMES_*`, `OPDM_*`, … | Static extras |

Env: `XSD_DIR` (default `./XSD`, container `/app/XSD`).

### Refresh packages (host)

```bash
./scripts/update_xsds.sh              # ENTSO-E + Edig@s 5.1/6.1
./scripts/update_entsoe_xsds.sh
./scripts/update_edigas_xsds.sh 5.1
```

Needs `curl`/`wget`, `unzip`, and `7z` **or** `uv` (ENTSO-E `.7z` fallback).

Then:

```bash
# local with bake
./scripts/up.sh

# or Cloud Run
git add XSD && git commit -m "Refresh XSDs" && git push
./scripts/deploy-cloudrun.sh
```

### Ace assets

```bash
./scripts/vendor_ace.sh 1.36.5
```

## CLI

```bash
uv run python xsd.py examples/ACK_positive.xml
XSD_DIR=/path/to/XSD uv run python xsd.py message.xml
```

## Image contents

| In image | Optional at runtime |
|----------|---------------------|
| App, uv venv, Ace UI | — |
| **Baked `XSD/`** | Host mount `./XSD` → `/app/XSD` overrides bake |

## Offline

- Ace/CSS in `assets/`
- Deps from `uv sync` / image layers  
- Schemas from image or mount

## Security notes (public deploy)

Reasonable defaults shipped for Cloud Run:

| Control | Detail |
|---------|--------|
| Safe XML parse | `resolve_entities=False`, `no_network=True` (XXE / external DTD) |
| Size limit | `MAX_XML_BYTES` (default 10 MiB) on XML body |
| HTTP body cap | Flask `MAX_CONTENT_LENGTH` slightly above that |
| Security headers | CSP (self), `X-Frame-Options: DENY`, nosniff, HSTS on HTTPS |
| Non-root image | runs as `app` user |
| Production server | **gunicorn** (not Flask dev server) |
| ProxyFix | trusts one hop of `X-Forwarded-*` (Cloud Run) |

Still public / unauthenticated by design (anyone can paste XML). Optional later: Cloud Armor rate limits, IAP, or auth if abuse appears.
