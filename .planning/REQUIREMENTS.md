# Requirements: ddev-claude

**Defined:** 2025-01-24
**Core Value:** Enable `--dangerously-skip-permissions` with confidence — Claude works autonomously while network isolation prevents prompt injection attacks.

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Firewall

- [ ] **FIRE-01**: Outbound traffic blocked by default (whitelist approach)
- [ ] **FIRE-02**: Whitelisted domains resolved to IPs and allowed through firewall
- [ ] **FIRE-03**: DNS traffic (UDP/TCP 53) allowed before restrictive rules
- [ ] **FIRE-04**: Firewall rules persist across container restarts (ENTRYPOINT-based)
- [ ] **FIRE-05**: Dynamic IP refresh re-resolves domains periodically (CDN rotation)
- [ ] **FIRE-06**: Blocked requests logged with domain/IP for debugging

### Configuration

- [ ] **CONF-01**: Per-project config at `.ddev/ddev-claude/whitelist.txt`
- [ ] **CONF-02**: Global config at `~/.ddev/ddev-claude/whitelist.txt`
- [ ] **CONF-03**: Per-project overrides global (additive merge)
- [ ] **CONF-04**: Default whitelist includes Claude API, GitHub, Composer, npm
- [ ] **CONF-05**: Hot reload whitelist without container restart
- [ ] **CONF-06**: Stack templates available for common frameworks (Laravel, npm, etc.)

### User Interface

- [ ] **UI-01**: `ddev claude [args]` runs Claude CLI with firewall active
- [ ] **UI-02**: `ddev claude --no-firewall` disables firewall but logs outbound domains
- [ ] **UI-03**: `ddev claude:whitelist` shows domains from last session (blocked or accessed)
- [ ] **UI-04**: Interactive selection in `claude:whitelist` to add domains to whitelist
- [ ] **UI-05**: Clear error messaging when requests are blocked

### Safety

- [ ] **SAFE-01**: Startup detects additional mounted directories beyond project root
- [ ] **SAFE-02**: User must acknowledge risky mounts before proceeding
- [ ] **SAFE-03**: Startup checks Claude settings for `.env` deny rule
- [ ] **SAFE-04**: If `.env` not protected, offer to add it (global or project settings)
- [ ] **SAFE-05**: Recommend global settings but allow project-specific choice

### DDEV Addon

- [ ] **DDEV-01**: install.yaml with DDEV v1.24.10+ version constraint
- [ ] **DDEV-02**: docker-compose grants NET_ADMIN and NET_RAW capabilities
- [ ] **DDEV-03**: Dockerfile extends web container with iptables-nft and ipset
- [ ] **DDEV-04**: User's `~/.claude` config mounted into container
- [ ] **DDEV-05**: Healthcheck validates firewall rules loaded and functional
- [ ] **DDEV-06**: Installation and removal are idempotent
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
| FIRE-01 | TBD | Pending |
| FIRE-02 | TBD | Pending |
| FIRE-03 | TBD | Pending |
| FIRE-04 | TBD | Pending |
| FIRE-05 | TBD | Pending |
| FIRE-06 | TBD | Pending |
| CONF-01 | TBD | Pending |
| CONF-02 | TBD | Pending |
| CONF-03 | TBD | Pending |
| CONF-04 | TBD | Pending |
| CONF-05 | TBD | Pending |
| CONF-06 | TBD | Pending |
| UI-01 | TBD | Pending |
| UI-02 | TBD | Pending |
| UI-03 | TBD | Pending |
| UI-04 | TBD | Pending |
| UI-05 | TBD | Pending |
| SAFE-01 | TBD | Pending |
| SAFE-02 | TBD | Pending |
| SAFE-03 | TBD | Pending |
| SAFE-04 | TBD | Pending |
| SAFE-05 | TBD | Pending |
| DDEV-01 | TBD | Pending |
| DDEV-02 | TBD | Pending |
| DDEV-03 | TBD | Pending |
| DDEV-04 | TBD | Pending |
| DDEV-05 | TBD | Pending |
| DDEV-06 | TBD | Pending |
| DDEV-07 | TBD | Pending |
| DDEV-08 | TBD | Pending |

**Coverage:**
- v1 requirements: 29 total
- Mapped to phases: 0
- Unmapped: 29 ⚠️

---
*Requirements defined: 2025-01-24*
*Last updated: 2025-01-24 after initial definition*
