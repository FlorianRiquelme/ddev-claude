#!/bin/bash
#
# watch-config.sh - Watch whitelist.json files for changes and trigger reload
#
# Uses inotify to watch config directories for changes.
# Implements debouncing to handle editor save patterns (temp file + atomic move).
# Validates JSON before reloading to prevent broken configs from affecting firewall.

set -euo pipefail

LOG_PREFIX="[ddev-claude-watch]"
SCRIPT_DIR="/var/www/html/.ddev/claude"
DEBOUNCE_DELAY=2  # seconds
PID_FILE="/var/run/ddev-claude-watcher.pid"

log() { echo "$LOG_PREFIX $*"; }
warn() { echo "$LOG_PREFIX WARNING: $*" >&2; }

# Check if already running
if [[ -f "$PID_FILE" ]]; then
    old_pid=$(cat "$PID_FILE")
    if kill -0 "$old_pid" 2>/dev/null; then
        log "Watcher already running (PID $old_pid)"
        exit 0
    fi
    rm -f "$PID_FILE"
fi

# Store our PID
echo $$ > "$PID_FILE"

# Cleanup on exit
cleanup() {
    rm -f "$PID_FILE"
    log "Watcher stopped"
}
trap cleanup EXIT

# Config file locations
GLOBAL_CONFIG="$HOME/.ddev/ddev-claude/whitelist.json"
PROJECT_CONFIG="/var/www/html/.ddev/ddev-claude/whitelist.json"

# Create config directories if needed
mkdir -p "$(dirname "$GLOBAL_CONFIG")" 2>/dev/null || true
mkdir -p "$(dirname "$PROJECT_CONFIG")" 2>/dev/null || true

# Create empty configs if missing
for config in "$GLOBAL_CONFIG" "$PROJECT_CONFIG"; do
    if [[ ! -f "$config" ]]; then
        echo '[]' > "$config"
        log "Created empty config: $config"
    fi
done

log "Watching config files for changes..."
log "  Global: $GLOBAL_CONFIG"
log "  Project: $PROJECT_CONFIG"

last_trigger=0

# Watch for changes (close_write and moved_to for atomic saves)
inotifywait -m -e close_write,moved_to \
    "$(dirname "$GLOBAL_CONFIG")" \
    "$(dirname "$PROJECT_CONFIG")" 2>/dev/null | \
while read -r dir action file; do
    # Only react to whitelist.json files
    [[ "$file" != "whitelist.json" ]] && continue

    now=$(date +%s)

    # Debounce: skip if within delay window
    if (( now - last_trigger < DEBOUNCE_DELAY )); then
        continue
    fi

    last_trigger=$now

    log "Config changed: $dir$file"

    # Validate JSON before reloading
    config_path="$dir$file"
    if ! jq empty < "$config_path" 2>/dev/null; then
        warn "Invalid JSON in $config_path - keeping previous whitelist"
        continue
    fi

    # Reload whitelist
    if "$SCRIPT_DIR/scripts/reload-whitelist.sh"; then
        log "Reload successful"
    else
        warn "Reload failed - firewall unchanged"
    fi
done
