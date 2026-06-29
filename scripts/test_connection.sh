#!/usr/bin/env bash
# Test CockroachDB connection on Windows (WSL or Git Bash).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
CONFIG_FILE="$ROOT/config/db.env"

log()  { printf '[%s] %s\n'  "$(date +%Y-%m-%d\ %H:%M:%S)" "$*"; }
ok()   { printf '[%s] OK  %s\n'  "$(date +%Y-%m-%d\ %H:%M:%S)" "$*"; }
fail() { printf '[%s] FAIL %s\n' "$(date +%Y-%m-%d\ %H:%M:%S)" "$*" >&2; }

# ── Step 1: Detect Windows environment ───────────────────────────────────────
log "Step 1: Detecting Windows environment..."
if grep -qi microsoft /proc/version 2>/dev/null; then
  ok "Running inside WSL (Windows Subsystem for Linux)"
  ENV="WSL"
elif [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == CYGWIN* ]]; then
  ok "Running inside Git Bash / Cygwin"
  ENV="GITBASH"
else
  fail "This script is intended for Windows (WSL or Git Bash)."
  fail "If you are on macOS/Linux, run export_employee.sh --validate instead."
  exit 1
fi

# ── Step 2: Check config file ─────────────────────────────────────────────────
log "Step 2: Checking config file..."
if [[ -f "$CONFIG_FILE" ]]; then
  ok "Config file found: $CONFIG_FILE"
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
  # Strip Windows \r (carriage return) from all loaded variables.
  DB_HOST="${DB_HOST//$'\r'/}"
  DB_PORT="${DB_PORT//$'\r'/}"
  DB_NAME="${DB_NAME//$'\r'/}"
  DB_USER="${DB_USER//$'\r'/}"
  DB_PASSWORD="${DB_PASSWORD//$'\r'/}"
  JWT_AUTH_CONNECTION="${JWT_AUTH_CONNECTION//$'\r'/}"
else
  fail "Config file not found: $CONFIG_FILE"
  if [[ "$ENV" == "WSL" ]]; then
    fail "Run: cp config/db.env.example config/db.env"
    fail "Then edit it with: nano config/db.env"
  else
    fail "Run: cp config/db.env.example config/db.env"
    fail "Then open it in Notepad: notepad.exe config/db.env"
  fi
  exit 1
fi

# ── Step 3: Validate required variables ──────────────────────────────────────
log "Step 3: Validating config variables..."
PASS=true
for var in DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD; do
  if [[ -n "${!var:-}" ]]; then
    ok "$var is set"
  else
    fail "$var is NOT set in $CONFIG_FILE"
    PASS=false
  fi
done
[[ "$PASS" == true ]] || { fail "Fix the missing variables above, then re-run."; exit 1; }

AUTH_MODE="password"
[[ "${JWT_AUTH_CONNECTION:-false}" == "true" ]] && AUTH_MODE="JWT"
ok "Auth mode: $AUTH_MODE"

# ── Step 4: Check cockroach CLI ───────────────────────────────────────────────
log "Step 4: Checking cockroach CLI..."
if command -v cockroach >/dev/null 2>&1; then
  COCKROACH_VER="$(cockroach version 2>/dev/null | head -1 || true)"
  ok "cockroach found: $COCKROACH_VER"
else
  fail "cockroach CLI not found in PATH"
  if [[ "$ENV" == "WSL" ]]; then
    fail "Install inside WSL:"
    fail "  curl -k https://binaries.cockroachdb.com/cockroach-latest.linux-amd64.tgz | tar -xz"
    fail "  sudo cp cockroach-*/cockroach /usr/local/bin/"
    fail "Or download manually from https://www.cockroachlabs.com/docs/releases/"
    fail "and copy to WSL: cp /mnt/c/Users/YourName/Downloads/cockroach-*.tgz ."
  else
    fail "Git Bash: download the Windows binary from https://www.cockroachlabs.com/docs/releases/"
    fail "then add the folder to your Windows PATH."
  fi
  exit 1
fi

# ── Step 5: TCP reachability check ────────────────────────────────────────────
log "Step 5: Checking TCP reachability to $DB_HOST:$DB_PORT..."
if command -v nc >/dev/null 2>&1; then
  if nc -z -w 5 "$DB_HOST" "$DB_PORT" 2>/dev/null; then
    ok "TCP connection to $DB_HOST:$DB_PORT succeeded"
  else
    fail "Cannot reach $DB_HOST:$DB_PORT"
    fail "Things to check:"
    fail "  - Are you connected to the VPN / corporate network?"
    fail "  - Is the host name correct in config/db.env?"
    fail "  - Is DB_PORT correct? (password=26257, JWT=443)"
    fail "  - WSL: run 'ping $DB_HOST' to check DNS resolution"
    exit 1
  fi
else
  log "  nc not available — skipping TCP check"
fi

# ── Step 6: Live DB query ─────────────────────────────────────────────────────
log "Step 6: Running live query (SELECT 1)..."

# JWT tokens contain +, /, = which must be percent-encoded in a URL.
url_encode() {
  local raw
  raw="${1:-}"          # safe default: empty string if $1 is unset
  local length
  length="${#raw}"
  local encoded
  encoded=""
  local i
  i=0
  local char
  char=""
  printf '[%s]   [url_encode] input length=%s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$length" >&2
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

log "Step 6a: Encoding password for URL..."
printf '[%s]   DB_PASSWORD is set: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$( [[ -n "${DB_PASSWORD:-}" ]] && echo YES || echo NO )" >&2
printf '[%s]   DB_PASSWORD length: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${#DB_PASSWORD}" >&2
ENCODED_PASSWORD="$(url_encode "${DB_PASSWORD:-}")"
printf '[%s]   Encoded length: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "${#ENCODED_PASSWORD}" >&2

if [[ "$AUTH_MODE" == "JWT" ]]; then
  DB_URL="postgresql://${DB_USER}:${ENCODED_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require&options=--crdb%3Ajwt_authenabled%3Dtrue"
else
  DB_URL="postgresql://${DB_USER}:${ENCODED_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require"
fi

log "DB_URL: $DB_URL"

if cockroach sql --url "$DB_URL" -e "SELECT 1" >/dev/null 2>/tmp/crdb_test_err; then
  ok "Live query succeeded — DB connection is working!"
else
  fail "Live query failed. Error:"
  cat /tmp/crdb_test_err >&2
  echo ""
  fail "Common causes on Windows:"
  fail "  - SSL cert error  -> try adding ?sslmode=require or ?sslmode=disable to test"
  fail "  - Wrong password  -> check DB_PASSWORD in config/db.env"
  fail "  - Expired JWT     -> generate a new token and update DB_PASSWORD"
  fail "  - Wrong DB name   -> check DB_NAME matches your actual database"
  fail "  - VPN not active  -> connect to VPN and retry"
  exit 1
fi

log "────────────────────────────────────────"
log "All checks passed. DB connection is OK."
log "────────────────────────────────────────"
