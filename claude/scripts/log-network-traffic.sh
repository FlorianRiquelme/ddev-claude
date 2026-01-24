#!/bin/bash
# log-network-traffic.sh - Capture accessed domains during no-firewall session
#
# Usage:
#   log-network-traffic.sh start    - Start capturing DNS queries, outputs PID
#   log-network-traffic.sh stop PID - Stop capture and save unique domains

set -euo pipefail

PCAP_FILE="/tmp/ddev-claude-traffic.pcap"
ACCESSED_LOG="/tmp/ddev-claude-accessed.log"
PID_FILE="/tmp/ddev-claude-tcpdump.pid"

case "${1:-}" in
    start)
        # Clean up any previous captures
        rm -f "$PCAP_FILE" "$ACCESSED_LOG" "$PID_FILE"

        # Start tcpdump in background to capture DNS queries (port 53)
        # -i any: capture on all interfaces
        # -n: don't resolve hostnames (avoid recursive lookups)
        # -s 0: capture full packets
        # port 53: DNS traffic only
        # -w: write to pcap file
        tcpdump -i any -n -s 0 'port 53' -w "$PCAP_FILE" >/dev/null 2>&1 &

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
            # Wait for tcpdump to flush buffers
            sleep 1
        fi

        # Parse pcap file to extract queried domain names
        if [[ -f "$PCAP_FILE" ]]; then
            # Use tcpdump to read the pcap and extract DNS queries
            # -r: read from file
            # -n: don't resolve
            # -l: line buffered
            # Filter for DNS queries (not responses) and extract domain names
            tcpdump -r "$PCAP_FILE" -n -l 2>/dev/null | \
                grep -oP 'A\? \K[^ ]+' | \
                sed 's/\.$//' | \
                grep -v '^$' | \
                sort -u > "$ACCESSED_LOG" || true

            # Alternative parsing if grep -P not available (BSD systems)
            if [[ ! -s "$ACCESSED_LOG" ]]; then
                tcpdump -r "$PCAP_FILE" -n 2>/dev/null | \
                    awk '/A\?/ {for(i=1;i<=NF;i++) if($i=="A?") print $(i+1)}' | \
                    sed 's/\.$//' | \
                    grep -v '^$' | \
                    sort -u > "$ACCESSED_LOG" || true
            fi
        fi

        # Clean up temp files
        rm -f "$PCAP_FILE" "$PID_FILE"
        ;;

    *)
        echo "Usage: $0 {start|stop [PID]}" >&2
        echo "" >&2
        echo "  start      - Start DNS traffic capture, outputs PID" >&2
        echo "  stop [PID] - Stop capture and save unique domains" >&2
        exit 1
        ;;
esac
