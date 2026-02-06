#!/bin/bash
#ddev-generated
#
# generate-settings.sh - Register Claude Code hooks in settings.json
#
# Merges ddev-claude hook configuration into /root/.claude/settings.json
# (bind-mounted from host ~/.claude/). Idempotent — skips if already registered.

set -euo pipefail

LOG_PREFIX="[ddev-claude]"
log() { echo "$LOG_PREFIX $*"; }
error() { echo "$LOG_PREFIX ERROR: $*" >&2; }

SETTINGS_FILE="/root/.claude/settings.json"
BACKUP_FILE="/root/.claude/settings.json.ddev-backup"
HOOK_COMMAND="/opt/ddev-claude/hooks/url-check.sh"

# Our hook config to inject
HOOK_CONFIG=$(cat <<'HOOKJSON'
{
  "matcher": "WebFetch|Bash|mcp__.*",
  "hooks": [
    {
      "type": "command",
      "command": "/opt/ddev-claude/hooks/url-check.sh"
    }
  ]
}
HOOKJSON
)

# Read existing settings (or empty object)
if [[ -f "$SETTINGS_FILE" ]]; then
    if ! existing=$(jq '.' "$SETTINGS_FILE" 2>/dev/null); then
        error "settings.json contains invalid JSON - please fix manually: $SETTINGS_FILE"
        exit 1
    fi
else
    existing='{}'
fi

# Check if our hook is already registered (idempotent)
if echo "$existing" | jq -e --arg cmd "$HOOK_COMMAND" \
    '.hooks.PreToolUse // [] | map(.hooks // []) | flatten | map(select(.command == $cmd)) | length > 0' \
    > /dev/null 2>&1; then
    log "Hooks already registered in settings.json"
    exit 0
fi

# Back up original settings (first run only)
if [[ -f "$SETTINGS_FILE" && ! -f "$BACKUP_FILE" ]]; then
    cp "$SETTINGS_FILE" "$BACKUP_FILE"
    log "Backed up settings.json to settings.json.ddev-backup"
fi

# Deep-merge: append our hook entry to existing PreToolUse array
merged=$(echo "$existing" | jq --argjson hook "$HOOK_CONFIG" '
    .hooks //= {} |
    .hooks.PreToolUse //= [] |
    .hooks.PreToolUse += [$hook]
')

# Ensure settings directory exists
mkdir -p "$(dirname "$SETTINGS_FILE")"

# Write back (atomic)
tmp_settings=$(mktemp)
echo "$merged" > "$tmp_settings"
mv "$tmp_settings" "$SETTINGS_FILE"

log "Registered PreToolUse hook in settings.json"
