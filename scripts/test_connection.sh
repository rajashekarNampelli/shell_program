#!/usr/bin/env bash
# Test CockroachDB connection (Windows WSL or Git Bash).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
CONFIG_FILE="$ROOT/config/db.env"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

load_config() {
  [[ -f "$CONFIG_FILE" ]] || die "Config not found: $CONFIG_FILE (copy config/db.env.example to config/db.env)"
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  DB_HOST="${DB_HOST//$'\r'/}"
  DB_PORT="${DB_PORT//$'\r'/}"
  DB_NAME="${DB_NAME//$'\r'/}"
  DB_USER="${DB_USER//$'\r'/}"
  DB_PASSWORD="${DB_PASSWORD//$'\r'/}"
  AUTH_MODE="${AUTH_MODE//$'\r'/}"
  [[ -n "${DB_HOST:-}" ]]     || die "DB_HOST is not set"
  [[ -n "${DB_PORT:-}" ]]     || die "DB_PORT is not set"
  [[ -n "${DB_NAME:-}" ]]     || die "DB_NAME is not set"
  [[ -n "${DB_USER:-}" ]]     || die "DB_USER is not set"
  [[ -n "${DB_PASSWORD:-}" ]] || die "DB_PASSWORD is not set"
}

url_encode() {
  local raw="${1:-}" length="${#raw}" encoded="" i=0 char
  while [[ $i -lt $length ]]; do
    char="${raw:$i:1}"
    case "$char" in
      [a-zA-Z0-9.~_-]) encoded="${encoded}${char}" ;;
      *) printf -v encoded '%s%%%02X' "$encoded" "'${char}" ;;
    esac
    i=$(( i + 1 ))
  done
  printf '%s' "$encoded"
}

build_url() {
  local encoded_password
  encoded_password="$(url_encode "$DB_PASSWORD")"
  if [[ "${AUTH_MODE:-password}" == "JWT" ]]; then
    printf 'postgresql://%s:%s@%s:%s/%s?sslmode=require&options=--crdb:jwt_auth_enabled=true' \
      "$DB_USER" "$encoded_password" "$DB_HOST" "$DB_PORT" "$DB_NAME"
  else
    printf 'postgresql://%s:%s@%s:%s/%s?sslmode=require' \
      "$DB_USER" "$encoded_password" "$DB_HOST" "$DB_PORT" "$DB_NAME"
  fi
}

load_config
command -v cockroach >/dev/null 2>&1 || die "'cockroach' not found in PATH"

OUTPUT_FILE="$ROOT/data/test_connection_$(date +%Y%m%d_%H%M%S).txt"
mkdir -p "$ROOT/data"

if cockroach sql --url "$(build_url)" -e "SELECT 1" --format=csv >"$OUTPUT_FILE" 2>&1; then
  printf 'Connection OK. Output saved to: %s\n' "$OUTPUT_FILE"
else
  die "Connection failed. See: $OUTPUT_FILE"
fi
