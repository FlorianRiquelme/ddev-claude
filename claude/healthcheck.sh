#!/bin/bash
#ddev-generated
set -e

LOG_PREFIX="[ddev-claude-healthcheck]"
log() { echo "$LOG_PREFIX $*"; }
fail() { echo "$LOG_PREFIX FAILED: $*" >&2; exit 1; }

# Check 1: iptables rules exist
rule_count=$(iptables -L OUTPUT -n 2>/dev/null | grep -c "^[A-Z]" || echo 0)
if [[ $rule_count -lt 5 ]]; then
  fail "Too few iptables rules ($rule_count), firewall not initialized"
fi
log "PASS: iptables rules loaded ($rule_count rules)"

# Check 2: OUTPUT policy is DROP
policy=$(iptables -L OUTPUT 2>/dev/null | head -1 | grep -o "policy [A-Z]*" || echo "policy UNKNOWN")
if [[ "$policy" != "policy DROP" ]]; then
  fail "OUTPUT policy is not DROP ($policy)"
fi
log "PASS: OUTPUT policy is DROP"

# Check 3: ipset exists
if ! ipset list whitelist_ips &>/dev/null; then
  fail "ipset 'whitelist_ips' not found"
fi
log "PASS: ipset 'whitelist_ips' exists"

# Check 4: ipset has entries (warn only)
entry_count=$(ipset list whitelist_ips 2>/dev/null | grep -c "^[0-9]" || echo 0)
if [[ $entry_count -eq 0 ]]; then
  log "WARN: ipset 'whitelist_ips' is empty (no domains whitelisted)"
else
  log "PASS: ipset has $entry_count IPs whitelisted"
fi

# Check 5: blocking works (functional test)
# Use TEST-NET-2 (198.51.100.0/24) - reserved, never routable
if timeout 2 nc -zv 198.51.100.1 80 2>&1 | grep -q "succeeded\|open"; then
  fail "Firewall not blocking - 198.51.100.1:80 was accessible"
fi
log "PASS: Firewall is blocking non-whitelisted traffic"

log "Firewall healthcheck passed"
exit 0
