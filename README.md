# XML Validator

Live browser UI to validate **European energy market XML** against a local XSD registry:

- **ENTSO-E ESMP** (IEC 62325 / CIM market documents) → `XSD/ENTSOE_ESMP/`
- **Edig@s** 5.1 and 6.1 → `XSD/ENTSOG_EDIGAS/5.1/`, `XSD/ENTSOG_EDIGAS/6.1/`
- CGMES FullModel helpers, OPDM QAR, RGCE reporting

Validation is **in-memory lxml**. Ace + app assets are **vendored** (offline UI). Deploy with **[uv](https://docs.astral.sh/uv/)** and **[Podman](https://podman.io/)** (Compose-compatible).

Repo: [github.com/Haigutus/xml-validator](https://github.com/Haigutus/xml-validator)

## Version

Header shows **`0.2.<n>`**, where `<n>` is the git commit count (`git rev-list --count HEAD`).  
Container builds without `.git` use `--build-arg GIT_COMMIT_COUNT=…` (written to `/app/VERSION`).

## Quick start (uv, host)

```bash
# install uv: https://docs.astral.sh/uv/getting-started/installation/
uv sync
uv run python app.py
# → http://0.0.0.0:8030
```

Schemas are read from `./XSD` (or `$XSD_DIR`). Dependencies are declared only in **`pyproject.toml`** / **`uv.lock`**.

## Podman (recommended)

The container image holds **only the app** (Python/uv, Ace UI). The **`XSD/` tree is mounted from the host**, so you can refresh schemas without rebuilding the image.

### Compose

```bash
# build + run (Podman 4+ has `podman compose`; or use podman-compose)
export GIT_COMMIT_COUNT=$(git rev-list --count HEAD)
podman compose up --build -d

# → http://localhost:8030
```

Equivalent with Docker Compose v2: `GIT_COMMIT_COUNT=$(git rev-list --count HEAD) docker compose up --build -d`.

### One-shot (no compose)

```bash
podman build -t xml-validator -f Containerfile \
  --build-arg GIT_COMMIT_COUNT="$(git rev-list --count HEAD)" .

podman run --rm -p 8030:8030 \
  -e XSD_DIR=/app/XSD \
  -v "$PWD/XSD:/app/XSD:ro" \
  xml-validator
```

### Update schemas without rebuilding the image

On the **host** (next to this repo):

```bash
./scripts/update_xsds.sh              # ENTSO-E + Edig@s 5.1/6.1
# or add/edit files under ./XSD/ manually

# restart so the process re-indexes XSD/
podman compose restart
# or: podman restart <container>
```

The volume mount means the container always sees the current host `XSD/` tree.

## XSD registry

| Folder | Content |
|--------|---------|
| `XSD/ENTSOE_ESMP/` | Current ENTSO-E ESMP / CIM package (replaced on update) |
| `XSD/ENTSOG_EDIGAS/5.1/` | Current Edig@s 5.1 package (replaced on update) |
| `XSD/ENTSOG_EDIGAS/6.1/` | Current Edig@s 6.1 package (replaced on update) |
| `XSD/CGMES_*`, `OPDM_*`, `urn-entsoe-*` | Static extras |

Env: `XSD_DIR` — path to the registry (default: `./XSD`; in the container: `/app/XSD`).

On process start every `*.xsd` under that directory is indexed by `targetNamespace`.

## Updating the XSD registry (host scripts)

Needs `curl`/`wget`, `unzip`, and for ENTSO-E `.7z` either **`p7zip-full`** (`7z`) or **`uv`** (scripts fall back to `uv run --with py7zr`).

Each script **deletes only its target folder and rewrites it**.

### All packs

```bash
./scripts/update_xsds.sh
```

### ENTSO-E ESMP only → `XSD/ENTSOE_ESMP/`

```bash
./scripts/update_entsoe_xsds.sh

ENTSOE_XSD_URL=https://www.entsoe.eu/Documents/EDI/Library/CIM_xsd_package_v2026.7z \
  ./scripts/update_entsoe_xsds.sh
```

Catalogue: [ENTSO-E EDI Library](https://www.entsoe.eu/publications/electronic-data-interchange-edi-library/).

### Edig@s only → `XSD/ENTSOG_EDIGAS/{5.1,6.1}/`

```bash
./scripts/update_edigas_xsds.sh          # both
./scripts/update_edigas_xsds.sh 5.1
./scripts/update_edigas_xsds.sh 6.1
```

Source: [edigas.org downloads](https://edigas.org/edigas/downloads/).

### Persist schemas in git (optional)

```bash
git add XSD/ENTSOE_ESMP XSD/ENTSOG_EDIGAS
git commit -m "Refresh ENTSO-E ESMP and Edig@s XSD packages"
git push
```

### Ace UI assets

```bash
./scripts/vendor_ace.sh 1.36.5
```

## CLI

```bash
uv run python xsd.py examples/ACK_positive.xml
XSD_DIR=/path/to/XSD uv run python xsd.py path/to/message.xml
```

## Image vs data

| In the container image | On the host (mounted) |
|------------------------|------------------------|
| App (`app.py`, `xsd.py`) | `XSD/` schema registry |
| `uv` venv + dependencies | (optional) update scripts |
| Vendored Ace / CSS (`assets/`) | |

So: **rebuild the image only when app code or dependencies change**; **schema updates = host scripts + container restart**.

## Offline runtime

- Ace / CSS under `assets/`
- Python deps from `uv sync` / image layers
- Schemas from mounted (or local) `XSD/`
