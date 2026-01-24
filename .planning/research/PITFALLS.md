# Pitfalls Research

**Domain:** DDEV addon with iptables firewall in Docker containers
**Researched:** 2026-01-24
**Confidence:** HIGH

## Critical Pitfalls

### Pitfall 1: iptables Rules in Wrong Chain (FORWARD vs DOCKER-USER)

**What goes wrong:**
Firewall rules added to the standard FORWARD chain execute AFTER Docker's built-in filtering, making them completely ineffective. Container traffic bypasses custom rules entirely, leaving the firewall non-functional despite appearing configured correctly.

**Why it happens:**
Developers assume the FORWARD chain works like traditional iptables on bare metal. Docker's architecture creates custom chains (DOCKER, DOCKER-FORWARD) that process traffic before reaching user FORWARD rules. Packets accepted/rejected by Docker's chains never reach FORWARD rules.

**How to avoid:**
- Always use the DOCKER-USER chain for custom container filtering rules
- DOCKER-USER is specifically designed as "a placeholder for user-defined rules that will be processed before rules in the DOCKER-FORWARD and DOCKER chains"
- Place permissive rules (established connections) BEFORE restrictive DROP rules
- Test with `iptables -L -v -n` showing packet counts to verify rules are actually matching traffic

**Warning signs:**
- iptables rules show zero packet counts after expected traffic
- Firewall appears configured but containers can access blocked resources
- Rules work on host but not for container traffic
- Testing shows packets hit DOCKER chain but not custom rules

**Phase to address:**
Phase 1 (Firewall Foundation) — Architecture must use DOCKER-USER from the start, refactoring later is error-prone.

---

### Pitfall 2: iptables Rules Don't Persist Across Container Restarts

**What goes wrong:**
Firewall rules configured during container startup disappear when the container restarts. Worse, if iptables-persistent or similar tools run AFTER Docker starts, they can overwrite Docker's networking rules, breaking container networking completely until Docker daemon restarts.

**Why it happens:**
iptables rules exist in kernel memory, not in the container's filesystem. Container restart doesn't preserve kernel state. Even with NET_ADMIN capability, rules applied inside the container are ephemeral. Host-level persistence tools can conflict with Docker's dynamic rule generation.

**How to avoid:**
- Apply iptables rules during ENTRYPOINT execution on every container start
- Use idempotent rule application (check before adding, use `-C` to test rule existence)
- For DOCKER-USER rules applied from host: ensure they're applied BEFORE Docker starts, or use Docker daemon hooks
- Never rely on iptables-persistent when running Docker — it will break Docker networking
- Store firewall configuration in version-controlled script files, not saved iptables state

**Warning signs:**
- Container works after `ddev start` but fails after `ddev restart`
- Firewall rules missing after container recreation
- Docker networking breaks after system reboot
- Rules present immediately after startup but gone later

**Phase to address:**
Phase 1 (Firewall Foundation) — Startup script architecture must handle rule application lifecycle from the beginning.

---

### Pitfall 3: DNS Resolution Happens Before Firewall Rules Apply

**What goes wrong:**
Container startup order causes the firewall to initialize before DNS resolution completes, resulting in either empty ipsets (blocking everything) or race conditions where some domains resolve while others don't. Subsequent domain resolutions fail because the firewall blocks the DNS queries needed to update ipsets.

**Why it happens:**
Docker Compose's `depends_on` only waits for container status "running", not "ready to accept connections". DNS queries during firewall initialization may fail if DNS server isn't available yet. Once firewall applies restrictive rules, it may block the DNS traffic needed to refresh domain resolutions.

**How to avoid:**
- Use `depends_on` with `service_healthy` condition, requiring healthcheck on DNS-dependent services
- Implement retry logic with exponential backoff for DNS resolution during startup
- Always whitelist DNS traffic (UDP/TCP port 53) before applying restrictive rules
- Use Docker's embedded DNS server (127.0.0.11) which is container-local, not network-dependent
- Apply firewall rules in stages: DNS allowlist first, then domain resolution, then restrictive rules

