# XML Validator

Live browser UI to validate **European energy market XML** against bundled XSDs:

- **ENTSO-E** IEC 62325 / ESMP (CIM market documents)
- **Edig@s** gas market messages (5.1 and 6.1 packages)
- CGMES FullModel / RDF helpers, OPDM QAR, RGCE reporting

Validation is **in-memory lxml** (no temp files / subprocess). The Ace editor and Dash UI assets are **vendored** for offline use.

Repo: [github.com/Haigutus/xml-validator](https://github.com/Haigutus/xml-validator)

## Quick start

```bash
python3.13 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python app.py
# → http://0.0.0.0:8030
```

### Docker

```bash
docker compose up --build
# → http://localhost:8030
```

## XSD registry layout

Schemas live under `XSD/`. On startup the app indexes every `*.xsd` by `targetNamespace` and auto-picks a schema for the pasted XML.

**Update scripts never remove old packages** — they only add new versioned folders so historical namespaces keep working.

| Tree | Role |
|------|------|
| `XSD/CIM_*`, `XSD/ENTSOE_*` | ENTSO-E market CIM / ESMP |
| `XSD/EAP-Schemas/`, `XSD/EDIGAS_*` | Edig@s |
| `XSD/CGMES_*`, `XSD/OPDM_*`, `XSD/urn-entsoe-*` | Other bundled packs |

Details: [XSD/README.md](XSD/README.md).

## Updating the XSD registry

Requires `curl` or `wget`, `unzip`, and for ENTSO-E `.7z` packages **`p7zip-full`** (`7z`).

### All auto-updatable packs (ENTSO-E + Edig@s 5.1 + 6.1)

```bash
./scripts/update_xsds.sh
```

### ENTSO-E CIM / ESMP only

```bash
./scripts/update_entsoe_xsds.sh

# or pin a package URL when ENTSO-E renames the file:
ENTSOE_XSD_URL=https://www.entsoe.eu/Documents/EDI/Library/CIM_xsd_package_v2026.7z \
  ./scripts/update_entsoe_xsds.sh
```

Creates e.g. `XSD/ENTSOE_CIM_xsd_package_v2026/` and leaves `XSD/CIM_2021-04-11/` intact.

Catalogue: [ENTSO-E EDI Library](https://www.entsoe.eu/publications/electronic-data-interchange-edi-library/).

### Edig@s 5.1 and 6.1

```bash
./scripts/update_edigas_xsds.sh          # both 5.1 and 6.1
./scripts/update_edigas_xsds.sh 5.1      # only 5.1
./scripts/update_edigas_xsds.sh 6.1      # only 6.1
```

The script scrapes [edigas.org downloads](https://edigas.org/edigas/downloads/) for the newest `Edigas_5.1_full_YYYY-MM-DD.zip` / `Edigas_6.1_full_…` links (with fallbacks). Override:

```bash
EDIGAS_5_1_URL=https://edigas.org/_files/downloads/….zip \
EDIGAS_6_1_URL=https://edigas.org/_files/downloads/….zip \
  ./scripts/update_edigas_xsds.sh
```

Creates e.g. `XSD/EDIGAS_5.1_2025-07-30/` and `XSD/EDIGAS_6.1_2026-07-31/` without touching `XSD/EAP-Schemas/`.

### After updating

1. Restart the app (or rebuild Docker) so the namespace index reloads.
2. **Commit** new `XSD/…` folders if you want them in git:

```bash
git add XSD/ENTSOE_* XSD/EDIGAS_*
git commit -m "Update XSD packages"
git push
```

Static packs (CGMES, OPDM, RGCE) are curated by hand — copy new files into `XSD/` and commit.

### Ace editor (UI offline assets)

```bash
./scripts/vendor_ace.sh 1.36.5
```

## CLI

```bash
python xsd.py examples/ACK_positive.xml
python xsd.py path/to/message.xml
```

## Examples

Official ENTSO-E Transparency samples under `examples/` (plus a demo with deliberate errors for first load).

## Layout

| Area | Role |
|------|------|
| Thin header | Title + GitHub link |
| Main Ace | Paste XML (live validate, gutter errors) |
| Log Ace | Timestamped status (UTC `Z`) |

## Offline runtime

- Ace + CSS under `assets/` (no CDN)
- Dash/React from the installed Python package (`serve_locally=True`)
- XSDs from `XSD/`

Network is only needed for `pip`/`docker build` and optional XSD update scripts.
