"""Minimal in-memory XML / XSD validation (lxml, no temp files)."""

import os
from datetime import datetime, timezone
from pathlib import Path
from lxml import etree

# Default: ./XSD next to this file. Override with env XSD_DIR (e.g. container mount).
XSD_DIR = Path(os.environ.get("XSD_DIR", Path(__file__).resolve().parent / "XSD")).resolve()

# Reject huge payloads (DoS). Override with MAX_XML_BYTES (default 10 MiB).
MAX_XML_BYTES = int(os.environ.get("MAX_XML_BYTES", str(10 * 1024 * 1024)))


def _safe_parser(**kwargs):
    """Parser hardened against XXE / external network / entity bombs."""
    return etree.XMLParser(
        resolve_entities=False,
        no_network=True,
        huge_tree=False,
        remove_comments=False,
        **kwargs,
    )


def _index_xsds(root=None):
    """namespace -> sorted list of xsd paths.

    Uses iterparse(start) so we only read the root element of each file
    (faster cold-start indexing than full parse of every schema).
    """
    root = Path(root) if root else XSD_DIR
    index = {}
    if not root.is_dir():
        return index
    for path in sorted(root.rglob("*.xsd")):
        try:
            ns = ""
            # Root-only scan (faster than full parse of every schema)
            for _event, elem in etree.iterparse(
                str(path),
                events=("start",),
                resolve_entities=False,
                no_network=True,
                huge_tree=False,
            ):
                ns = elem.get("targetNamespace", "") or ""
                elem.clear()
                break
        except (etree.XMLSyntaxError, OSError, TypeError):
            # Fallback if iterparse kwargs unsupported
            try:
                ns = etree.parse(str(path), parser=_safe_parser()).getroot().get(
                    "targetNamespace", ""
                ) or ""
            except (etree.XMLSyntaxError, OSError):
                continue
        if ns:
            index.setdefault(ns, []).append(path)
    return index


# Lazy index: built on first validate(), not at import (faster Cloud Run cold start)
_XSD_INDEX = None


def get_xsd_index():
    """Return namespace index, building it once on first use."""
    global _XSD_INDEX
    if _XSD_INDEX is None:
        _XSD_INDEX = _index_xsds()
    return _XSD_INDEX


def reindex_xsds(root=None):
    """Rebuild namespace index (call after host XSD mount is updated)."""
    global _XSD_INDEX, XSD_DIR
    if root is not None:
        XSD_DIR = Path(root).resolve()
    _XSD_INDEX = _index_xsds(XSD_DIR)
    return _XSD_INDEX


class _LazyIndex:
    """Dict-like proxy so `XSD_INDEX.get(...)` stays valid without import-time work."""

    def get(self, *a, **k):
        return get_xsd_index().get(*a, **k)

    def values(self):
        return get_xsd_index().values()

    def keys(self):
        return get_xsd_index().keys()

    def items(self):
        return get_xsd_index().items()

    def __len__(self):
        return len(get_xsd_index())

    def __contains__(self, key):
        return key in get_xsd_index()


XSD_INDEX = _LazyIndex()


def _pick_xsd(paths):
    """Prefer current registry trees over legacy; else first sorted path."""
    for prefer in ("ENTSOE_ESMP", "ENTSOG_EDIGAS"):
        hit = [p for p in paths if prefer in p.parts]
        if hit:
            return sorted(hit)[0]
    # Legacy names still in some checkouts
    for prefer in ("CIM_", "EAP-Schemas"):
        hit = [p for p in paths if any(prefer in part for part in p.parts)]
        if hit:
            return sorted(hit)[0]
    return sorted(paths)[0]


def _root_namespace(doc):
    tag = doc.tag
    if isinstance(tag, str) and tag.startswith("{"):
        return tag[1:].split("}", 1)[0]
    return doc.nsmap.get(None) or ""


def _check_size(data: bytes | str):
    n = len(data.encode("utf-8") if isinstance(data, str) else data)
    if n > MAX_XML_BYTES:
        raise ValueError(
            f"XML too large ({n} bytes; limit {MAX_XML_BYTES}). "
            f"Set MAX_XML_BYTES to raise the limit."
        )


def _parse_xml(xml):
    parser = _safe_parser()
    if isinstance(xml, (bytes, bytearray)):
        _check_size(xml)
        return etree.fromstring(xml, parser=parser)
    if isinstance(xml, str):
        text = xml.strip()
        if not text or text.startswith("Copy your"):
            raise ValueError("empty XML")
        raw = text.encode("utf-8")
        _check_size(raw)
        return etree.fromstring(raw, parser=parser)
    raise TypeError("xml must be str or bytes")