**Warning signs:**
- Firewall works inconsistently — sometimes allows traffic, sometimes blocks everything
- `ipset list` shows empty sets or partial results
- DNS resolution fails after firewall initialization
- Different behavior between `ddev start` (fresh) and `ddev restart` (cached DNS)

**Phase to address:**
Phase 2 (DNS Integration) — DNS and firewall must initialize in correct order with proper healthchecks.

---

### Pitfall 4: ipset Can't Track Dynamic IPs Without Update Mechanism

**What goes wrong:**
Domain-based whitelisting appears to work initially but breaks when external services change IP addresses (CDNs, cloud providers rotate IPs regularly). The ipset contains stale IPs, blocking legitimate traffic while potentially allowing traffic to old, now-unused IPs.

**Why it happens:**
iptables works on IP addresses, not hostnames. Domain resolution happens once at firewall initialization, but IPs change over time. ipset is an efficient lookup structure but doesn't auto-refresh. Services like GitHub, AWS, Google frequently rotate IPs for load balancing and scaling.

**How to avoid:**
- Implement periodic DNS re-resolution (cron-like mechanism inside container)
- Use `ipset flush` and re-populate rather than trying to diff updates
- Consider TTL-aware refresh: parse DNS TTL and schedule next resolution accordingly
- For critical services, maintain both old and new IPs during transition (grace period)
- Log IP changes for debugging and monitoring domain migration patterns
- Accept that some services (CDNs) have hundreds of IPs — may need CIDR range allowlisting instead

**Warning signs:**
- Firewall works for days/weeks then suddenly blocks legitimate traffic
- Different behavior across DDEV restarts (fresh DNS vs. cached)
- Traffic to high-availability services (GitHub, npm) intermittently fails
- ipset contents don't match current `dig` results for whitelisted domains

**Phase to address:**
Phase 3 (Dynamic IP Updates) — After basic firewall works, implement refresh mechanism before declaring feature complete.

---

### Pitfall 5: DDEV Addon Files Not Using Namespaced Directories

**What goes wrong:**
Addon files placed in generic directories like `.ddev/scripts/` or `.ddev/config/` conflict with other addons or user customizations. File overwrites during addon updates destroy user configurations. Removal process can't safely delete files without risking damage to other addons.

**Why it happens:**
Developers treat `.ddev/` like a single-purpose directory and don't anticipate multi-addon environments. DDEV's addon system allows multiple addons to coexist, but without namespacing, they share the same filesystem paths.

**How to avoid:**
- Use namespaced directories: `.ddev/ddev-claude/scripts/`, `.ddev/ddev-claude/config/`
- Include `#ddev-generated` stanza in ALL created files for proper cleanup
- Make installation idempotent — check file existence before copying
- Test addon with common addons installed (ddev-redis, ddev-memcached)
- Document file structure clearly in README
- Use unique service names in docker-compose files

**Warning signs:**
- Addon installation overwrites existing files without warning
- Removal leaves orphaned files
- Conflicts with other popular addons
- User-customized scripts get replaced during addon update

**Phase to address:**
Phase 1 (Addon Structure) — File organization must be correct from first commit; refactoring breaks existing installations.

---

### Pitfall 6: Missing or Inadequate Healthcheck Causes Startup Race Conditions

**What goes wrong:**
DDEV starts dependent services before the firewall container is actually ready, resulting in connection failures, timeout errors, or services starting in degraded state. Worse, other services may cache "firewall unavailable" state and require manual restart even after firewall becomes healthy.

**Why it happens:**
DDEV uses healthchecks to determine service readiness. Without a proper healthcheck, DDEV considers the container "ready" as soon as the process starts, not when it's actually functional. Firewall initialization (loading rules, resolving domains, populating ipsets) takes time. Default `depends_on` behavior only waits for "running" status.

**How to avoid:**
- Implement comprehensive healthcheck testing actual firewall functionality (not just process existence)
- Test that iptables rules are loaded: `iptables -L DOCKER-USER | grep -q "specific-rule"`
- Verify ipsets contain entries: `ipset list allowed-domains -o plain | grep -q .`
- Use `depends_on: service_healthy` in services that need firewall protection
- Set appropriate healthcheck intervals (10s), timeout (5s), retries (3), start_period (30s)
- Log healthcheck execution for debugging startup failures

