#!/bin/bash
#ddev-generated
# run-claude-no-firewall.sh - Run Claude with firewall disabled and traffic logging
#
# Usage: run-claude-no-firewall.sh [claude args...]

RAW_LOG="/tmp/ddev-claude-traffic-raw.log"
ACCESSED_LOG="/tmp/ddev-claude-accessed.log"
TCPDUMP_PID=""

cleanup() {
    # Stop tcpdump
    if [[ -n "$TCPDUMP_PID" ]]; then
        kill -TERM "$TCPDUMP_PID" 2>/dev/null || true
        sleep 1
    fi

    # Parse domains from log
    if [[ -f "$RAW_LOG" ]]; then
        # Debug: keep a copy of raw log
        cp "$RAW_LOG" /tmp/ddev-claude-traffic-raw-debug.log 2>/dev/null || true

        grep -oE '[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+\. (A|AAAA) ' "$RAW_LOG" 2>/dev/null | \
            awk '{print $1}' | \
            sed 's/\.$//' | \
            grep -v '^$' | \
            sort -u > "$ACCESSED_LOG" || true
        rm -f "$RAW_LOG"
    else
        echo "NO_RAW_LOG" > "$ACCESSED_LOG"
    fi
}

# Ensure cleanup runs on exit, interrupt, or termination
trap cleanup EXIT INT TERM

# Clean up previous
rm -f "$RAW_LOG" "$ACCESSED_LOG"

# Start tcpdump in background
tcpdump -i any -n -l -v 'port 53' >> "$RAW_LOG" 2>&1 &
TCPDUMP_PID=$!
sleep 0.5

# Disable firewall
iptables -F OUTPUT
iptables -P OUTPUT ACCEPT

# Tell hooks to passthrough (no firewall = no blocking)
export DDEV_CLAUDE_NO_FIREWALL=1

# Run claude with all passed arguments
"${DDEV_APPROOT}/.ddev/claude/scripts/run-as-claude.sh" claude "$@"
