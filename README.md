# XML Validator

Live browser UI to validate **European energy market XML** against bundled XSDs:

- **ENTSO-E ESMP** (IEC 62325 / CIM market documents) → `XSD/ENTSOE_ESMP/`
- **Edig@s** 5.1 and 6.1 → `XSD/ENTSOG_EDIGAS/5.1/`, `XSD/ENTSOG_EDIGAS/6.1/`
- CGMES FullModel helpers, OPDM QAR, RGCE reporting

Validation is **in-memory lxml**. Ace + app assets are **vendored** (offline UI). Deployment uses **[uv](https://docs.astral.sh/uv/)**.

Repo: [github.com/Haigutus/xml-validator](https://github.com/Haigutus/xml-validator)

## Quick start (uv)

```bash
# install uv if needed: https://docs.astral.sh/uv/getting-started/installation/
uv sync
uv run python app.py
# → http://0.0.0.0:8030
```

Or one-shot:

```bash
uv run --with dash --with lxml python app.py
```

### Docker (uv image)

```bash
docker compose up --build
# → http://localhost:8030
```

## XSD registry

| Folder | Content |
|--------|---------|
| `XSD/ENTSOE_ESMP/` | Current ENTSO-E ESMP / CIM package (replaced on update) |
| `XSD/ENTSOG_EDIGAS/5.1/` | Current Edig@s 5.1 package (replaced on update) |
| `XSD/ENTSOG_EDIGAS/6.1/` | Current Edig@s 6.1 package (replaced on update) |
| `XSD/CGMES_*`, `OPDM_*`, `urn-entsoe-*` | Static extras |

On startup every `*.xsd` under `XSD/` is indexed by `targetNamespace`.

## Updating the XSD registry

Needs `curl`/`wget`, `unzip`, and for ENTSO-E `.7z` packages **`p7zip-full`** (`7z`).

Each script **deletes the target folder and rewrites it** with the newest download (no date-stamped copies to clean up).

### All packs

```bash
./scripts/update_xsds.sh
```

### ENTSO-E ESMP only → `XSD/ENTSOE_ESMP/`

```bash
./scripts/update_entsoe_xsds.sh

# pin URL when ENTSO-E renames the package:
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

Scrapes [edigas.org downloads](https://edigas.org/edigas/downloads/) for the latest full zip names (with fallbacks). Override:

```bash
EDIGAS_5_1_URL=https://edigas.org/_files/downloads/….zip \
EDIGAS_6_1_URL=https://edigas.org/_files/downloads/….zip \
  ./scripts/update_edigas_xsds.sh
```

### After updating

1. Restart the app (or rebuild Docker).
2. Commit the refreshed trees:

```bash
git add XSD/ENTSOE_ESMP XSD/ENTSOG_EDIGAS
git status   # review
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
uv run python xsd.py path/to/message.xml
```

## Offline runtime

- Ace / CSS / favicon under `assets/`
- Python deps from `uv sync` (`.venv`)
- Schemas from `XSD/`

Network is only required for `uv sync` / `docker build` and optional XSD update scripts.
