# Roadmap: ddev-claude

## Overview

This roadmap delivers a DDEV addon that sandboxes Claude Code with network firewall protection. Phase 1 establishes the core firewall architecture using iptables and DDEV addon structure. Phase 2 adds configuration management and user commands for domain whitelisting. Phase 3 implements safety warnings and documentation to guide secure usage. Phase 4 makes the firewall production-ready with dynamic IP refresh for CDN compatibility.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [ ] **Phase 1: Firewall Foundation** - Core iptables firewall and DDEV addon skeleton
- [ ] **Phase 2: Configuration & Commands** - Domain whitelist system and user interface
- [ ] **Phase 3: Safety Warnings & Documentation** - Security checks and user guidance
- [ ] **Phase 4: Dynamic IP Refresh** - Production-ready IP management

## Phase Details

### Phase 1: Firewall Foundation
**Goal:** DDEV addon installs with functional network firewall blocking outbound traffic by default
**Depends on:** Nothing (first phase)
**Requirements:** FIRE-01, FIRE-02, FIRE-03, FIRE-04, FIRE-06, DDEV-01, DDEV-02, DDEV-03, DDEV-04, DDEV-05, DDEV-06
**Success Criteria** (what must be TRUE):
  1. DDEV addon can be installed and removed idempotently using `ddev get` and `ddev addon remove`
  2. Web container has iptables-nft and ipset tools available after installation
  3. Outbound network traffic is blocked by default with whitelisted domains allowed through
  4. DNS resolution works before firewall applies (UDP/TCP 53 whitelisted)
  5. Firewall rules persist across container restarts via ENTRYPOINT script
  6. Healthcheck verifies iptables rules are loaded and functional
  7. Blocked requests are logged with domain/IP for debugging
**Plans:** 3 plans

Plans:
- [ ] 01-01-PLAN.md — DDEV addon skeleton with capabilities and Dockerfile
- [ ] 01-02-PLAN.md — Core firewall scripts (entrypoint, domain resolution, whitelist)
- [ ] 01-03-PLAN.md — Healthcheck validation and internal logging

### Phase 2: Configuration & Commands
**Goal:** Users can configure domain whitelists and run Claude CLI through DDEV
**Depends on:** Phase 1
**Requirements:** CONF-01, CONF-02, CONF-03, CONF-04, CONF-05, CONF-06, UI-01, UI-02, UI-03, UI-04, UI-05, SKILL-01, SKILL-02, SKILL-03
**Success Criteria** (what must be TRUE):
  1. Per-project whitelist config exists at `.ddev/ddev-claude/whitelist.txt` and is loaded on startup
  2. Global whitelist config exists at `~/.ddev/ddev-claude/whitelist.txt` and merges with per-project config
  3. Default whitelist includes Claude API, GitHub, Composer, npm registries
  4. Stack templates available for common frameworks (Laravel, npm) to quickly configure whitelists
  5. `ddev claude [args]` command runs Claude CLI inside container with firewall active
  6. `ddev claude --no-firewall` disables firewall but logs all accessed domains
  7. `ddev claude:whitelist` shows domains from last session and allows interactive selection to add to whitelist
  8. Configuration changes reload without container restart (hot reload)
  9. Clear error messages appear when firewall blocks a request
  10. `/whitelist` Claude skill provides firewall awareness and guides users through whitelisting
  11. Claude can edit whitelist.txt directly after asking user for confirmation
  12. Skill triggers hot reload after whitelist changes
**Plans:** TBD

Plans:
- [ ] 02-01: TBD during phase planning

### Phase 3: Safety Warnings & Documentation
**Goal:** Users understand security boundaries and receive warnings for risky configurations
**Depends on:** Phase 2
**Requirements:** SAFE-01, SAFE-02, SAFE-03, SAFE-04, SAFE-05, DDEV-07, DDEV-08
**Success Criteria** (what must be TRUE):
  1. Startup detects additional mounted directories beyond project root and displays warning
  2. User must acknowledge risky mounts with explicit confirmation before proceeding
  3. Startup checks Claude settings for `.env` file deny rules
  4. If `.env` not protected, addon offers to add deny rule to global or project-specific Claude settings
  5. README documentation explains installation, usage, security boundaries, and limitations
  6. Bats test suite validates addon installation, removal, and firewall functionality
  7. Tests run in CI/CD for validation before releases
**Plans:** TBD

Plans:
- [ ] 03-01: TBD during phase planning

### Phase 4: Dynamic IP Refresh
**Goal:** Firewall handles CDN IP rotation gracefully without manual intervention
**Depends on:** Phase 3
**Requirements:** FIRE-05 (enhanced)
**Success Criteria** (what must be TRUE):
  1. Domains are periodically re-resolved to update IP addresses in ipsets
  2. DNS TTL values are parsed and respected for refresh timing
  3. IP changes are logged for debugging and monitoring
  4. DNS resolution happens in parallel for faster startup
  5. DNS resolution failures are handled gracefully with retry logic and fallback behavior
**Plans:** TBD

Plans:
- [ ] 04-01: TBD during phase planning

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Firewall Foundation | 0/3 | Planned | - |
| 2. Configuration & Commands | 0/TBD | Not started | - |
| 3. Safety Warnings & Documentation | 0/TBD | Not started | - |
| 4. Dynamic IP Refresh | 0/TBD | Not started | - |