**Warning signs:**
- Services start but can't connect to network until manual restart
- Intermittent failures during `ddev start` but `ddev restart` works
- Logs show firewall rules applied AFTER services attempted network access
- Different behavior between fast and slow machines (race condition indicator)

**Phase to address:**
Phase 1 (Firewall Foundation) — Healthcheck architecture must exist before other services integrate.

---

### Pitfall 7: Firewall Rules Use Internal IPs After DNAT, Not Original Source

**What goes wrong:**
Source IP filtering in iptables rules only sees Docker's internal network IPs (172.17.x.x), not the actual source of requests. Rules intended to block external access fail because traffic appears to come from Docker's bridge network. Logs show confusing IP addresses that don't match actual client IPs.

**Why it happens:**
By the time packets reach the DOCKER-USER chain, they've "already passed through a Destination Network Address Translation (DNAT) filter." Standard iptables flags (-s, -d) match post-DNAT addresses. To access original addresses requires the `conntrack` extension, which adds performance overhead.

**How to avoid:**
- For this addon's use case (outbound filtering from container), this isn't relevant — we control what the container initiates
- If implementing inbound filtering: use `conntrack` extension with `--ctorigdst` and `--ctorigsrc`
- Be aware performance cost of connection tracking for every packet
- Log actual matched IPs during testing to verify expectations
- Consider whether source IP filtering is even needed (may want authenticated filtering instead)

**Warning signs:**
- Source IP rules show Docker bridge IPs (172.x.x.x) in logs instead of real client IPs
- Rules intended to block external access don't work
- Allow/deny decisions based on source appear to match everything or nothing
- Confusion between pre-DNAT and post-DNAT addressing in debugging

**Phase to address:**
Not applicable for this project (outbound filtering only), but document for future inbound filtering features.

---

### Pitfall 8: NET_ADMIN Capability Not Properly Declared in docker-compose

**What goes wrong:**
Container fails to apply iptables rules with "Permission denied" errors even when running as root. Firewall appears completely non-functional despite correct rule syntax. Error messages are cryptic and don't clearly indicate capability issue.

**Why it happens:**
Docker's security model requires explicit capability grants for privileged operations. iptables manipulation needs `NET_ADMIN` (network configuration) and `NET_RAW` (raw socket access) capabilities. Default container security drops these capabilities even for root user. Developers assume root = all permissions.

**How to avoid:**
- Add to `docker-compose.*.yaml`:
  ```yaml
  cap_add:
    - NET_ADMIN
    - NET_RAW
  ```
- Test in isolated container first: `docker run --rm --cap-add=NET_ADMIN --cap-add=NET_RAW alpine iptables -L`
- Document security implications — these are powerful capabilities
- Consider if alternative architectures avoid needing NET_ADMIN (host-based firewall vs. container-based)
- Never use `privileged: true` as workaround — grants unnecessary capabilities

**Warning signs:**
- `iptables` commands fail with "Permission denied" or "Operation not permitted"
- Works in privileged container but not in production
- Error messages mention "capabilities" or "CAP_NET_ADMIN"
- Rules apply successfully on host but not in container

**Phase to address:**
Phase 0 (DDEV Addon Skeleton) — Must be in initial docker-compose.yaml or first container start will fail.

---

### Pitfall 9: Addon Dependencies Not Declared, Causing Silent Installation Failures

**What goes wrong:**
Addon installs successfully but doesn't function because required tools (iptables, ipset, dig) aren't available in the container. Or addon assumes DDEV version features that don't exist in user's installed version. Errors appear during runtime, not installation, making debugging difficult.

**Why it happens:**
DDEV addons run in existing container contexts (web container, custom containers). Base images may not include network utilities. Different DDEV versions have different features (docker-compose schema support, healthcheck capabilities). Developers test on their local environment which has all dependencies.

