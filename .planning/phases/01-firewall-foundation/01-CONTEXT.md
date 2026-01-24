# Phase 1: Firewall Foundation - Context

**Gathered:** 2026-01-24
**Status:** Ready for planning

<domain>
## Phase Boundary

DDEV addon installs with functional iptables firewall blocking outbound traffic by default, with whitelisted domains allowed through. Configuration management, user commands, and the Claude CLI wrapper are Phase 2.

</domain>

<decisions>
## Implementation Decisions

### Logging behavior
- Two-tier logging: internal collection (always on) + visible container logs (off by default)
- Internal collection captures blocked domains for Phase 2's whitelist suggestion feature
- Visible logs format when enabled: `[ddev-claude] BLOCKED: api.example.com (93.184.216.34:443)` (domain + IP + port)
- Internal log deduplicates: store unique domains + count (e.g., "api.example.com blocked 47 times")

### Failure modes
- Fail closed: if iptables rules fail to load, block all traffic
- Loud warning when firewall fails to load
- Require CAP_NET_ADMIN capability explicitly — fail fast with clear error if missing
- DNS resolution failures: retry a few times, then warn and continue with other domains

### Initial whitelist
- Functional defaults: Claude API + common dev tools (GitHub, npm, Composer)
- No web search domains by default — user enables if needed (or uses --no-firewall)
- Support wildcards (e.g., *.github.com) for easier CDN/subdomain whitelisting

### Healthcheck design
- Mode-aware: different behavior for firewall-on vs firewall-off
- Firewall on: verify rules exist AND test that blocking works (try blocked domain, confirm failure)
- If healthcheck fails, container shows as unhealthy in `ddev status`

### Claude's Discretion
- Log retention period (current session vs persist across restarts)
- Warning mechanism details (logs, healthcheck, or both)
- Whitelist file organization (flat vs commented sections)
- Test domain for healthcheck blocking verification
- Healthcheck behavior in --no-firewall mode
- Healthcheck frequency/interval

</decisions>

<specifics>
## Specific Ideas

- Internal log collection must work independently from visible logs — Phase 2's `ddev claude:whitelist` needs to show domains from the last session
- `--no-firewall` mode (Phase 2) disables firewall entirely but logs accessed domains for later review and whitelisting

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-firewall-foundation*
*Context gathered: 2026-01-24*
