#!/bin/bash
#ddev-generated
set -euo pipefail

WHITELIST_FILE="${1:-${DDEV_APPROOT}/.ddev/claude/whitelist-domains.txt}"
LOG_PREFIX="[ddev-claude]"

log() { echo "$LOG_PREFIX $*"; }
warn() { echo "$LOG_PREFIX WARNING: $*" >&2; }

total_ips=0
failed_domains=()

if [[ ! -f "$WHITELIST_FILE" ]]; then
  warn "Whitelist file not found: $WHITELIST_FILE"
  exit 0  # Don't fail - just no domains to whitelist
fi

while IFS= read -r domain || [[ -n "$domain" ]]; do
  # Skip empty lines and comments
  [[ -z "$domain" || "$domain" =~ ^[[:space:]]*# ]] && continue

  # Trim whitespace
  domain=$(echo "$domain" | xargs)

  # Resolve domain with retries
  ips=$(dig +short +time=2 +tries=3 A "$domain" 2>/dev/null | grep -E '^[0-9]+\.' || true)

  if [[ -n "$ips" ]]; then
    while IFS= read -r ip; do
      ipset add -exist whitelist_ips "$ip" timeout 3600
      log "Whitelisted: $domain -> $ip"
      ((++total_ips))
    done <<< "$ips"
  else
    warn "Could not resolve $domain (skipping)"
    failed_domains+=("$domain")
  fi
done < "$WHITELIST_FILE"

log "Whitelist complete: $total_ips IPs added"
if [[ ${#failed_domains[@]} -gt 0 ]]; then
  warn "Failed to resolve: ${failed_domains[*]}"
fi