**How to avoid:**
- Declare `ddev_version_constraint` in `install.yaml`: `">= v1.24.10"` for modern features
- Document required container packages clearly
- For custom containers: specify base image with required tools or install during build
- Use dependency checking in installation actions: test for `iptables`, `ipset`, `dig` availability
- Provide clear error messages when dependencies missing
- Test addon on minimal DDEV installation, not development environment

**Warning signs:**
- Addon installs without errors but features don't work
- "command not found" errors during runtime
- Different behavior on different DDEV versions
- Works for addon developer but not for users

**Phase to address:**
Phase 0 (DDEV Addon Skeleton) — `install.yaml` must have correct constraints before first release.

---

### Pitfall 10: DOCKER-USER Chain Doesn't Exist or Not at Top of FORWARD Chain

**What goes wrong:**
If the DOCKER-USER chain already exists when Docker starts (from host-level iptables configuration), "it is not inserted at the top of the FORWARD chain like it normally is, rendering it useless." Firewall rules in DOCKER-USER are never evaluated. This is a confirmed bug in Docker 27.3+.

**Why it happens:**
Docker's initialization assumes DOCKER-USER doesn't exist and creates it with specific positioning. If chain pre-exists, Docker skips initialization but doesn't verify chain position. Host-level firewall tools or previous Docker installations can leave DOCKER-USER chain orphaned.

**How to avoid:**
- During addon installation, check if DOCKER-USER exists on host and warn user
- Provide cleanup script to remove orphaned DOCKER-USER chain if needed
- Test chain position: `iptables -L FORWARD -n | grep -A 1 DOCKER-USER` should appear early
- Document that addon requires Docker daemon restart if DOCKER-USER exists before installation
- Consider using unique chain name (DDEV-CLAUDE-USER) as workaround, jumping to it from DOCKER-USER
- Test on clean Docker installation and on systems with existing firewall rules

**Warning signs:**
- Rules added to DOCKER-USER but packet counters stay at zero
- `iptables -L FORWARD` shows DOCKER-USER positioned after DOCKER chain
- Firewall worked on some systems but not others with identical configuration
- Host has complex iptables rules or multiple Docker-related tools installed

**Phase to address:**
Phase 1 (Firewall Foundation) — Must detect and document this issue before users encounter silent failures.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Using shell form in ENTRYPOINT instead of exec form | Simpler syntax, easier to write multi-command scripts | Signal handling breaks, container doesn't shut down cleanly, zombie processes accumulate | Never — exec form is mandatory for production containers |
| Skipping healthcheck implementation | Faster initial development, one less thing to maintain | Race conditions on startup, unpredictable behavior, difficult debugging | Never for production addon, maybe acceptable for personal testing |
| Hardcoding DNS servers (8.8.8.8) instead of using Docker's embedded DNS | Works immediately, no configuration needed | Breaks in air-gapped networks, ignores /etc/resolv.conf, doesn't resolve container names | Only if explicitly documenting requirement for internet access |
| Using `iptables-save` / `iptables-restore` for persistence | Standard approach on bare metal, familiar to sysadmins | Conflicts with Docker's dynamic rules, causes networking failures on restart | Never in containerized environments with Docker |
| Applying all firewall rules in single batch | Simpler logic, fewer steps | Failure in middle leaves firewall in inconsistent state, harder to debug which rule failed | Acceptable if comprehensive error handling exists |
| Using `privileged: true` instead of specific capabilities | Guaranteed to work, no capability research needed | Massive security hole, grants unnecessary permissions, fails security audits | Never — defeats container security model |

## Integration Gotchas

