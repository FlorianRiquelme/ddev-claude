#!/bin/bash
#ddev-generated
#
# generate-settings.sh - Register Claude Code hooks in settings.json
#
# Merges ddev-claude hook configuration into $CLAUDE_HOME/.claude/settings.json
# (bind-mounted from host ~/.claude/). Idempotent — skips if already registered.

set -euo pipefail

LOG_PREFIX="[ddev-claude]"
log() { echo "$LOG_PREFIX $*"; }
error() { echo "$LOG_PREFIX ERROR: $*" >&2; }

CLAUDE_HOME="${CLAUDE_HOME:-/root}"
SETTINGS_FILE="${CLAUDE_HOME}/.claude/settings.json"
BACKUP_FILE="${CLAUDE_HOME}/.claude/settings.json.ddev-backup"
HOOK_COMMAND_URL="/opt/ddev-claude/hooks/url-check.sh"
HOOK_COMMAND_SECRET="/opt/ddev-claude/hooks/secret-check.sh"

# Hook configs to inject
HOOK_CONFIG_URL=$(cat <<'HOOKJSON'
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

HOOK_CONFIG_SECRET=$(cat <<'HOOKJSON'
{
  "matcher": "Read|Edit|Write|Bash",
  "hooks": [
    {
      "type": "command",
      "command": "/opt/ddev-claude/hooks/secret-check.sh"
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

# Check which hooks need registration (idempotent)
needs_url=true
needs_secret=true

if echo "$existing" | jq -e --arg cmd "$HOOK_COMMAND_URL" \
    '.hooks.PreToolUse // [] | map(.hooks // []) | flatten | map(select(.command == $cmd)) | length > 0' \
    > /dev/null 2>&1; then
    needs_url=false
fi

if echo "$existing" | jq -e --arg cmd "$HOOK_COMMAND_SECRET" \
    '.hooks.PreToolUse // [] | map(.hooks // []) | flatten | map(select(.command == $cmd)) | length > 0' \
    > /dev/null 2>&1; then
    needs_secret=false
fi

if [[ "$needs_url" == "false" && "$needs_secret" == "false" ]]; then
    log "Hooks already registered in settings.json"
    exit 0
fi

# Back up original settings (first run only)
if [[ -f "$SETTINGS_FILE" && ! -f "$BACKUP_FILE" ]]; then
    cp "$SETTINGS_FILE" "$BACKUP_FILE"
    log "Backed up settings.json to settings.json.ddev-backup"
fi

# Deep-merge: append missing hook entries to existing PreToolUse array
merged="$existing"

if [[ "$needs_url" == "true" ]]; then
    merged=$(echo "$merged" | jq --argjson hook "$HOOK_CONFIG_URL" '
        .hooks //= {} |
        .hooks.PreToolUse //= [] |
        .hooks.PreToolUse += [$hook]
    ')
    log "Adding url-check hook"
fi

if [[ "$needs_secret" == "true" ]]; then
    merged=$(echo "$merged" | jq --argjson hook "$HOOK_CONFIG_SECRET" '
        .hooks //= {} |
        .hooks.PreToolUse //= [] |
        .hooks.PreToolUse += [$hook]
    ')
    log "Adding secret-check hook"
fi

# Ensure settings directory exists
mkdir -p "$(dirname "$SETTINGS_FILE")"

# Write back (atomic)
tmp_settings=$(mktemp)
echo "$merged" > "$tmp_settings"
mv "$tmp_settings" "$SETTINGS_FILE"

log "Registered PreToolUse hooks in settings.json"
