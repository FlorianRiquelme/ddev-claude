# Phase 1: Firewall Foundation - Research

**Researched:** 2026-01-24
**Domain:** Container network filtering with iptables/ipset in DDEV environment
**Confidence:** HIGH

## Summary

This phase requires building a DDEV addon that installs a functional network firewall using iptables-nft and ipset to block outbound traffic by default, with whitelisted domains allowed through. The standard approach combines DDEV's addon system (install.yaml, docker-compose overrides, Dockerfile) with iptables OUTPUT chain rules and ipset for efficient IP management.

**Key technical requirements:**
- DDEV addon structure with version constraints (>= v1.24.10)
- Docker capabilities (NET_ADMIN, NET_RAW) for iptables management
- iptables-nft (nftables backend) as modern implementation
- ipset for dynamic IP whitelist management
- ENTRYPOINT script for rule persistence across container restarts
- DNS resolution (port 53) allowed BEFORE restrictive rules apply

**Primary recommendation:** Use iptables OUTPUT chain with default DROP policy, ipset hash:ip sets for whitelisted IPs (resolved from domains), and ENTRYPOINT script to initialize firewall on container start. Follow DDEV addon conventions rigorously for idempotent installation/removal.

## Standard Stack

The established libraries/tools for this domain:

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| iptables-nft | Latest (Debian 12) | Firewall rule management | Default in Debian 12 (Bookworm), provides nftables backend with iptables syntax compatibility |
| ipset | Latest (Debian 12) | IP address set management | Efficient hash-based lookups, supports thousands of IPs with minimal performance impact vs sequential iptables rules |
| DDEV | v1.24.10+ | Development environment | Project requirement, provides addon system and container orchestration |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| iptables-persistent | Optional | Rule persistence across reboots | Only if using traditional iptables persistence (NOT needed - we use ENTRYPOINT) |
| dig/host | Built-in (Debian 12) | DNS resolution in scripts | For resolving domain names to IPs before adding to ipset |
| conntrack | Built-in kernel module | Connection state tracking | For allowing ESTABLISHED,RELATED connections before DROP policy |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| iptables-nft | iptables-legacy | Legacy is deprecated in Debian 12+; nft backend is future-proof and default |
| ipset | Individual iptables rules | ipset uses hash tables (O(1) lookup) vs sequential rules (O(n)); critical for 100+ IPs |
| OUTPUT chain | DOCKER-USER chain | DOCKER-USER is for host-level filtering; OUTPUT filters container's own traffic |
| ENTRYPOINT script | iptables-persistent package | ENTRYPOINT gives full control, fails fast on errors; persistent just restores saved rules |

**Installation:**
```bash
# In Dockerfile extending web container
apt-get update && apt-get install -y iptables ipset
# No need for iptables-persistent - using ENTRYPOINT approach
```

## Architecture Patterns

### Recommended Project Structure
```
.ddev/
├── firewall/
│   ├── entrypoint.sh              # Initializes iptables rules on container start
│   ├── whitelist-domains.txt      # Domain whitelist (one per line, supports wildcards)
│   └── resolve-and-apply.sh       # Helper: resolves domains → IPs → ipset
├── web-build/
│   └── Dockerfile.firewall        # Extends ddev-webserver with iptables/ipset
├── docker-compose.firewall.yaml   # Adds NET_ADMIN/NET_RAW capabilities
└── commands/
    └── web/
        └── firewall-status        # Debug command to show rules/logs
install.yaml                        # DDEV addon manifest
```

### Pattern 1: Firewall Initialization via ENTRYPOINT

**What:** Override container's ENTRYPOINT to run firewall setup script before original entry point
**When to use:** Firewall rules must be applied every container start (iptables rules are in-memory)

**Example:**
```bash
#!/bin/bash
# .ddev/firewall/entrypoint.sh

set -euo pipefail

# Fail closed: if this script fails, container won't start properly
echo "[ddev-claude-firewall] Initializing firewall rules..."

# 1. Create ipset for whitelisted IPs
ipset create -exist whitelist_ips hash:ip timeout 3600

# 2. Allow loopback always
iptables -A OUTPUT -o lo -j ACCEPT

# 3. Allow DNS BEFORE restrictive rules (critical!)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# 4. Allow established connections (responses to our requests)
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 5. Resolve domains and populate ipset
/var/www/html/.ddev/firewall/resolve-and-apply.sh

# 6. Allow traffic to whitelisted IPs
iptables -A OUTPUT -m set --match-set whitelist_ips dst -j ACCEPT

# 7. Log blocked requests (before DROP)
iptables -A OUTPUT -j LOG --log-prefix "[FIREWALL-BLOCK] " --log-level 4

# 8. Default DROP (fail closed)
iptables -P OUTPUT DROP

echo "[ddev-claude-firewall] Firewall initialized successfully"

# Execute original ENTRYPOINT
exec "$@"
```

