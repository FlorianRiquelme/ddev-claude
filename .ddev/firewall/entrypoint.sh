#!/bin/bash
set -euo pipefail

LOG_PREFIX="[ddev-claude]"
WHITELIST_FILE="/var/www/html/.ddev/firewall/whitelist-domains.txt"
BLOCKED_LOG="/tmp/ddev-claude-blocked.log"

log() { echo "$LOG_PREFIX $*"; }
error() { echo "$LOG_PREFIX ERROR: $*" >&2; }

# Error trap - fail closed
trap 'error "Firewall initialization failed - blocking all traffic"; exit 1' ERR

log "Initializing firewall rules..."

# 1. Setup phase - flush and set ACCEPT temporarily
log "Flushing existing OUTPUT rules..."
iptables -F OUTPUT || true
iptables -P OUTPUT ACCEPT

# 2. Create ipset for whitelisted IPs
log "Creating ipset for whitelisted IPs..."
ipset create -exist whitelist_ips hash:ip timeout 3600

# 3. Allow loopback (FIRST rule - critical for localhost)
log "Allowing loopback traffic..."
iptables -A OUTPUT -o lo -j ACCEPT

# 4. Allow DNS (BEFORE any restrictions)
log "Allowing DNS resolution..."
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# 5. Allow established connections
log "Allowing established/related connections..."
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 6. Resolve and populate whitelist
log "Resolving whitelisted domains..."
/var/www/html/.ddev/firewall/resolve-and-apply.sh

# 7. Allow whitelisted IPs
log "Allowing whitelisted IPs..."
iptables -A OUTPUT -m set --match-set whitelist_ips dst -j ACCEPT

# 8. Initialize blocked request log for Phase 2 whitelist suggestions
> "$BLOCKED_LOG"  # Truncate on start (current session only)
log "Initialized blocked request log at $BLOCKED_LOG"

# 9. Visible logging (rate limited to prevent log flooding)
# Phase 2 will parse kernel log for whitelist suggestions
log "Setting up blocked traffic logging..."
iptables -A OUTPUT -m limit --limit 2/sec --limit-burst 5 -j LOG --log-prefix "[FIREWALL-BLOCK] " --log-level warning

# 10. Default DROP (LAST - fail closed)
log "Setting default DROP policy..."
iptables -P OUTPUT DROP

log "Firewall initialized successfully"
log "Policy: Default DENY, whitelisted domains allowed"
log "To see blocked requests: dmesg | grep FIREWALL-BLOCK"

# 11. Chain to original DDEV entrypoint
exec "$@"
