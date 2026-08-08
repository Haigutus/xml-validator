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

## Local containers (Podman)

Helper scripts (prefer these over raw compose if snap `docker-compose` fights Podman):

```bash
./scripts/build.sh              # build image (XSD baked in)
./scripts/run.sh                # run with baked XSD  → :8030
./scripts/run.sh --host-xsd     # mount ./XSD over baked schemas
./scripts/up.sh                 # build + run
./scripts/up.sh --host-xsd -d   # build + run detached with host XSD
```

Or compose:

```bash
export GIT_COMMIT_COUNT=$(git rev-list --count HEAD)
export PODMAN_COMPOSE_PROVIDER=podman-compose   # recommended
systemctl --user start podman.socket            # if needed

podman compose -f compose.yml up --build -d
# → http://localhost:8030
```

### Baked XSD vs host mount

| Mode | How | When |
|------|-----|------|
| **Baked (default)** | `COPY XSD` in image | Cloud Run, simple local run |
| **Host override** | `-v ./XSD:/app/XSD:ro` or `./scripts/run.sh --host-xsd` | Local schema experiments without rebuild |

Mounting `./XSD` **replaces** the image directory at `/app/XSD` (standard container bind-mount behaviour).

## Google Cloud Run (scale-to-zero / free-tier)

Designed for **min-instances = 0** (pay mostly when handling requests). Cold starts are mitigated without a warm instance.

```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud services enable run.googleapis.com artifactregistry.googleapis.com cloudbuild.googleapis.com

./scripts/deploy-cloudrun.sh
# REGION=europe-west1 SERVICE=xml-validator ./scripts/deploy-cloudrun.sh
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

Map **xsd.cimtools.eu** in Cloud Console → Cloud Run → Domain mappings (managed TLS).

**Schema updates:** commit refreshed `XSD/` → push → `./scripts/deploy-cloudrun.sh` (image rebuild).

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
