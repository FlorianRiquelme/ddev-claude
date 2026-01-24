# Project Research Summary

**Project:** ddev-claude
**Domain:** DDEV addon with network firewall for AI code assistant sandboxing
**Researched:** 2026-01-24
**Confidence:** HIGH

## Executive Summary

ddev-claude is a DDEV addon that implements network sandboxing for Claude Code running in DDEV containerized development environments. The product addresses a critical security gap: Claude Code's sandboxing relies on OS-level primitives that don't translate to Docker containers, leaving DDEV users without network isolation. This addon extends the DDEV web container with iptables-based firewall using Docker's DOCKER-USER chain for packet filtering, ipset for efficient IP whitelisting, and Docker capabilities (NET_ADMIN) for privileged network operations.

The recommended approach is container modification (not a separate service container) because Claude CLI runs in DDEV's web container and needs web container context. Use Dockerfile extensions for build-time iptables/ipset installation, docker-compose overrides for NET_ADMIN capability grants, and ENTRYPOINT-based initialization for persistent rule application. The architecture follows DDEV addon patterns: install.yaml for lifecycle orchestration, commands/web/ for user CLI, and namespace isolation (.ddev/ddev-claude/) to avoid conflicts with other addons.

Key risks center on Docker networking complexity: iptables rules must use DOCKER-USER chain (not FORWARD), DNS resolution must complete before firewall applies, dynamic IPs require refresh mechanisms, and rule persistence needs idempotent startup scripts. The technology stack is mature (iptables-nft in Debian 12, DDEV v1.24.10+, bats for testing), but integration points have sharp edges documented in official Docker firewall guides and confirmed by community reports. Mitigation involves strict adherence to Docker networking best practices, comprehensive healthchecks, and defense-in-depth through fail-closed defaults.

## Key Findings

### Recommended Stack

The stack is tightly constrained by DDEV's architecture and Docker networking requirements. All core technologies are mature and well-documented, giving HIGH confidence in implementation feasibility.

**Core technologies:**
- **DDEV v1.24.10+**: Container orchestration platform — Required base for addon ecosystem with modern docker-compose profile support
- **iptables-nft 1.8.9**: Packet filtering inside web container — Default in Debian 12 (DDEV base), uses nftables backend with iptables syntax compatibility
- **ipset 7.x**: IP whitelist management — Efficient storage for iptables rules, avoids rule explosion with hundreds of whitelisted IPs
- **Docker Compose v2**: Service definition and orchestration — DDEV manages lifecycle, addon uses docker-compose.<service>.yaml pattern
- **Bash 5.x with shellcheck**: Scripting for install/commands — Standard for DDEV addons, must follow strict error handling (set -euo pipefail)
- **bats-core**: Bash testing framework — Standard testing framework for DDEV addon CI/CD

**Critical versions:**
- DDEV v1.24.10+ for x-ddev.describe-* extensions and Docker Engine v28.5.2+ compatibility
- iptables-nft (not iptables-legacy) for Debian 12 Bookworm compatibility
- Avoid privileged mode, use specific capabilities (NET_ADMIN, NET_RAW)