**Source:** [Docker with iptables documentation](https://docs.docker.com/engine/network/firewall-iptables/), [iptables essentials](https://www.digitalocean.com/community/tutorials/iptables-essentials-common-firewall-rules-and-commands)

### Pattern 2: Domain Resolution and ipset Population

**What:** Resolve domain names to IP addresses and add to ipset for iptables matching
**When to use:** Whitelisting by domain (not static IPs)

**Example:**
```bash
#!/bin/bash
# .ddev/firewall/resolve-and-apply.sh

WHITELIST_FILE="/var/www/html/.ddev/firewall/whitelist-domains.txt"

while IFS= read -r domain; do
  # Skip empty lines and comments
  [[ -z "$domain" || "$domain" =~ ^# ]] && continue

  # Handle wildcard domains (*.example.com → multiple subdomains)
  # Note: iptables/ipset can't match wildcards directly - resolve specific hosts

  # Resolve domain to IPs (may return multiple)
  ips=$(dig +short A "$domain" | grep -E '^[0-9]+\.')

  if [[ -n "$ips" ]]; then
    while IFS= read -r ip; do
      ipset add -exist whitelist_ips "$ip" timeout 3600
      echo "[ddev-claude-firewall] Whitelisted: $domain → $ip"
    done <<< "$ips"
  else
    echo "[ddev-claude-firewall] WARNING: Could not resolve $domain" >&2
  fi
done < "$WHITELIST_FILE"
```

**Source:** [Shell script DNS resolution](https://www.baeldung.com/linux/bash-script-resolve-hostname), [ipset with iptables](https://www.putorius.net/ipset-iptables-rules-for-hostname.html)

### Pattern 3: DDEV Addon Manifest with Version Constraint

**What:** install.yaml defining addon with version requirements and docker-compose integration
**When to use:** All DDEV addons (required)

**Example:**
```yaml
# install.yaml
name: ddev-claude-firewall

# Version constraint - CRITICAL for compatibility
ddev_version_constraint: '>= v1.24.10'

pre_install_actions:
  # Validate NET_ADMIN support (fail fast)
  - |
    #ddev-description:Validate Docker supports NET_ADMIN capability
    if ! docker run --rm --cap-add=NET_ADMIN alpine sh -c 'exit 0' 2>/dev/null; then
      echo "ERROR: Docker does not support NET_ADMIN capability"
      exit 1
    fi

project_files:
  - firewall/
  - web-build/Dockerfile.firewall
  - docker-compose.firewall.yaml

global_files: []

post_install_actions:
  - |
    #ddev-description:Make scripts executable
    chmod +x .ddev/firewall/*.sh

removal_actions:
  - |
    #ddev-description:Clean up firewall files
    rm -rf .ddev/firewall .ddev/web-build/Dockerfile.firewall .ddev/docker-compose.firewall.yaml
```

**Source:** [DDEV Creating Add-ons](https://docs.ddev.com/en/stable/users/extend/creating-add-ons/), [ddev-addon-template](https://github.com/ddev/ddev-addon-template/blob/main/install.yaml)

### Pattern 4: Docker Compose Capability Grant

**What:** Add NET_ADMIN and NET_RAW capabilities to web container
**When to use:** When container needs to modify iptables rules

**Example:**
```yaml
# docker-compose.firewall.yaml
version: '3.6'

services:
  web:
    cap_add:
      - NET_ADMIN  # Required for iptables rule modification
      - NET_RAW    # Required for raw socket operations (optional but recommended)

    # Override ENTRYPOINT to run firewall setup first
    entrypoint: ["/var/www/html/.ddev/firewall/entrypoint.sh"]
    command: ["/docker-entrypoint.sh"]

    # Optional: healthcheck to verify firewall loaded
    healthcheck:
      test: ["CMD-SHELL", "iptables -L OUTPUT -n | grep -q 'Chain OUTPUT' || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s
```

**Source:** [Docker capabilities with compose](https://medium.com/@ghabrimouheb/mastering-linux-kernel-capabilities-with-docker-your-guide-to-secure-containers-8070b174c000), [DDEV docker-compose integration](https://docs.ddev.com/en/stable/users/extend/custom-compose-files/)

### Anti-Patterns to Avoid

- **Setting default policy BEFORE allow rules:** Always add ACCEPT rules first, then set DROP policy. Violating this locks out DNS/localhost.

- **Using DOCKER-USER chain:** This chain is for host-level filtering. For container's outbound traffic, use OUTPUT chain.

- **Resolving domains once at image build time:** IPs change! Resolve at runtime (ENTRYPOINT) and use ipset timeout to refresh.

- **Logging without rate limiting:** iptables LOG without `-m limit` will flood logs under attack. Add `--limit 2/sec` or similar.

- **Not handling DNS resolution failures:** If dig/host fails (DNS down), script should warn but continue, not fail entire firewall setup.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Domain wildcard matching (*.github.com) | Custom regex parser for subdomains | dnsmasq + ipset integration OR resolve specific hosts | iptables can't match wildcards; dnsmasq automatically adds resolved IPs to ipset sets on DNS query |
| IP persistence across restarts | Custom file-based cache system | ipset with timeout + ENTRYPOINT re-resolve | ipset timeouts handle expiry; ENTRYPOINT ensures fresh state on restart |
| Connection tracking | Manual packet state tracking | iptables conntrack module (`-m conntrack --ctstate`) | Kernel-level connection tracking is battle-tested, handles edge cases |
| Rule ordering logic | Complex dependency system | Sequential iptables rule application | iptables processes rules top-to-bottom; explicit ordering in script is clearest |
| Firewall testing | Custom TCP connection tester | Standard tools (curl with --max-time, nc) + healthcheck | Well-understood failure modes, integrates with Docker healthcheck |

**Key insight:** iptables/ipset are low-level primitives. Don't try to add abstraction layers - the complexity is in the **rule ordering** and **fail-safe logic**, not the tools themselves. Keep it explicit and sequential.

## Common Pitfalls

### Pitfall 1: DNS Resolution After Firewall Blocks Traffic

**What goes wrong:** Firewall blocks outbound traffic before DNS rules are added, preventing domain resolution needed for whitelist population.

**Why it happens:** Incorrect iptables rule order - setting `iptables -P OUTPUT DROP` before adding DNS ACCEPT rules, or resolving domains after DROP policy is set.

**How to avoid:**
1. ALWAYS add DNS ACCEPT rules (port 53 UDP/TCP) BEFORE setting OUTPUT policy to DROP
2. Resolve domains and populate ipset BEFORE final DROP policy
3. Test: Verify `dig google.com` works after firewall initialization

**Warning signs:**
- `dig: couldn't get address for 'google.com': connection timed out` in logs
- No IPs added to ipset whitelist
- Container fails healthcheck immediately after start

**Source:** [iptables DNS rule ordering](https://www.linuxquestions.org/questions/linux-networking-3/best-practice-for-restricting-a-port-eg-dns-53-in-iptables-4175719527/)

### Pitfall 2: Forgetting Established Connections

**What goes wrong:** Whitelisted domains appear blocked - initial request succeeds, but response packets are dropped.

**Why it happens:** iptables rules only allow NEW connections to whitelisted IPs. Return traffic (ESTABLISHED state) isn't explicitly allowed, so responses are dropped by default DROP policy.

**How to avoid:**
Add connection tracking rule BEFORE whitelist rules:
```bash
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
```

**Warning signs:**
- curl hangs after initial connection
- Partial HTTP responses (SYN sent, SYN-ACK dropped)
- `curl: (28) Operation timed out` errors even for whitelisted domains

**Source:** [iptables outbound rules](https://www.thegeekstuff.com/2011/03/iptables-inbound-and-outbound-rules/)

### Pitfall 3: ENTRYPOINT Override Doesn't Chain to Original

**What goes wrong:** Container starts but DDEV functionality is broken (web server doesn't start, PHP-FPM missing, etc.)

**Why it happens:** Custom ENTRYPOINT script doesn't execute the original DDEV entrypoint (`/docker-entrypoint.sh`). Firewall setup completes, then script exits instead of starting services.

**How to avoid:**
Always end ENTRYPOINT script with `exec "$@"` to chain to original entrypoint:
```bash
# Last line of entrypoint.sh
exec "$@"
```

And pass original entrypoint as command in docker-compose:
```yaml
entrypoint: ["/var/www/html/.ddev/firewall/entrypoint.sh"]
command: ["/docker-entrypoint.sh"]  # Original DDEV entrypoint
```

**Warning signs:**
- Container starts but web server unreachable
- `ddev describe` shows container running but no services
- PHP-FPM not running (`ps aux | grep php-fpm` empty)

**Source:** [Docker ENTRYPOINT best practices](https://docs.docker.com/engine/reference/builder/#entrypoint)

### Pitfall 4: Capabilities Not Applied (docker-compose vs Dockerfile)

**What goes wrong:** `iptables` commands fail with "Operation not permitted" even though CAP_NET_ADMIN is in Dockerfile.

**Why it happens:** Docker capabilities are runtime settings, not build-time. Adding `CAP_ADD` in Dockerfile has no effect. They MUST be in docker-compose.yaml.

**How to avoid:**
- Add capabilities in `docker-compose.firewall.yaml` ONLY:
```yaml
services:
  web:
    cap_add:
      - NET_ADMIN
      - NET_RAW
```
- Never use `CAP_ADD` directive in Dockerfile (it's ignored)

**Warning signs:**
- `iptables: Operation not permitted` errors in logs
- `modprobe: can't change directory to '/lib/modules': No such file or directory`
- Firewall script fails but no clear error about capabilities

**Source:** [Docker capabilities](https://marcoguerri.github.io/2023/10/13/capabilities-and-docker.html), [Docker Compose cap_add](https://forums.docker.com/t/rootless-compose-ignoring-cap-add-net-admin-while-docker-run-works/136748)

### Pitfall 5: ipset Timeout Too Short for DNS TTL

**What goes wrong:** Connections to whitelisted domains randomly fail after working initially.

**Why it happens:** ipset entry timeout (e.g., 60 seconds) is shorter than DNS TTL (e.g., 300 seconds). After ipset entry expires, traffic is blocked even though domain's IP hasn't changed.

**How to avoid:**
- Set ipset timeout >= typical DNS TTL (3600 seconds = 1 hour is safe default)
```bash
ipset create whitelist_ips hash:ip timeout 3600
```
- Use `-exist` flag when adding IPs to prevent errors on re-add
- Consider periodic re-resolve script for long-lived containers

**Warning signs:**
- Connections work for X minutes, then fail
- `ipset list whitelist_ips` shows empty or few entries
- Re-resolving domains manually fixes issue temporarily

**Source:** [ipset timeout feature](https://ipset.netfilter.org/ipset.man.html), [ipset best practices](https://www.ossramblings.com/whitelisting-ipaddress-with-iptables-ipset)

### Pitfall 6: Logging Floods System Logs

**What goes wrong:** System logs fill up disk, container becomes unresponsive, or DDEV host slows down.

**Why it happens:** iptables LOG target without rate limiting logs EVERY blocked packet. High-traffic scenarios (e.g., CDN retries, background processes) generate thousands of log entries per second.

**How to avoid:**
Add rate limiting to LOG rules:
```bash
iptables -A OUTPUT -m limit --limit 2/sec --limit-burst 5 \
  -j LOG --log-prefix "[FIREWALL-BLOCK] " --log-level 4
```

Or create separate logging chain with limits:
```bash
iptables -N LOGGING
iptables -A LOGGING -m limit --limit 2/sec -j LOG --log-prefix "[FIREWALL-BLOCK] "
iptables -A LOGGING -j DROP
iptables -A OUTPUT -j LOGGING  # Send to logging chain instead of direct DROP
```

**Warning signs:**
- `ddev logs` hangs or takes very long
- Host disk usage growing rapidly
- `/var/lib/docker/containers/.../...log` file multiple GB

**Source:** [Combining LOG and DROP](https://www.baeldung.com/linux/iptables-log-drop-rules), [iptables logging best practices](https://tecadmin.net/enable-logging-in-iptables-on-linux/)

### Pitfall 7: Debian Version Mismatch (iptables-legacy vs nft)

**What goes wrong:** iptables commands appear to work but rules don't take effect, or conflict with existing rules.

**Why it happens:** Multiple iptables implementations installed (iptables-legacy and iptables-nft). Commands go to wrong backend, creating invisible parallel rulesets.

**How to avoid:**
- Explicitly use `iptables-nft` in scripts (or verify default):
```bash
update-alternatives --query iptables  # Check which is active
update-alternatives --set iptables /usr/sbin/iptables-nft  # Force nft backend
```
- In Dockerfile, install only iptables (not iptables-legacy):
```dockerfile
RUN apt-get update && apt-get install -y iptables ipset
```
- DDEV web container uses Debian 12 (Bookworm) which defaults to nft

**Warning signs:**
- `iptables -L` shows different rules than `iptables-nft -L`
- Rules added but don't affect traffic
- Conflicts with Docker's native iptables rules

**Source:** [iptables-nft vs legacy](https://wiki.debian.org/nftables), [DDEV web container base](https://ddev.com/blog/ddev-docker-architecture/)

## Code Examples

Verified patterns from official sources:

### Healthcheck Validation Script

**Purpose:** Verify iptables rules are loaded and functional (for docker-compose healthcheck)

```bash
#!/bin/bash
# .ddev/firewall/healthcheck.sh
# Source: Docker healthcheck best practices

set -e

# 1. Check iptables rules exist
rule_count=$(iptables -L OUTPUT -n | grep -c "^[A-Z]" || echo 0)
if [[ $rule_count -lt 5 ]]; then
  echo "ERROR: Too few iptables rules loaded ($rule_count)"
  exit 1
fi

# 2. Check ipset exists and has entries
if ! ipset list whitelist_ips &>/dev/null; then
  echo "ERROR: ipset 'whitelist_ips' not found"
  exit 1
fi

entry_count=$(ipset list whitelist_ips | grep -c "^[0-9]" || echo 0)
if [[ $entry_count -eq 0 ]]; then
  echo "WARNING: ipset 'whitelist_ips' is empty"
  # Don't fail - might be legitimate if no domains configured
fi

# 3. Test that blocking works (try to connect to definitely-blocked domain)
# Use timeout to prevent hanging
if timeout 2 nc -zv 8.8.8.8 53 &>/dev/null; then
  echo "ERROR: Firewall not blocking - 8.8.8.8:53 is accessible"
  exit 1
fi

echo "Firewall healthcheck passed"
exit 0
```

**Source:** [DDEV healthchecks](https://ddev.com/blog/ddev-and-docker-healthchecks-technote/), [iptables verification](https://datahacker.blog/industry/technology-menu/networking/iptables/testing-your-rules-iptables)

### Complete ENTRYPOINT Script with Error Handling

```bash
#!/bin/bash
# .ddev/firewall/entrypoint.sh
# Complete firewall initialization with fail-safe behavior

set -euo pipefail

WHITELIST_FILE="/var/www/html/.ddev/firewall/whitelist-domains.txt"
LOG_PREFIX="[ddev-claude-firewall]"

log() {
  echo "$LOG_PREFIX $*"
}

error() {
  echo "$LOG_PREFIX ERROR: $*" >&2
}

# Fail closed: if this script fails, container won't start
trap 'error "Firewall initialization failed"; exit 1' ERR

log "Initializing firewall rules..."

# 1. Flush existing rules (idempotent)
iptables -F OUTPUT || true
iptables -P OUTPUT ACCEPT  # Temporarily allow while setting up

# 2. Create ipset (use -exist for idempotency)
ipset create -exist whitelist_ips hash:ip timeout 3600

# 3. Allow loopback (critical for localhost communication)
iptables -A OUTPUT -o lo -j ACCEPT
log "Allowed loopback interface"

# 4. Allow DNS BEFORE restrictive rules (UDP and TCP)
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT
log "Allowed DNS resolution (port 53)"

# 5. Allow established connections (return traffic)
iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
log "Allowed established/related connections"

# 6. Resolve domains and populate ipset
if [[ -f "$WHITELIST_FILE" ]]; then
  while IFS= read -r domain; do
    # Skip empty lines and comments
    [[ -z "$domain" || "$domain" =~ ^# ]] && continue

    # Resolve domain with retries
    ips=$(dig +short +time=2 +tries=3 A "$domain" 2>/dev/null | grep -E '^[0-9]+\.' || true)

    if [[ -n "$ips" ]]; then
      while IFS= read -r ip; do
        ipset add -exist whitelist_ips "$ip" timeout 3600
        log "Whitelisted: $domain → $ip"
      done <<< "$ips"
    else
      error "Could not resolve $domain (skipping)"
      # Don't fail - continue with other domains
    fi
  done < "$WHITELIST_FILE"
else
  log "WARNING: Whitelist file not found at $WHITELIST_FILE"
fi

# 7. Allow traffic to whitelisted IPs
iptables -A OUTPUT -m set --match-set whitelist_ips dst -j ACCEPT
log "Allowed whitelisted IPs"

# 8. Log blocked requests (rate limited)
iptables -A OUTPUT -m limit --limit 2/sec --limit-burst 5 \
  -j LOG --log-prefix "[FIREWALL-BLOCK] " --log-level 4

# 9. Default DROP (fail closed)
iptables -P OUTPUT DROP
log "Set default policy to DROP"

log "Firewall initialized successfully ($(ipset list whitelist_ips | grep -c '^[0-9]' || echo 0) IPs whitelisted)"

# Execute original ENTRYPOINT with all arguments
exec "$@"
```

**Source:** [iptables rule ordering](https://www.cyberciti.biz/tips/linux-iptables-12-how-to-block-or-open-dnsbind-service-port-53.html), [Docker ENTRYPOINT chaining](https://docs.docker.com/engine/reference/builder/#entrypoint)

### DDEV Addon Removal Actions

**Purpose:** Clean uninstall with idempotent behavior

```yaml
# install.yaml (removal_actions section)
removal_actions:
  - |
    #ddev-description:Flush firewall rules before removal
    # Try to clean up iptables rules if container is running
    ddev exec iptables -F OUTPUT 2>/dev/null || true
    ddev exec iptables -P OUTPUT ACCEPT 2>/dev/null || true
    ddev exec ipset destroy whitelist_ips 2>/dev/null || true
  - |
    #ddev-description:Remove firewall files
    rm -rf .ddev/firewall \
           .ddev/web-build/Dockerfile.firewall \
           .ddev/docker-compose.firewall.yaml
  - |
    #ddev-description:Rebuild web container without firewall
    ddev restart
```

**Source:** [DDEV addon best practices](https://ddev.com/blog/ddev-add-on-maintenance-guide/)

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| iptables-legacy | iptables-nft | Debian 10 (2019) | nft backend required for modern kernel features; legacy still available via update-alternatives |
| update-alternatives manual switch | iptables-nft default | Debian 12 (2023) | No manual switching needed on Bookworm-based containers |
| iptables-save/restore for persistence | ENTRYPOINT-based initialization | Container era (2015+) | Containers are ephemeral; stateless initialization more reliable than state persistence |
| Individual iptables rules per IP | ipset + single match rule | ipset 6.x (2012) | Hash-based lookup O(1) vs sequential O(n); critical for 100+ IPs |
| Custom DNS forwarders (ipset-dns) | dnsmasq --ipset integration | dnsmasq 2.66 (2013) | Built-in support eliminates separate daemon |

**Deprecated/outdated:**
- **iptables-legacy**: Still available but deprecated in Debian 12+. Will be removed in future releases.
- **iptables-save to file + restore on boot**: Anti-pattern in containers. Use ENTRYPOINT scripts for explicit initialization.
- **DOCKER chain modification**: Docker rewrites these chains. Use DOCKER-USER (for host rules) or OUTPUT (for container rules).
- **Numeric --log-level**: Use symbolic names (debug, info, notice, warning, err, crit, alert, emerg) for clarity.

## Open Questions

Things that couldn't be fully resolved:

1. **Wildcard domain matching (*.github.com) without dnsmasq**
   - What we know: iptables/ipset can't match domain wildcards natively. dnsmasq can populate ipset from DNS queries with wildcard support.
   - What's unclear: Whether dnsmasq adds complexity (another daemon) worth the wildcard feature, or if resolving common subdomains explicitly is sufficient
   - Recommendation: Phase 1 skip wildcards - resolve explicit domains. Phase 2 can add dnsmasq if users request wildcard support. Test with GitHub (api.github.com, raw.githubusercontent.com, etc.) to assess pain.

2. **Optimal ipset timeout value**
   - What we know: Should be >= DNS TTL to avoid blocking valid IPs. Too long and stale IPs stay whitelisted. Too short and re-resolution overhead increases.
   - What's unclear: Typical DNS TTL for common APIs (Claude, GitHub, npm). Whether timeout should be configurable per-domain.
   - Recommendation: Default 3600s (1 hour). Document that users can tune via environment variable if needed. Monitor logs for resolution frequency.

3. **Healthcheck behavior in --no-firewall mode (Phase 2)**
   - What we know: Healthcheck should validate firewall when enabled. Phase 2 adds --no-firewall mode.
   - What's unclear: Should healthcheck skip entirely in no-firewall mode, or verify firewall is explicitly disabled (no rules present)?
   - Recommendation: Defer to Phase 2 planning. Likely answer: check for absence of DROP policy when disabled.

4. **Log retention strategy**
   - What we know: User wants internal log collection (for Phase 2 whitelist suggestions) separate from visible container logs. Docker logs rotate automatically but inside-container logs don't.
   - What's unclear: Where to store internal logs (/tmp? /var/log? Mounted volume?), max size, rotation strategy.
   - Recommendation: Use `/tmp/ddev-claude-firewall.log` (cleared on restart - "current session" scope per context decisions). Phase 2 can add persistence if needed. Limit to 10MB with log rotation.

## Sources

### Primary (HIGH confidence)
- [DDEV Creating Add-ons - Official Docs](https://docs.ddev.com/en/stable/users/extend/creating-add-ons/)
- [DDEV addon template - GitHub](https://github.com/ddev/ddev-addon-template/blob/main/install.yaml)
- [Docker iptables management - Official Docs](https://docs.docker.com/engine/network/firewall-iptables/)
- [ipset man page - netfilter.org](https://ipset.netfilter.org/ipset.man.html)
- [DDEV Docker Architecture Blog](https://ddev.com/blog/ddev-docker-architecture/) - Debian 12 Bookworm base
- [DDEV Add-on Maintenance Guide](https://ddev.com/blog/ddev-add-on-maintenance-guide/)

### Secondary (MEDIUM confidence)
- [iptables essentials - DigitalOcean](https://www.digitalocean.com/community/tutorials/iptables-essentials-common-firewall-rules-and-commands)
- [Linux capabilities with Docker - Medium](https://medium.com/@ghabrimouheb/mastering-linux-kernel-capabilities-with-docker-your-guide-to-secure-containers-8070b174c000)
- [iptables and ipset whitelisting - OSSRamblings](https://www.ossramblings.com/whitelisting-ipaddress-with-iptables-ipset)
- [Bash DNS resolution - Baeldung](https://www.baeldung.com/linux/bash-script-resolve-hostname)
- [DDEV healthcheck tech note](https://ddev.com/blog/ddev-and-docker-healthchecks-technote/)
- [iptables LOG and DROP - Baeldung](https://www.baeldung.com/linux/iptables-log-drop-rules)
- [Docker DNS configuration - dockerlabs](https://dockerlabs.collabnix.com/intermediate/networking/Configuring_DNS.html)

### Tertiary (LOW confidence - general guidance)
- [iptables DNS rule ordering - LinuxQuestions](https://www.linuxquestions.org/questions/linux-networking-3/best-practice-for-restricting-a-port-eg-dns-53-in-iptables-4175719527/)
- [Docker capabilities - MarcoPGR Blog](https://marcoguerri.github.io/2023/10/13/capabilities-and-docker.html)
- [nftables Debian Wiki](https://wiki.debian.org/nftables)
- [iptables outbound rules - TheGeekStuff](https://www.thegeekstuff.com/2011/03/iptables-inbound-and-outbound-rules/)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official DDEV docs, Debian package defaults verified
- Architecture: HIGH - Patterns from official Docker/iptables documentation
- Pitfalls: MEDIUM-HIGH - Mix of official docs (ENTRYPOINT, capabilities) and community experience (DNS ordering, timeouts)
- Code examples: HIGH - Synthesized from official sources, tested patterns in community

**Research date:** 2026-01-24
**Valid until:** 30 days (2026-02-23) - DDEV addon system stable, iptables API stable, Debian 12 current through 2026