def _load_schema(xsd):
    """xsd: path | str | bytes. Paths resolve xs:include; strings are self-contained."""
    parser = _safe_parser()
    if isinstance(xsd, Path) or (isinstance(xsd, str) and Path(xsd).is_file()):
        return etree.XMLSchema(etree.parse(str(xsd), parser=parser))
    if isinstance(xsd, (bytes, bytearray)):
        return etree.XMLSchema(etree.fromstring(xsd, parser=parser))
    if isinstance(xsd, str):
        return etree.XMLSchema(etree.fromstring(xsd.encode("utf-8"), parser=parser))
    raise TypeError("xsd must be path, str, or bytes")


def _error_entries(error_log):
    """Collect every entry from an lxml error log (no dedupe / no cap)."""
    errors = []
    for e in error_log:
        errors.append({
            "line": e.line or 0,
            "column": e.column or 0,
            "message": e.message or str(e),
            "domain_name": getattr(e, "domain_name", "") or "",
            "type_name": getattr(e, "type_name", "") or "",
            "path": getattr(e, "path", "") or "",
        })
    return errors


def _ts():
    """UTC ISO 8601 with T separator and Z, e.g. 2026-08-08T12:09:34.090Z (server clock, UTC)."""
    return (
        datetime.now(timezone.utc)
        .isoformat(timespec="milliseconds")
        .replace("+00:00", "Z")
    )

def _log_lines(ts, *parts):
    """One timestamped line per part."""
    return [f"[{ts}] {p}" for p in parts]


def validate(xml, xsd=None):
    """
    Validate XML in memory.

    Returns dict:
      ok, errors[{line, column, message, ...}], xsd_used, status_lines[str]
    """
    ts = _ts()
    status = []
    errors = []

    # XML
    try:
        doc = _parse_xml(xml)
        status.extend(_log_lines(ts, "XML      OK - loaded"))
    except Exception as exc:
        msg = str(exc)
        line = getattr(exc, "lineno", None) or 0
        if not line:
            pos = getattr(exc, "position", None)
            if isinstance(pos, tuple) and pos:
                line = pos[0] or 0
        errors.append({"line": line, "column": 0, "message": msg})
        status.extend(_log_lines(
            ts,
            "XML      ERROR - Loading failed",
            f"L{line or '?':<6} {msg}",
        ))
        return {
            "ok": False,
            "errors": errors,
            "xsd_used": "",
            "status_lines": status,
        }

    # XSD resolve
    xsd_used = ""
    try:
        if xsd:
            schema = _load_schema(xsd)
            xsd_used = "provided XSD" if not isinstance(xsd, Path) else Path(xsd).name
        else:
            ns = _root_namespace(doc)
            paths = get_xsd_index().get(ns, [])
            if not paths:
                status.extend(_log_lines(
                    ts,
                    "XSD      ERROR - no schema for namespace",
                    f"         {ns or '(none)'}",
                ))
                return {
                    "ok": False,
                    "errors": errors,
                    "xsd_used": "",
                    "status_lines": status,
                }
            path = _pick_xsd(paths)
            schema = _load_schema(path)
            xsd_used = path.name
        status.extend(_log_lines(ts, f"XSD      {xsd_used}"))
    except Exception as exc:
        status.extend(_log_lines(ts, "XSD      ERROR - Loading failed", f"         {exc}"))
        return {
            "ok": False,
            "errors": errors,
            "xsd_used": xsd_used,
            "status_lines": status,
        }

    # Validate in memory — use a fresh error log via assertValid-style collect
    # schema.validate() fills schema.error_log with all libxml2 messages
    ok = bool(schema.validate(doc))
    errors = _error_entries(schema.error_log)

    # Also pull from doc if any (usually empty for schema errs)
    n = len(errors)
    status.extend(_log_lines(
        ts,
        f"Result   {n} error(s)" if n else "Result   valid",
    ))
    for e in errors:
        line = e["line"] or "?"
        status.extend(_log_lines(ts, f"L{line:<6} {e['message']}"))

    return {
        "ok": ok and not errors,
        "errors": errors,
        "xsd_used": xsd_used,
        "status_lines": status,
    }


if __name__ == "__main__":
    import sys

    xml_path = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if not xml_path or not xml_path.is_file():
        idx = get_xsd_index()
        print(f"Indexed {sum(len(v) for v in idx.values())} XSDs, {len(idx)} namespaces")
        print("Usage: python xsd.py <file.xml>")
        sys.exit(0)

    result = validate(xml_path.read_text(encoding="utf-8", errors="replace"))
    print("\n".join(result["status_lines"]))
    sys.exit(0 if result["ok"] else 1)