**What NOT to use:**
- iptables-legacy (deprecated in Debian 12, incompatible with iptables-nft rules)
- iptables-persistent (conflicts with Docker's dynamic networking)
- Pure nftables syntax (less familiar, DDEV ecosystem expects iptables commands)

### Expected Features

Feature landscape research distinguishes table stakes (users expect these), differentiators (competitive advantage), and anti-features (commonly requested but problematic).

**Must have (table stakes):**
- Network firewall with domain allowlisting — Core security boundary, prevents data exfiltration
- Basic allow/deny configuration — DDEV standard pattern using YAML config files
- Installation/removal idempotency — DDEV addon standard with #ddev-generated stanzas
- Per-project configuration — DDEV pattern for project-specific overrides
- Error messaging when sandbox blocks — Users need immediate feedback on blocked requests

**Should have (competitive differentiators):**
- Interactive blocked domain review — Allow runtime approval decisions (deny/allow-once/allow-permanently), reduces approval fatigue
- Mount awareness warnings — Alerts when DDEV mounts expose sensitive directories (SSH keys, credentials)
- Domain allowlist templates — Pre-configured allowlists for common stacks (Laravel, npm, etc.)
- Per-project + global config with precedence — Enterprise policy enforcement

**Defer (v2+):**
- Claude config validation warnings — Detects misconfigured Claude sandbox settings
- Violation audit log — Persistent log for security review
- SIEM integration — Enterprise compliance features
- Advanced traffic analysis — Protocol-specific filtering

**Anti-features (do NOT implement):**
- "Learning mode" auto-approval — Creates false security, defeats sandboxing purpose
- Block-by-default filesystem isolation — DDEV architecture conflicts, use mount warnings instead
- Real-time traffic inspection/logging — SSL/TLS makes impossible without MITM
- GUI configuration interface — DDEV is CLI-first, config files are the pattern

### Architecture Approach

DDEV addon architecture uses four components working together: install.yaml (lifecycle orchestration), Dockerfile extensions (build-time customization), docker-compose overrides (runtime capabilities), and custom commands (user interface). Execution flow: install.yaml runs pre/post hooks → Dockerfile builds image with iptables → docker-compose grants NET_ADMIN capability → ENTRYPOINT applies firewall rules → commands provide user CLI.

**Major components:**
1. **install.yaml manifest** — Orchestrates installation lifecycle, validates DDEV version constraints (>= v1.24.10), runs pre/post actions for setup
2. **web-build/Dockerfile.ddev-claude** — Extends DDEV web container image at build time, installs iptables/ipset packages via apt-get
3. **docker-compose.ddev-claude.yaml** — Grants NET_ADMIN capability to web container, adds environment variables for firewall config
4. **commands/web/** — Custom CLI commands (claude-sandbox-init, claude-sandbox-status) providing user interface to firewall management
5. **Namespaced directory structure** — .ddev/ddev-claude/ for scripts/config to avoid conflicts with other addons

**Critical architectural patterns:**
- Use DOCKER-USER chain (not FORWARD) for iptables rules to process before Docker's built-in filtering
- Apply firewall rules in ENTRYPOINT on every container start for persistence
- Implement healthcheck testing actual functionality (iptables rules loaded, ipsets populated)
- DNS allowlisting must happen before restrictive rules to avoid bootstrap deadlock

**Build order dependencies:**
- Phase 1: install.yaml + docker-compose.yaml (capability) → foundation
- Phase 2: Dockerfile (iptables installation) → depends on Phase 1 capability
- Phase 3: ENTRYPOINT scripts + commands → depends on Phase 2 tools
- Phase 4: Configuration + testing → depends on Phase 3 interface

### Critical Pitfalls

Top 5 pitfalls ranked by severity and likelihood, extracted from detailed research covering 10 documented failure modes.

1. **iptables Rules in Wrong Chain** — Rules added to FORWARD chain execute AFTER Docker's filtering, making them ineffective. Always use DOCKER-USER chain which processes before DOCKER-FORWARD. Verify with packet counters showing actual matches.

2. **Rules Don't Persist Across Container Restarts** — iptables rules exist in kernel memory, not container filesystem. Apply rules in ENTRYPOINT on every container start with idempotent logic. Never rely on iptables-persistent (conflicts with Docker networking).

3. **DNS Resolution Before Firewall Applies** — Startup race conditions cause firewall to initialize before DNS available, resulting in empty ipsets. Use healthcheck dependencies, retry logic with exponential backoff, and whitelist DNS traffic (UDP/TCP 53) before restrictive rules.

4. **ipset Can't Track Dynamic IPs** — Domain resolution happens once but CDNs/cloud providers rotate IPs regularly. Implement periodic DNS re-resolution with TTL awareness, flush and repopulate ipsets rather than diffing.

5. **Missing NET_ADMIN Capability** — Container fails to apply iptables rules with "Permission denied" even as root. Docker requires explicit capability grants. Add `cap_add: [NET_ADMIN, NET_RAW]` to docker-compose.yaml, never use `privileged: true` as workaround.

**Additional pitfalls requiring attention:**
- DDEV addon files not namespaced (use .ddev/ddev-claude/ directory structure)
- Missing healthchecks cause startup race conditions (test actual functionality, not just process existence)
- DOCKER-USER chain positioning bug in Docker 27.3+ if chain pre-exists (detect and warn during installation)

## Implications for Roadmap

Based on research, the roadmap should follow dependency-driven architecture with four phases. Technology stack is mature, so phases focus on integration complexity rather than technology uncertainty.

### Phase 1: Firewall Foundation
**Rationale:** DOCKER-USER chain architecture and NET_ADMIN capability must be correct from the start. Refactoring firewall rule chain placement is error-prone and requires complete rebuild. This phase establishes the security boundary — without it, there's no product.

**Delivers:**
- DDEV addon skeleton (install.yaml, README, docker-compose with NET_ADMIN)
- Dockerfile extension installing iptables-nft and ipset
- ENTRYPOINT script applying basic firewall rules to DOCKER-USER chain
- Healthcheck verifying rules loaded and functional
- Basic bats tests for install/uninstall idempotency

**Addresses features:**
- Network firewall with domain allowlisting (table stakes)
- Installation/removal idempotency (table stakes)

**Avoids pitfalls:**
- Rules in wrong chain (use DOCKER-USER from start)
- Rules don't persist (ENTRYPOINT-based application)
- Missing NET_ADMIN capability (docker-compose configuration)
- Addon files not namespaced (.ddev/ddev-claude/ structure)
- Missing healthcheck (implemented in docker-compose)

**Research flag:** Skip phase research — DDEV addon patterns are well-documented in official docs and template repository. Stack research already covers iptables/Docker integration.

### Phase 2: Domain Configuration & User Interface
**Rationale:** Once firewall foundation works, users need configuration mechanism and CLI interface. Configuration format determines user experience and drives all later feature development. Getting YAML structure right early avoids breaking changes.

**Delivers:**
- YAML configuration format (.ddev/ddev-claude/config.yaml) for domain allowlists
- DNS resolution logic converting domains to IPs for ipset population
- Custom commands (ddev claude-sandbox-init, ddev claude-sandbox-status)
- Per-project configuration loading with environment variable support
- Documentation and error messaging for blocked requests

**Addresses features:**
- Basic allow/deny configuration (table stakes)
- Per-project configuration (table stakes)
- Error messaging when sandbox blocks (table stakes)

**Avoids pitfalls:**
- DNS resolution before firewall applies (whitelist DNS first, implement retry logic)
- Stale IPs in ipset (initial resolution mechanism, sets up for Phase 3 refresh)

**Uses stack:**
- Bash scripting with set -euo pipefail for error handling
- DDEV custom commands pattern (commands/web/ directory)
- YAML for configuration (DDEV ecosystem standard)

**Research flag:** Skip phase research — YAML parsing and DNS resolution are standard patterns. Domain allowlist configuration follows established DDEV addon conventions.

### Phase 3: Dynamic IP Refresh & Persistence
**Rationale:** Domain-based whitelisting requires IP refresh mechanism because CDNs and cloud providers rotate addresses. This phase makes the firewall production-ready by handling IP changes gracefully. Depends on Phase 2's DNS resolution logic.

**Delivers:**
- Periodic DNS re-resolution with TTL awareness
- ipset flush and repopulate mechanism
- IP change logging for debugging
- Startup optimization (parallel DNS resolution)
- Graceful handling of DNS failures

**Addresses features:**
- Network firewall reliability (table stakes completion)

**Avoids pitfalls:**
- ipset can't track dynamic IPs (periodic refresh with TTL parsing)
- DNS resolution failures (retry logic, fallback behavior)

**Implements architecture:**
- Data flow pattern for DNS → ipset → iptables updates
- Cron-like scheduling inside container

**Research flag:** Skip phase research — DNS TTL and ipset management are well-documented. Implementation pattern clear from Stack and Architecture research.

### Phase 4: Interactive Review & Mount Awareness
**Rationale:** Differentiating features that improve UX and address DDEV-specific security concerns. Interactive review reduces configuration burden (approve at runtime vs. pre-configuration). Mount awareness is unique to DDEV context. Both enhance security without blocking core functionality.

**Delivers:**
- Interactive blocked domain review with deny/allow-once/allow-permanently options
- Mount awareness scanning .ddev/config.yaml for risky patterns (SSH keys, credentials)
- Notifications for blocked requests
- Violation audit log (optional, low complexity)

**Addresses features:**
- Interactive blocked domain review (differentiator)
- Mount awareness warnings (differentiator)
- Violation audit log (should-have)

**Implements architecture:**
- User prompt mechanism (likely DDEV hooks or notification system)
- DDEV config parser for mount scanning

**Research flag:** Needs phase research — Interactive review UX pattern unclear, requires researching DDEV hook mechanism and notification options. Mount awareness requires parsing DDEV's config.yaml format and defining security heuristics.

### Phase Ordering Rationale

- **Phases 1-3 are sequential dependencies:** Can't configure domains without firewall, can't refresh IPs without domain resolution
- **Phase 4 is parallel-capable:** Interactive review and mount awareness are independent features, could be developed simultaneously
- **Phase 1 is architectural foundation:** DOCKER-USER chain and NET_ADMIN decisions can't be changed later without breaking installations
- **Phases 2-3 complete table stakes:** After Phase 3, product is viable for security-conscious users
- **Phase 4 adds competitive differentiators:** UX improvements and DDEV-specific value

### Research Flags

**Needs deeper research:**
- **Phase 4 (Interactive Review):** User prompt mechanism unclear. Need to research DDEV hooks, notification systems, or lightweight web UI options. How to pause container execution for approval? Can DDEV commands trigger host-side notifications?

**Standard patterns (skip research):**
- **Phase 1 (Firewall Foundation):** DDEV addon template provides structure, Docker/iptables documentation comprehensive
- **Phase 2 (Configuration):** YAML parsing and DNS resolution well-documented
- **Phase 3 (IP Refresh):** Standard cron/scheduling patterns, DNS TTL parsing documented

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Official DDEV docs, Docker iptables guides, Debian package documentation. All technologies mature and battle-tested |
| Features | MEDIUM | Feature classification based on Claude Code documentation and AI sandboxing best practices. Anti-features identified from security research. MVP definition solid but differentiator priority could shift based on user feedback |
| Architecture | HIGH | DDEV addon structure from official template, iptables/Docker integration from official Docker networking docs. Component boundaries clear, build order validated against dependency graph |
| Pitfalls | HIGH | Sourced from official Docker docs, GitHub issues, and confirmed community reports. All 10 documented pitfalls have authoritative sources or reproductions. Prevention strategies validated against Docker best practices |

**Overall confidence:** HIGH

Research based on official documentation (DDEV, Docker, Debian), verified with 2026-dated sources, and cross-referenced with GitHub issues and community reports. Technology stack is mature. Main uncertainty is in Phase 4 interactive review UX pattern.

### Gaps to Address

**Interactive review mechanism (Phase 4):**
- Research needed on DDEV hook capabilities for pausing execution
- Notification system unclear (CLI prompts vs. desktop notifications vs. web UI)
- Decision: Research during Phase 4 planning, not before. Phase 1-3 deliverables don't depend on this

**Dynamic IP refresh interval tuning:**
- TTL-based scheduling documented but optimal refresh frequency unclear
- CDN IP change patterns vary by provider
- Decision: Start with conservative defaults (hourly refresh), monitor and adjust based on logs

**Mount awareness heuristics:**
- Which mount patterns constitute security risks needs refinement
- Balance between helpful warnings and alert fatigue
- Decision: Start with obvious patterns (SSH keys, .aws/, .env), iterate based on user feedback

**Performance at scale:**
- Unknown how many domains/IPs system handles before performance degrades
- ipset efficiency validated up to 10,000 entries but real-world usage patterns unclear
- Decision: Implement basic monitoring/logging in Phase 3, optimize in Phase 4+ if needed

## Sources

### Primary (HIGH confidence)
- [DDEV Creating Add-ons](https://docs.ddev.com/en/stable/users/extend/creating-add-ons/) — Addon structure, install.yaml lifecycle
- [DDEV Customizing Images](https://docs.ddev.com/en/stable/users/extend/customizing-images/) — Dockerfile extensions, build variables
- [Docker Firewall iptables](https://docs.docker.com/engine/network/firewall-iptables/) — DOCKER-USER chain, packet filtering
- [Docker Packet Filtering](https://docs.docker.com/engine/network/packet-filtering-firewalls/) — Networking security, capabilities
- [DDEV Addon Template](https://github.com/ddev/ddev-addon-template) — Official template repository
- [Debian nftables Wiki](https://wiki.debian.org/nftables) — iptables-nft backend information
- [Claude Code Sandboxing](https://code.claude.com/docs/en/sandboxing) — Sandbox architecture patterns

### Secondary (MEDIUM confidence)
- [DDEV Add-on Maintenance Guide](https://ddev.com/blog/ddev-add-on-maintenance-guide/) — Best practices (Nov 2025)
- [Docker Engine v28 Security](https://www.docker.com/blog/docker-engine-28-hardening-container-networking-by-default/) — Container networking hardening (Feb 2025)
- [Anthropic Engineering: Claude Code Sandboxing](https://www.anthropic.com/engineering/claude-code-sandboxing) — Design rationale
- [OpenSSF Security Guide for AI Assistants](https://best.openssf.org/Security-Focused-Guide-for-AI-Code-Assistant-Instructions) — Best practices
- [Medium: Simple Secure Docker with ipset](https://medium.com/@udomsak/simple-secure-you-staging-docker-environment-with-ipset-and-iptables-aafb679f9a7a) — Firewall patterns

### Tertiary (LOW confidence, needs validation)
- Community forum discussions on DOCKER-USER chain positioning bug (GitHub issue #48560)
- Blog posts on iptables-persistent and Docker conflicts (requires testing in DDEV context)
- ipset persistence patterns (standard on bare metal, needs validation in containerized environment)

---
*Research completed: 2026-01-24*
*Ready for roadmap: yes*
