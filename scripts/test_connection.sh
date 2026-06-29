#!/usr/bin/env bash
# Test CockroachDB connection and print diagnostic info.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
CONFIG_FILE="$ROOT/config/db.env"

log()  { printf '[%s] %s\n' "$(date +%Y-%m-%d\ %H:%M:%S)" "$*"; }
ok()   { printf '[%s] ✓ %s\n' "$(date +%Y-%m-%d\ %H:%M:%S)" "$*"; }
fail() { printf '[%s] ✗ %s\n' "$(date +%Y-%m-%d\ %H:%M:%S)" "$*" >&2; }

PASS=true

# ── Step 1: Check config file ────────────────────────────────────────────────
log "Step 1: Checking config file..."
if [[ -f "$CONFIG_FILE" ]]; then
  ok "Config file found: $CONFIG_FILE"
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
else
  fail "Config file not found: $CONFIG_FILE"
  fail "Run: cp config/db.env.example config/db.env  then fill in your details"
  exit 1
fi

# ── Step 2: Validate required variables ──────────────────────────────────────
log "Step 2: Validating config variables..."
for var in DB_HOST DB_PORT DB_NAME DB_USER DB_PASSWORD; do
  if [[ -n "${!var:-}" ]]; then
    ok "$var is set"
  else
    fail "$var is NOT set in $CONFIG_FILE"
    PASS=false
  fi
done

[[ "$PASS" == true ]] || { fail "Fix missing variables above, then re-run."; exit 1; }

AUTH_MODE="password"
[[ "${JWT_AUTH_CONNECTION:-false}" == "true" ]] && AUTH_MODE="JWT"
ok "Auth mode: $AUTH_MODE"

# ── Step 3: Check cockroach CLI ───────────────────────────────────────────────
log "Step 3: Checking cockroach CLI..."
if command -v cockroach >/dev/null 2>&1; then
  COCKROACH_VER="$(cockroach version --client-only 2>/dev/null | head -1 || cockroach version 2>/dev/null | head -1)"
  ok "cockroach found: $COCKROACH_VER"
else
  fail "cockroach CLI not found in PATH"
  fail "macOS:  brew install cockroachdb/tap/cockroach"
  fail "Linux:  curl https://binaries.cockroachdb.com/cockroach-latest.linux-amd64.tgz | tar -xz && sudo cp cockroach-*/cockroach /usr/local/bin/"
  exit 1
fi

# ── Step 4: TCP reachability check ───────────────────────────────────────────
log "Step 4: Checking TCP reachability to $DB_HOST:$DB_PORT..."
if command -v nc >/dev/null 2>&1; then
  if nc -z -w 5 "$DB_HOST" "$DB_PORT" 2>/dev/null; then
    ok "TCP connection to $DB_HOST:$DB_PORT succeeded"
  else
    fail "Cannot reach $DB_HOST:$DB_PORT — check host, port, firewall, or VPN"
    PASS=false
  fi
else
  log "  (nc not available, skipping TCP check)"
fi

[[ "$PASS" == true ]] || exit 1

# ── Step 5: Live DB query ─────────────────────────────────────────────────────
log "Step 5: Running live query (SELECT 1)..."

if [[ "$AUTH_MODE" == "JWT" ]]; then
  DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require&options=--crdb%3Ajwt_authenabled%3Dtrue"
else
  DB_URL="postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=require"
fi

if cockroach sql --url "$DB_URL" -e "SELECT 1" >/dev/null 2>/tmp/crdb_test_err; then
  ok "Live query succeeded — connection is working!"
else
  fail "Live query failed. Error output:"
  cat /tmp/crdb_test_err >&2
  fail "Common causes:"
  fail "  - Wrong DB_USER or DB_PASSWORD / JWT token"
  fail "  - Wrong DB_NAME (database does not exist)"
  fail "  - SSL issue: try adding ?sslmode=require to your connection"
  fail "  - JWT: check token is not expired and JWT_AUTH_CONNECTION=true is set"
  exit 1
fi

log "────────────────────────────────────────"
log "All checks passed. DB connection is OK."
log "────────────────────────────────────────"