Common mistakes when connecting to external services.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| DDEV's Docker network | Assuming containers can reach host on `localhost` | Use `host.docker.internal` or DDEV's gateway IP; Docker network isolates containers |
| DNS resolution | Using host's /etc/hosts for domain resolution | DNS queries only — Docker doesn't mount /etc/hosts, use Docker's embedded DNS at 127.0.0.11 |
| Docker Compose profiles | Not testing addon with profiles disabled | Use `x-ddev.profile` for optional features, test with profile both enabled and disabled |
| DDEV restart vs. start | Assuming containers keep state between restarts | Container filesystem is ephemeral; persist data in volumes or regenerate on startup |
| Testing with ddev-router | Not accounting for Traefik's own healthcheck and iptables rules | ddev-router (Traefik) has its own networking requirements; firewall rules must not block Traefik health checks |
| Multiple DDEV projects | Assuming addon runs in isolation | Multiple projects share Docker daemon and iptables; use project-specific ipset names to avoid conflicts |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Resolving hundreds of CDN IPs individually | Slow container startup (30+ seconds), DNS timeout errors | Use CIDR ranges from CDN providers, or allow entire ASN ranges, or use category-based allowlisting | When whitelisting >20 domains with >10 IPs each |
| No DNS caching during domain resolution | Repeated DNS queries for same domain, rate limiting from DNS server | Implement local DNS cache, respect TTL, batch resolutions with delay between queries | Refreshing >50 domains every minute |
| Using `--ctorigdst` for every packet | High CPU usage in iptables, packet loss under load | Only use conntrack when necessary, optimize rule order to match most common traffic first | >1000 packets/second through firewall |
| Linear search through ipset with `hash:ip` type | Slow iptables processing as set grows, increased latency | Use appropriate ipset type (hash:net for CIDR ranges), monitor ipset size | ipset exceeding 10,000 entries |
| Synchronous DNS resolution during startup | Container startup blocks for minutes if DNS slow | Parallel resolution with timeout, fail open rather than blocking forever | Whitelisting >100 domains on startup |
| Logging every iptables rule match | Disk space exhaustion, log file growth, I/O bottleneck | Log only drops/rejects, sample accepted traffic, use log levels appropriately | Production traffic >100 requests/second |

## Security Mistakes

