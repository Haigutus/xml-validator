# shellcheck shell=bash
# Optional repo-root .env loader for helper scripts.
#
# Usage (near top of a script, after ROOT=…):
#   # shellcheck source=scripts/lib/load-env.sh
#   source "$ROOT/scripts/lib/load-env.sh"
#
# Rules:
#   - .env is gitignored; commit .env.example only
#   - Only KEY=value lines (no shell commands)
#   - Does not override variables already set in the environment
#   - Never put long-lived credentials here; use `gcloud auth login` / WIF

_load_env_file="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/.env"

if [[ -f "${_load_env_file}" ]]; then
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line//$'\r'/}"
    # skip blanks and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    # only plain assignments
    [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
    key="${line%%=*}"
    # already set in environment → keep it
    if [[ -n "${!key+x}" ]]; then
      continue
    fi
    value="${line#*=}"
    # strip optional surrounding quotes
    if [[ "$value" =~ ^\"(.*)\"$ ]]; then
      value="${BASH_REMATCH[1]}"
    elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi
    export "${key}=${value}"
  done < "${_load_env_file}"
fi

unset _load_env_file
