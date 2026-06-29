#!/usr/bin/env bash
# Export employee table from CockroachDB to CSV.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
CONFIG_FILE="$ROOT/config/db.env"

TABLE="employee"
OUTPUT_FILE=""
VALIDATE_ONLY=false

RUN_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_DIR="$ROOT/logs"
LOG_FILE="$LOG_DIR/export_${RUN_TIMESTAMP}.log"
mkdir -p "$LOG_DIR"

# Tee all output (stdout + stderr) to the log file.
exec > >(tee -a "$LOG_FILE") 2>&1

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Export a CockroachDB table to a CSV file.

Options:
  --table NAME   Table to export (default: employee)
  --out PATH     Output CSV path (default: output/<table>_export_<timestamp>.csv)
  --validate     Check config without querying the DB
  -h, --help     Show this help

Examples:
  $(basename "$0")
  $(basename "$0") --table employee --out output/baseline.csv
  $(basename "$0") --validate
EOF
}

log() {
  printf '[%s] %s\n' "$(date +%Y-%m-%d\ %H:%M:%S)" "$*"
}

die() {
  log "ERROR: $*"
  exit 1
}

load_config() {
  [[ -f "$CONFIG_FILE" ]] || die "Config not found: $CONFIG_FILE  (copy config/db.env.example to config/db.env)"
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  # Strip Windows \r (carriage return) from all loaded variables.
  DB_HOST="${DB_HOST//$'\r'/}"
  DB_PORT="${DB_PORT//$'\r'/}"
  DB_NAME="${DB_NAME//$'\r'/}"
  DB_USER="${DB_USER//$'\r'/}"
  DB_PASSWORD="${DB_PASSWORD//$'\r'/}"
  JWT_AUTH_CONNECTION="${JWT_AUTH_CONNECTION//$'\r'/}"
  [[ -n "${DB_HOST:-}" ]]     || die "DB_HOST is not set in $CONFIG_FILE"
  [[ -n "${DB_PORT:-}" ]]     || die "DB_PORT is not set in $CONFIG_FILE"
  [[ -n "${DB_NAME:-}" ]]     || die "DB_NAME is not set in $CONFIG_FILE"
  [[ -n "${DB_USER:-}" ]]     || die "DB_USER is not set in $CONFIG_FILE"
  [[ -n "${DB_PASSWORD:-}" ]] || die "DB_PASSWORD is not set in $CONFIG_FILE"
}

# JWT tokens contain characters like +, /, = that must be percent-encoded in a URL.
url_encode() {
  local raw="$1"
  local length="${#raw}"
  local encoded=""
  local i=0
  local char
  while [[ $i -lt $length ]]; do
    char="${raw:i:1}"
    case "$char" in
      [a-zA-Z0-9.~_-]) encoded+="$char" ;;
      *) printf -v encoded '%s%%%02X' "$encoded" "'$char" ;;
    esac
    (( i++ )) || true
  done
  printf '%s' "$encoded"
}

build_url() {
  local encoded_password
  encoded_password="$(url_encode "$DB_PASSWORD")"

  if [[ "${JWT_AUTH_CONNECTION:-false}" == "true" ]]; then
    AUTH_MODE="JWT"
    printf 'postgresql://%s:%s@%s:%s/%s?sslmode=require&options=--crdb%%3Ajwt_authenabled%%3Dtrue' \
      "$DB_USER" "$encoded_password" "$DB_HOST" "$DB_PORT" "$DB_NAME"
  else
    AUTH_MODE="password"
    printf 'postgresql://%s:%s@%s:%s/%s?sslmode=require' \
      "$DB_USER" "$encoded_password" "$DB_HOST" "$DB_PORT" "$DB_NAME"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --table)  TABLE="$2";       shift 2 ;;
      --out)    OUTPUT_FILE="$2"; shift 2 ;;
      --validate) VALIDATE_ONLY=true; shift ;;
      -h|--help) usage; exit 0 ;;
      *) die "Unknown option: $1 (use --help)" ;;
    esac
  done
}

main() {
  parse_args "$@"
  load_config

  log "Log file: $LOG_FILE"

  local db_url
  db_url="$(build_url)"

  if [[ "$VALIDATE_ONLY" == true ]]; then
    log "Config OK — host=$DB_HOST port=$DB_PORT db=$DB_NAME user=$DB_USER auth=$AUTH_MODE"
    exit 0
  fi

  command -v cockroach >/dev/null 2>&1 || die "'cockroach' not found. Install: brew install cockroachdb/tap/cockroach"

  if [[ -z "$OUTPUT_FILE" ]]; then
    OUTPUT_FILE="$ROOT/output/${TABLE}_export_${RUN_TIMESTAMP}.csv"
  fi

  mkdir -p "$(dirname "$OUTPUT_FILE")"

  log "Exporting table '$TABLE' (auth=$AUTH_MODE) -> $OUTPUT_FILE"

  cockroach sql \
    --url "$db_url" \
    --format=csv \
    -e "SELECT * FROM ${TABLE}" > "$OUTPUT_FILE"

  [[ -s "$OUTPUT_FILE" ]] || die "Export produced an empty file: $OUTPUT_FILE"

  local rows
  rows=$(( $(wc -l < "$OUTPUT_FILE") - 1 ))
  log "Export complete: $OUTPUT_FILE ($rows data rows)"
}

main "$@"
