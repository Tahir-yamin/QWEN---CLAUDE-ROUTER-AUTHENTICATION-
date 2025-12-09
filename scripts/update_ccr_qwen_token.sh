#!/usr/bin/env bash
set -euo pipefail

QWEN_CREDS="${QWEN_CREDS:-$HOME/.qwen/oauth_creds.json}"
CCR_CONFIG="${CCR_CONFIG:-$HOME/.claude-code-router/config.json}"

# Check for jq
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required. Install it (apt/brew/etc) and re-run."
  exit 2
fi

# Validate paths
if [ ! -f "$QWEN_CREDS" ]; then
  echo "Error: Qwen creds not found at $QWEN_CREDS"
  exit 2
fi

if [ ! -f "$CCR_CONFIG" ]; then
  echo "Error: CCR config not found at $CCR_CONFIG"
  exit 2
fi

TOKEN=$(jq -r '.access_token // empty' "$QWEN_CREDS")
if [ -z "$TOKEN" ]; then
  echo "Error: access_token not found in $QWEN_CREDS"
  exit 2
fi

# Backup config
cp "$CCR_CONFIG" "${CCR_CONFIG}.bak.$(date +%s)"
TMP="$(mktemp)"
UPDATED=false

# 1) top-level APIKEY or api_key (case-insensitive attempt)
if jq -e 'has("APIKEY") or has("api_key") or has("API_KEY")' "$CCR_CONFIG" >/dev/null 2>&1; then
  # Prefer api_key if present, otherwise APIKEY
  if jq -e 'has("api_key")' "$CCR_CONFIG" >/dev/null 2>&1; then
    jq --arg t "$TOKEN" '.api_key = $t' "$CCR_CONFIG" > "$TMP"
  elif jq -e 'has("APIKEY")' "$CCR_CONFIG" >/dev/null 2>&1; then
    jq --arg t "$TOKEN" '.APIKEY = $t' "$CCR_CONFIG" > "$TMP"
  else
    jq --arg t "$TOKEN" '.API_KEY = $t' "$CCR_CONFIG" > "$TMP"
  fi
  mv "$TMP" "$CCR_CONFIG"
  echo "Updated top-level api key in $CCR_CONFIG"
  UPDATED=true
fi

# 2) single-provider object with name == "qwen"
if [ "$UPDATED" = false ] && jq -e '(.name? == "qwen")' "$CCR_CONFIG" >/dev/null 2>&1; then
  jq --arg t "$TOKEN" '.api_key = $t' "$CCR_CONFIG" > "$TMP"
  mv "$TMP" "$CCR_CONFIG"
  echo "Updated api_key for single-provider config named 'qwen'"
  UPDATED=true
fi

# 3) Providers array (case-insensitive common names: Providers or providers)
if [ "$UPDATED" = false ] && jq -e '(.Providers? | type == "array") or (.providers? | type == "array")' "$CCR_CONFIG" >/dev/null 2>&1; then
  # Try both keys
  if jq -e '.Providers[] | select(.name=="qwen")' "$CCR_CONFIG" >/dev/null 2>&1; then
    jq --arg t "$TOKEN" '( .Providers[] | select(.name=="qwen") | .api_key ) = $t' "$CCR_CONFIG" > "$TMP"
    mv "$TMP" "$CCR_CONFIG"
    echo "Updated api_key for provider 'qwen' in .Providers[]"
    UPDATED=true
  elif jq -e '.providers[] | select(.name=="qwen")' "$CCR_CONFIG" >/dev/null 2>&1; then
    jq --arg t "$TOKEN" '( .providers[] | select(.name=="qwen") | .api_key ) = $t' "$CCR_CONFIG" > "$TMP"
    mv "$TMP" "$CCR_CONFIG"
    echo "Updated api_key for provider 'qwen' in .providers[]"
    UPDATED=true
  else
    echo "Warning: config has Providers/providers array but no provider named 'qwen'. No change made."
  fi
fi

if [ "$UPDATED" = false ]; then
  echo "Could not detect where to put api_key in $CCR_CONFIG."
  echo "You can update manually. Token is:"
  echo
  echo "$TOKEN"
  echo
  echo "If you want the script to handle a different schema, edit it."
  exit 3
fi

# Restart ccr if available
if command -v ccr >/dev/null 2>&1; then
  echo "Restarting ccr..."
  ccr stop || true
  ccr start || true
  echo "ccr restarted (if the commands exist)."
else
  echo "ccr command not found; please restart your Router manually: ccr stop && ccr start"
fi

echo "Done. Backup of previous config saved as: ${CCR_CONFIG}.bak.*"