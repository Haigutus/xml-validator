# XSD registry

Schemas used for auto-validation (match by XML root namespace).

## Maintained packs (replaced in place by update scripts)

| Path | Family | Update script |
|------|--------|---------------|
| `ENTSOE_ESMP/` | ENTSO-E IEC 62325 / ESMP market XSDs | `scripts/update_entsoe_xsds.sh` |
| `ENTSOG_EDIGAS/5.1/` | Edig@s 5.1 full package | `scripts/update_edigas_xsds.sh 5.1` |
| `ENTSOG_EDIGAS/6.1/` | Edig@s 6.1 full package | `scripts/update_edigas_xsds.sh 6.1` |

Each pack may contain a `.package_source` file with download URL and fetch time.

**Updates wipe and recreate only the target folder** — no date-stamped copies.

## Other bundled packs (manual / static)

| Path | Notes |
|------|--------|
| `CGMES_2_4_15/` | CGMES FullModel / RDF helpers |
| `OPDM_XSD/` | OPDM QAR / query |
| `urn-entsoe-eu-wgedi-rgce-reporting_schemas-2-0/` | RGCE reporting |

See root [README.md](../README.md#updating-the-xsd-registry).
