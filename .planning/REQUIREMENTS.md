# Requirements: ddev-claude

**Defined:** 2025-01-24
**Core Value:** Enable `--dangerously-skip-permissions` with confidence — Claude works autonomously while network isolation prevents prompt injection attacks.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Firewall

- [x] **FIRE-01**: Outbound traffic blocked by default (whitelist approach)
- [x] **FIRE-02**: Whitelisted domains resolved to IPs and allowed through firewall
- [x] **FIRE-03**: DNS traffic (UDP/TCP 53) allowed before restrictive rules
- [x] **FIRE-04**: Firewall rules persist across container restarts (ENTRYPOINT-based)
- [ ] **FIRE-05**: Dynamic IP refresh re-resolves domains periodically (CDN rotation)
- [x] **FIRE-06**: Blocked requests logged with domain/IP for debugging

### Configuration

- [x] **CONF-01**: Per-project config at `.ddev/ddev-claude/whitelist.json`
- [x] **CONF-02**: Global config at `~/.ddev/ddev-claude/whitelist.json`
- [x] **CONF-03**: Per-project overrides global (additive merge)
- [x] **CONF-04**: Default whitelist includes Claude API, GitHub, Composer, npm
- [x] **CONF-05**: Hot reload whitelist without container restart
- [x] **CONF-06**: Stack templates available for common frameworks (Laravel, npm, etc.)

### User Interface

- [x] **UI-01**: `ddev claude [args]` runs Claude CLI with firewall active
- [x] **UI-02**: `ddev claude --no-firewall` disables firewall but logs outbound domains
- [x] **UI-03**: `ddev claude:whitelist` shows domains from last session (blocked or accessed)
- [x] **UI-04**: Interactive selection in `claude:whitelist` to add domains to whitelist
- [x] **UI-05**: Clear error messaging when requests are blocked

### Claude Skill

- [x] **SKILL-01**: `/whitelist` skill provides Claude with firewall awareness and context
- [x] **SKILL-02**: Skill enables Claude to edit whitelist.json directly (asks user first)
- [x] **SKILL-03**: Skill triggers hot reload after whitelist changes

### Safety

- [ ] **SAFE-01**: Startup detects additional mounted directories beyond project root
- [ ] **SAFE-02**: User must acknowledge risky mounts before proceeding
- [ ] **SAFE-03**: Startup checks Claude settings for `.env` deny rule
- [ ] **SAFE-04**: If `.env` not protected, offer to add it (global or project settings)
- [ ] **SAFE-05**: Recommend global settings but allow project-specific choice

### DDEV Addon

- [x] **DDEV-01**: install.yaml with DDEV v1.24.10+ version constraint
- [x] **DDEV-02**: docker-compose grants NET_ADMIN and NET_RAW capabilities
- [x] **DDEV-03**: Dockerfile extends web container with iptables-nft and ipset
- [x] **DDEV-04**: User's `~/.claude` config mounted into container
- [x] **DDEV-05**: Healthcheck validates firewall rules loaded and functional
- [x] **DDEV-06**: Installation and removal are idempotent
- [ ] **DDEV-07**: bats test suite for CI/CD validation
- [ ] **DDEV-08**: README with installation, usage, and security documentation

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Runtime Approval

- **RT-01**: Intercept blocked requests before they fail
- **RT-02**: Prompt user with allow-once / allow-permanently / deny options
- **RT-03**: Allow-once adds to ipset for current session only
- **RT-04**: Allow-permanently updates config file and reloads

### Enhanced Features

- **ENH-01**: Violation audit log (persistent history of blocked requests)
- **ENH-02**: SIEM integration for enterprise compliance
- **ENH-03**: Per-domain TTL configuration for IP refresh

## Out of Scope

Explicitly excluded. Documented to prevent scope creep.

| Feature | Reason |
|---------|--------|
| URL-path level filtering | iptables works at IP/domain level only — would require MITM proxy |
| Real-time desktop notifications | Container-to-host notification is complex, defer to v2 |
| GUI configuration interface | DDEV is CLI-first, config files are the pattern |
| Learning mode auto-approval | Security anti-pattern, defeats sandboxing purpose |
| Filesystem isolation | DDEV mounts entire project, container boundary is sufficient |
| Managing Claude's settings.json | User's config, their responsibility — we warn and offer to help |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FIRE-01 | Phase 1 | Complete |
| FIRE-02 | Phase 1 | Complete |
| FIRE-03 | Phase 1 | Complete |
| FIRE-04 | Phase 1 | Complete |
| FIRE-05 | Phase 4 | Pending |
| FIRE-06 | Phase 1 | Complete |
| CONF-01 | Phase 2 | Complete |
| CONF-02 | Phase 2 | Complete |
| CONF-03 | Phase 2 | Complete |
| CONF-04 | Phase 2 | Complete |
| CONF-05 | Phase 2 | Complete |
| CONF-06 | Phase 2 | Complete |
| UI-01 | Phase 2 | Complete |
| UI-02 | Phase 2 | Complete |
| UI-03 | Phase 2 | Complete |
| UI-04 | Phase 2 | Complete |
| UI-05 | Phase 2 | Complete |
| SKILL-01 | Phase 2 | Complete |
| SKILL-02 | Phase 2 | Complete |
| SKILL-03 | Phase 2 | Complete |
| SAFE-01 | Phase 3 | Pending |
| SAFE-02 | Phase 3 | Pending |
| SAFE-03 | Phase 3 | Pending |
| SAFE-04 | Phase 3 | Pending |
| SAFE-05 | Phase 3 | Pending |
| DDEV-01 | Phase 1 | Complete |
| DDEV-02 | Phase 1 | Complete |
| DDEV-03 | Phase 1 | Complete |
| DDEV-04 | Phase 1 | Complete |
| DDEV-05 | Phase 1 | Complete |
| DDEV-06 | Phase 1 | Complete |
| DDEV-07 | Phase 3 | Pending |
| DDEV-08 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 32 total
- Mapped to phases: 32
- Unmapped: 0 ✓

---
*Requirements defined: 2025-01-24*
*Last updated: 2026-01-24 after Phase 2 completion*
