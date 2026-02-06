#!/bin/bash
#ddev-generated
set -euo pipefail

# Parse blocked domains from iptables LOG
# Outputs unique domain/IP list, one per line

LOG_PREFIX="[ddev-claude]"

# Get blocked IPs from kernel log
blocked_ips=$(dmesg 2>/dev/null | grep '\[FIREWALL-BLOCK\]' | grep -oP 'DST=\K[0-9.]+' | sort -u)

if [[ -z "$blocked_ips" ]]; then
    exit 0  # No blocked domains, silent exit
fi

# Try reverse DNS lookup for each IP
while IFS= read -r ip; do
    # Attempt reverse DNS (with timeout)
    domain=$(dig +short -x "$ip" +time=1 +tries=1 2>/dev/null | sed 's/\.$//' | head -1)

    if [[ -n "$domain" ]]; then
        echo "$domain"
    else
        # No reverse DNS, output IP with marker
        echo "$ip (no reverse DNS)"
    fi
done <<< "$blocked_ips" | sort -u