Domain-specific security issues beyond general web security.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Firewall fails open (allows all traffic when rules fail to apply) | Sandbox bypass — Claude Code could access any network resource | Implement fail-closed default: DROP all traffic first, then add allow rules; healthcheck must verify restrictive state |
| Whitelisting wildcard domains without subdomain validation | Attacker registers whitelisted subdomain (e.g., attacker.github.io), bypasses firewall | Only whitelist specific subdomains, use exact matching, document wildcard risks, consider using public suffix list |
| Not validating DNS responses before adding to ipset | DNS spoofing/cache poisoning adds attacker IPs to allowlist | Use DNSSEC validation, verify responses against multiple nameservers, log suspicious IP changes |
| Allowing DNS traffic to all destinations | Container can query malicious DNS servers for data exfiltration | Restrict DNS traffic to Docker's embedded DNS (127.0.0.11) only, block outbound UDP/TCP 53 |
| Firewall rules applied after services start | Window of vulnerability where container has unrestricted network access | Apply firewall rules in ENTRYPOINT before starting main process, verify rules before exec |
| Not monitoring firewall rule changes | Unauthorized modifications go undetected, debugging is impossible | Log rule additions/deletions, checksum iptables state, alert on unexpected changes |
| Granting NET_ADMIN without network namespace isolation | Container can modify host networking, affecting other containers/host | Accept the risk with documentation, or use network namespaces, monitor for privilege escalation |
| Trusting ipset contents without validation | Stale/incorrect IPs persist, bypassing intended restrictions | Regenerate ipsets from authoritative source on startup, validate before loading |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Silent firewall failures (rules don't apply but no error shown) | User assumes sandbox works but Claude Code has unrestricted access, false sense of security | Fail loudly with clear error messages, healthcheck must validate rule application, require explicit confirmation |
| No visibility into what's blocked/allowed | User can't debug why legitimate requests fail, can't verify sandbox is working | Provide `ddev claude firewall status` command showing active rules, recent blocks, ipset contents |
| Requiring manual container restart after whitelist changes | Disrupts workflow, loses container state, requires re-running setup commands | Hot-reload whitelist changes, provide `ddev claude whitelist-add <domain>` command that updates running container |
| Cryptic iptables error messages shown to user | User sees "iptables v1.8.7 (legacy): can't initialize iptables table" without context | Translate iptables errors to user-friendly messages, provide troubleshooting steps in error output |
| Firewall blocks DDEV's own internal communication | `ddev exec` fails, database connections break, site doesn't load | Auto-detect and whitelist DDEV's internal services (ddev-router, ddev-ssh-agent), test against standard DDEV services |
| No indication of startup progress | User waits 30+ seconds during `ddev start` wondering if it's frozen | Show progress messages: "Resolving whitelisted domains (1/25)", "Applying firewall rules", "Verifying sandbox" |
| Firewall configuration in unfamiliar location | User can't find config, edits wrong file, confusion about precedence | Use standard DDEV config location (.ddev/ddev-claude/config.yaml), document clearly in `ddev describe` |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Firewall rules working:** Often missing idempotent application — verify rules persist across `ddev restart`, not just `ddev start`
- [ ] **Domain whitelisting functional:** Often missing IP refresh mechanism — verify IPs update when external service changes addresses
- [ ] **Healthcheck passing:** Often just checks process existence, not actual functionality — verify healthcheck tests iptables rules are loaded and ipsets populated
- [ ] **Addon installation successful:** Often missing dependency validation — verify addon works on fresh DDEV install without additional tools
- [ ] **Container starts without errors:** Often missing signal handling — verify container shuts down cleanly with Ctrl+C, no zombie processes
- [ ] **iptables rules applied:** Often in wrong chain (FORWARD instead of DOCKER-USER) — verify with packet counters showing actual matches
- [ ] **Documentation complete:** Often missing troubleshooting section — verify includes common errors, debugging commands, logging locations
- [ ] **Tests passing:** Often only happy path tested — verify tests include rule persistence, DNS failures, IP changes, concurrent access
- [ ] **ENTRYPOINT script working:** Often uses shell form instead of exec form — verify signals propagate correctly, startup failures exit non-zero
- [ ] **Removal working:** Often leaves orphaned rules/chains — verify `ddev delete` removes all iptables rules, ipsets, and generated files

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Rules in wrong chain | LOW | 1. Flush FORWARD chain custom rules 2. Re-apply to DOCKER-USER 3. Test with packet counters 4. Update documentation |
| Rules don't persist | LOW | 1. Move rule application to ENTRYPOINT 2. Make idempotent (test before add) 3. Add logging 4. Test restart |
| DNS before firewall | MEDIUM | 1. Add healthcheck to DNS-dependent services 2. Use `depends_on: service_healthy` 3. Implement retry logic 4. Whitelist DNS traffic early |
| Stale IPs in ipset | LOW | 1. Implement refresh cron job 2. Parse DNS TTL 3. Flush and repopulate 4. Log IP changes |
| Missing namespace | HIGH | 1. Create namespaced directories 2. Move all files 3. Update paths in scripts 4. Require reinstall for existing users 5. Document migration |
| No healthcheck | MEDIUM | 1. Write healthcheck script 2. Test actual functionality (not just process) 3. Add to docker-compose 4. Update depends_on |
| DNAT IP confusion | LOW | Not applicable for outbound filtering; document for future reference |
| Missing NET_ADMIN | LOW | 1. Add cap_add to docker-compose.yaml 2. Test capability 3. Document security implications |
| Wrong DDEV version | LOW | 1. Add ddev_version_constraint to install.yaml 2. Test error message 3. Document minimum version |
| DOCKER-USER position | MEDIUM | 1. Detect chain exists 2. Warn user 3. Provide cleanup script 4. Document Docker restart requirement |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Rules in wrong chain | Phase 1: Firewall Foundation | `iptables -L DOCKER-USER -v` shows packet matches on test traffic |
| Rules don't persist | Phase 1: Firewall Foundation | `ddev restart && ddev exec iptables -L DOCKER-USER` shows rules present |
| DNS before firewall | Phase 2: DNS Integration | `ddev start` logs show DNS resolution completes before rule application |
| Stale IPs in ipset | Phase 3: Dynamic IP Updates | Change external service IP, wait refresh interval, verify ipset updates |
| Missing namespace | Phase 0: Addon Skeleton | `ls .ddev/ddev-claude/` shows namespaced directory structure |
| No healthcheck | Phase 1: Firewall Foundation | `docker ps` shows "healthy" status, not just "running" |
| DNAT IP confusion | Documentation only | Not applicable for current architecture |
| Missing NET_ADMIN | Phase 0: Addon Skeleton | `ddev exec iptables -L` works without permission errors |
| Wrong DDEV version | Phase 0: Addon Skeleton | Installing on old DDEV version shows clear error message |
| DOCKER-USER position | Phase 1: Firewall Foundation | Installation script checks chain position, warns if incorrect |

## Sources

### DDEV Addon Development
- [Creating DDEV Add-ons - DDEV Docs](https://docs.ddev.com/en/stable/users/extend/creating-add-ons/)
- [DDEV Add-on Maintenance Guide](https://ddev.com/blog/ddev-add-on-maintenance-guide/)
- [Custom Docker Compose Services - DDEV Docs](https://docs.ddev.com/en/stable/users/extend/custom-docker-services/)
- [DDEV and Docker Healthchecks](https://ddev.com/blog/ddev-and-docker-healthchecks-technote/)
- [Creating a DDEV Addon - Medium](https://medium.com/@alexfinnarn/creating-a-ddev-addon-c443ac8a1357)

### Docker and iptables
- [Docker with iptables - Docker Docs](https://docs.docker.com/engine/network/firewall-iptables/)
- [Packet filtering and firewalls - Docker Docs](https://docs.docker.com/engine/network/packet-filtering-firewalls/)
- [iptables inside container - Docker Forums](https://forums.docker.com/t/iptables-inside-container-doesnt-work-net-admin-also-didnt-help/71270)
- [DOCKER-USER chain bug - GitHub Issue #48560](https://github.com/moby/moby/issues/48560)
- [Docker networking fails after iptables restart - GitHub Issue #12294](https://github.com/moby/moby/issues/12294)

### DNS and Container Networking
- [How to Debug Docker DNS Issues](https://oneuptime.com/blog/post/2026-01-06-docker-dns-troubleshooting/view)
- [Solving DNS Resolution Issues Inside Docker Containers](https://www.magetop.com/blog/solving-dns-resolution-issues-inside-docker-containers/)
- [Docker Compose healthcheck and depends_on](https://www.denhox.com/posts/forget-wait-for-it-use-docker-compose-healthcheck-and-depends-on-instead/)
- [Control startup order - Docker Docs](https://docs.docker.com/compose/how-tos/startup-order/)

### ipset and Firewall Management
- [Limit Docker Container Access with ipset](https://www.putorius.net/limit-docker-container-access-to-certain-ip-addresses.html)
- [Create iptables Rules Based on Hostname Using IPSet](https://www.putorius.net/ipset-iptables-rules-for-hostname.html)
- [Advanced Firewall Configurations with ipset - Linux Journal](https://www.linuxjournal.com/content/advanced-firewall-configurations-ipset)

### Container Best Practices
- [Docker ENTRYPOINT vs CMD](https://oneuptime.com/blog/post/2026-01-16-docker-entrypoint-vs-cmd/view)
- [Docker Best Practices: RUN, CMD, and ENTRYPOINT](https://www.docker.com/blog/docker-best-practices-choosing-between-run-cmd-and-entrypoint/)
- [Understanding Docker's CMD and ENTRYPOINT](https://www.cloudbees.com/blog/understanding-dockers-cmd-and-entrypoint-instructions)

### iptables Persistence
- [Make iptables Rules Persistent](https://linuxconfig.org/how-to-make-iptables-rules-persistent-after-reboot-on-linux)
- [iptables-persistent and Docker conflicts - Docker Forums](https://forums.docker.com/t/iptables-persistent-on-ubuntu-14-04-messes-up-docker-iptables-rules/35890)
- [Managing iptables as a Service with Docker](https://hugotkk.github.io/posts/managing-iptables-as-a-service-and-integrating-with-docker/)

---
*Pitfalls research for: DDEV addon with iptables firewall (ddev-claude)*
*Researched: 2026-01-24*
*Confidence: HIGH - Research based on official Docker/DDEV documentation, verified with recent 2026 sources and community issue tracking*
