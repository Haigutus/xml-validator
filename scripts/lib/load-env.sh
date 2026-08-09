# Optional repo-root .env (KEY=value). Does not override existing env.
# shellcheck shell=bash
_f="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.env"
[[ -f "$_f" ]] || { unset _f; return 0 2>/dev/null || true; }
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line//$'\r'/}"
  [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
  [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
  key="${line%%=*}"
  [[ -n "${!key+x}" ]] && continue
  value="${line#*=}"
  [[ "$value" =~ ^\"(.*)\"$ || "$value" =~ ^\'(.*)\'$ ]] && value="${BASH_REMATCH[1]}"
  export "${key}=${value}"
done < "$_f"
unset _f
