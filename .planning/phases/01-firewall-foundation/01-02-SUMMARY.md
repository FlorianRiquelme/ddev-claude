---
phase: 01-firewall-foundation
plan: 02
subsystem: infra
tags: [iptables, ipset, dns, firewall, security, docker, ddev]

# Dependency graph
requires:
  - phase: 01-01
    provides: "DDEV addon skeleton with NET_ADMIN capability and Dockerfile structure"
provides:
  - "Firewall entrypoint script with critical rule ordering (loopback → DNS → established → whitelist → DROP)"
  - "Domain resolution helper that resolves whitelisted domains and populates ipset"
  - "Default whitelist with Claude API, GitHub, npm, Composer, and CDN domains"
affects: [01-03-phase1-integration, 02-whitelist-management]

# Tech tracking
tech-stack:
  added: [iptables, ipset, dig]
  patterns:
    - "Fail-closed firewall: default DROP with explicit ALLOW rules"
    - "DNS-before-DROP ordering: DNS resolution works before restrictions apply"
    - "Entrypoint chaining: firewall setup → exec original entrypoint"
    - "Graceful degradation: unresolvable domains logged but don't fail firewall init"

key-files:
  created:
    - .ddev/firewall/entrypoint.sh
    - .ddev/firewall/resolve-and-apply.sh
    - .ddev/firewall/whitelist-domains.txt
  modified: []

key-decisions:
  - "Rule ordering: loopback first (localhost critical), DNS before DROP (avoid self-blocking), established connections allowed (return traffic works)"
  - "ipset timeout 3600s (1 hour): safe default for DNS TTL, auto-refreshes on container restart"
  - "Graceful DNS failures: unresolvable domains logged but don't fail entire firewall (availability over strictness)"
  - "Rate-limited logging: 2/sec with burst 5 prevents log flooding while maintaining visibility"

patterns-established:
  - "Critical rule ordering pattern: setup → loopback → DNS → established → whitelist → log → DROP"
  - "Error trap pattern: fail closed if firewall init fails (container should NOT start)"
  - "Domain resolution pattern: dig +short +time=2 +tries=3 with retry logic"

# Metrics
duration: 1min
completed: 2026-01-24
---

# Phase 01 Plan 02: Core Firewall Logic Summary

**iptables firewall with DNS-safe rule ordering, domain-to-IP resolution via ipset, and functional whitelist for Claude API, GitHub, and package registries**

## Performance

- **Duration:** 1 min
- **Started:** 2026-01-24T05:53:59Z
- **Completed:** 2026-01-24T05:55:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- Firewall entrypoint script with critical rule ordering that avoids self-blocking
- Domain resolution helper that resolves domains via dig and populates ipset
- Default whitelist covering Claude API, GitHub, npm, Composer, and CDNs (12 domains)
- Fail-closed security: default DROP policy with explicit ALLOW rules only

## Task Commits

Each task was committed atomically:

1. **Task 1: Create firewall ENTRYPOINT script** - `8658df8` (feat)
2. **Task 2: Create domain resolution helper script** - `a85b582` (feat)
3. **Task 3: Create default domain whitelist** - `0516ce8` (feat)

## Files Created/Modified

- `.ddev/firewall/entrypoint.sh` - Initializes iptables rules on container start with critical ordering: loopback → DNS → established → whitelist → log → DROP, then chains to DDEV entrypoint
- `.ddev/firewall/resolve-and-apply.sh` - Resolves whitelisted domains via dig and adds IPs to ipset with 1-hour timeout and graceful error handling
- `.ddev/firewall/whitelist-domains.txt` - Default domains for Claude API, GitHub, npm, Composer, and CDNs organized by category

## Decisions Made

**Rule ordering rationale:**
- Loopback FIRST: Localhost communication (PHP-FPM, etc.) must always work
- DNS BEFORE DROP: Domain resolution must work before default DROP policy applies (avoid self-blocking)
- Established connections allowed: Return traffic for initiated connections works
- Whitelist via ipset: O(1) lookup performance for IP matching
- Visible logging rate-limited: 2/sec prevents log flooding while maintaining visibility

**ipset timeout choice:**
- 3600 seconds (1 hour) balances DNS TTL variability with auto-refresh on container restart
- Safe default that handles most CDN/load-balanced scenarios

**Graceful degradation:**
- Unresolvable domains are logged as warnings but don't fail firewall initialization
- Prioritizes availability: firewall still works even if some domains are temporarily unreachable

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all scripts implemented as specified, bash syntax validation passed.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for 01-03 (Phase 1 Integration):**
- All three firewall scripts created and verified
- Scripts pass bash syntax validation
- Critical rule ordering verified (loopback line 27 → DNS line 31 → DROP line 57)
- Default whitelist contains all required domains
- Ready to integrate into Dockerfile and test in live container

**No blockers.**

---
*Phase: 01-firewall-foundation*
*Completed: 2026-01-24*
