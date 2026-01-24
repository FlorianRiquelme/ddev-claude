#!/bin/bash
# log-network-traffic.sh - Capture accessed domains during no-firewall session
#
# Usage:
#   log-network-traffic.sh start    - Start capturing DNS queries, outputs PID
#   log-network-traffic.sh stop PID - Stop capture and save unique domains

set -euo pipefail

RAW_LOG="/tmp/ddev-claude-traffic-raw.log"
ACCESSED_LOG="/tmp/ddev-claude-accessed.log"
PID_FILE="/tmp/ddev-claude-tcpdump.pid"

case "${1:-}" in
    start)
        # Clean up any previous captures
        rm -f "$RAW_LOG" "$ACCESSED_LOG" "$PID_FILE"

        # Start tcpdump writing directly to text log (not pcap)
        # -i any: capture on all interfaces
        # -n: don't resolve hostnames
        # -l: line buffered for real-time output
        # -v: verbose to show domain names in responses
        tcpdump -i any -n -l -v 'port 53' >> "$RAW_LOG" 2>&1 &

        TCPDUMP_PID=$!
        echo "$TCPDUMP_PID" > "$PID_FILE"

        # Give tcpdump a moment to start
        sleep 0.5

        echo "$TCPDUMP_PID"
        ;;

    stop)
        # Get PID from argument or file
        TCPDUMP_PID="${2:-}"
        if [[ -z "$TCPDUMP_PID" ]] && [[ -f "$PID_FILE" ]]; then
            TCPDUMP_PID=$(cat "$PID_FILE")
        fi

        if [[ -z "$TCPDUMP_PID" ]]; then
            echo "ERROR: No PID provided and no PID file found" >&2
            exit 1
        fi

        # Stop tcpdump gracefully
        if kill -0 "$TCPDUMP_PID" 2>/dev/null; then
            kill -TERM "$TCPDUMP_PID" 2>/dev/null || true
            sleep 1
        fi

        # Parse raw log to extract domain names from DNS responses
        if [[ -f "$RAW_LOG" ]]; then
            # Extract domains from DNS responses (format: "domain.com. A x.x.x.x")
            grep -oE '[a-zA-Z0-9][-a-zA-Z0-9]*(\.[a-zA-Z0-9][-a-zA-Z0-9]*)+\. (A|AAAA) ' "$RAW_LOG" 2>/dev/null | \
                awk '{print $1}' | \
                sed 's/\.$//' | \
                grep -v '^$' | \
                sort -u > "$ACCESSED_LOG" || true
        fi

        # Clean up temp files
        rm -f "$RAW_LOG" "$PID_FILE"
        ;;

    *)
        echo "Usage: $0 {start|stop [PID]}" >&2
        echo "" >&2
        echo "  start      - Start DNS traffic capture, outputs PID" >&2
        echo "  stop [PID] - Stop capture and save unique domains" >&2
        exit 1
        ;;
esac
