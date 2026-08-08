# XSD registry

All schemas used for auto-validation (match by XML root `targetNamespace`).

**Old packages are never deleted by update scripts** — new downloads get versioned folder names.

## Bundled (committed in git)

| Path | Family | Notes |
|------|--------|--------|
| `CIM_2021-04-11/` | ENTSO-E IEC 62325 / ESMP | Legacy snapshot |
| `EAP-Schemas/` | Edig@s ~5.1 | Legacy snapshot (codelists ~2018) |
| `CGMES_2_4_15/` | CGMES FullModel / RDF helpers | Static |
| `OPDM_XSD/` | OPDM QAR / query | Static |
| `urn-entsoe-eu-wgedi-rgce-reporting_schemas-2-0/` | RGCE reporting | Static |

## After running update scripts

| Path pattern | Family | Script |
|--------------|--------|--------|
| `ENTSOE_CIM_xsd_package_vYYYY/` | ENTSO-E CIM/ESMP latest | `scripts/update_entsoe_xsds.sh` |
| `EDIGAS_5.1_YYYY-MM-DD/` | Edig@s 5.1 full package | `scripts/update_edigas_xsds.sh` |
| `EDIGAS_6.1_YYYY-MM-DD/` | Edig@s 6.1 full package | `scripts/update_edigas_xsds.sh` |

See root [README.md](../README.md#updating-the-xsd-registry) for commands.
