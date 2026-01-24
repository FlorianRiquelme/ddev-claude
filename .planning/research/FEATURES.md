# Feature Research

**Domain:** DDEV addon for AI code assistant security sandboxing
**Researched:** 2026-01-24
**Confidence:** MEDIUM

## Feature Landscape

### Table Stakes (Users Expect These)

Features users assume exist. Missing these = product feels incomplete.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Network firewall (whitelist-based) | Core security boundary - prevents data exfiltration, malware downloads. Essential for AI agent sandboxing per Claude Code's own implementation | MEDIUM | DDEV container architecture requires proxy-based approach. Must intercept all outbound traffic including subprocesses |
| Basic configuration management | DDEV addons standard pattern - users expect config.yaml or similar | LOW | DDEV supports both project_files (.ddev) and global_files (~/.ddev) patterns |
| Installation/removal idempotency | DDEV addon standard - all addons must support clean install/uninstall | LOW | Use #ddev-generated stanzas in all created files per DDEV best practices |
| Documentation | All DDEV addons include README with setup/usage | LOW | DDEV community expectation - critical for adoption |
| Error messaging | When sandbox blocks action, user needs to know what happened | LOW | Pattern from Claude Code: immediate notifications when boundaries tested |

### Differentiators (Competitive Advantage)

Features that set the product apart. Not required, but valuable.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Interactive blocked domain review | Unlike static config, allows runtime approval decisions with "deny/allow once/allow permanently" options | MEDIUM | Inspired by Claude Code UX. Reduces approval fatigue while maintaining control. Requires capturing blocked requests and prompting user |
| Mount awareness warnings | Alerts when DDEV mounts expose sensitive directories (SSH keys, credentials) to Claude | MEDIUM | Unique to DDEV context. Addresses filesystem isolation gap. Scan .ddev/config.yaml for risky mount patterns |
| Claude config validation warnings | Detects misconfigured Claude Code settings that create security bypasses (overly broad filesystem access, allowUnixSockets risks) | HIGH | Domain-specific knowledge. Requires parsing Claude's settings.json and applying security heuristics |
| Per-project + global config with precedence | Project-specific rules override global defaults, allowing restrictive global policy with selective project relaxation | MEDIUM | DDEV pattern supported but not commonly used. Enables enterprise policy enforcement |
| Domain allowlist templates | Pre-configured allowlists for common stacks (Laravel needs packagist.org, npm needs registry.npmjs.org, etc) | LOW | Reduces initial configuration burden. Framework detection via DDEV project type |
| Violation audit log | Persistent log of blocked requests for security review | LOW | Security teams need this for compliance. File in .ddev/claude-security/violations.log |

### Anti-Features (Commonly Requested, Often Problematic)

Features that seem good but create problems.

| Feature | Why Requested | Why Problematic | Alternative |
|---------|---------------|-----------------|-------------|
| "Learning mode" that auto-allows | Users want convenience - reduce manual approvals by having system learn and auto-approve | Creates false sense of security. Attackers can train the system by establishing patterns then exploiting. Defeats purpose of sandboxing | Interactive approval with "allow permanently" for user-vetted domains. One-time decision with explicit intent |
| Block-by-default filesystem isolation | Users want to prevent Claude from reading/modifying any files outside project | DDEV mounts entire project into container. Filesystem isolation would require re-architecting DDEV itself or nested containers with performance penalty | Mount awareness warnings + documentation on Claude's native sandbox settings for filesystem control |
| Real-time traffic inspection/logging | Security teams want to see exactly what data is transmitted | SSL/TLS makes this impossible without MITM proxy that breaks certificate validation. Privacy concerns with logging API keys, code snippets | Domain-level allowlisting with violation logs. Trust encryption, focus on preventing connections to unapproved hosts |
| GUI configuration interface | Non-technical users want point-and-click config | DDEV is CLI-first ecosystem. GUI adds maintenance burden, doesn't match user expectations. Config files are the pattern | Well-documented YAML with inline comments, examples, and validation warnings |

## Feature Dependencies

```
Network Firewall (core)
    └──requires──> Domain Allowlist Configuration
                       └──requires──> Config File Management
                       └──enhances──> Domain Allowlist Templates

Interactive Blocked Domain Review
    └──requires──> Network Firewall (core)
    └──requires──> User Prompt Mechanism
    └──enhances──> Violation Audit Log

Mount Awareness Warnings
    └──requires──> DDEV Config Parser
    └──conflicts──> Filesystem Isolation (can't both warn about mounts AND block them)

Claude Config Validation
    └──requires──> Claude Settings Parser
    └──enhances──> Mount Awareness Warnings (both about filesystem security)

Per-project + Global Config
    └──requires──> Config Precedence Logic
    └──enhances──> Domain Allowlist Templates (templates provide global defaults)
```

### Dependency Notes

- **Network Firewall requires Domain Allowlist Configuration:** Can't enforce firewall without knowing which domains are allowed. Allowlist must be configurable via both global and project-level files.
- **Interactive Review requires User Prompt Mechanism:** Need a way to pause Claude's execution, display blocked request details, and capture user decision. May use DDEV hooks or separate daemon process.
- **Mount Awareness conflicts with Filesystem Isolation:** DDEV architecture exposes entire project directory to containers. Can't prevent mounts without breaking DDEV. Instead, warn users and point to Claude's native sandbox for filesystem controls.
- **Claude Config Validation enhances Mount Awareness:** Both address filesystem security. Validation can detect when Claude's sandbox is disabled or misconfigured, making mount warnings more actionable.
- **Templates enhance Domain Allowlists:** Framework-specific templates (detected from DDEV project type) provide smart defaults, reducing manual configuration burden.

## MVP Definition

### Launch With (v1)

Minimum viable product - what's needed to validate the concept.

- [x] Network firewall with domain allowlisting - Core security boundary. Without this, there's no sandbox.
- [x] Basic allow/deny configuration - YAML file in .ddev/claude-security/config.yaml with domain rules.
- [x] Interactive blocked domain review - Key differentiator. Makes sandbox usable without constant config editing.
- [x] Per-project configuration - DDEV standard pattern. Global-only would be insufficient.
- [x] Mount awareness warnings - Low complexity, high value. Addresses DDEV-specific risk.
- [x] Installation via ddev add-on get - Standard DDEV distribution. Must work with existing DDEV projects.

### Add After Validation (v1.x)

Features to add once core is working.

- [ ] Global configuration with precedence - Add after validating per-project works. Enterprise users will request this.
- [ ] Domain allowlist templates - Add after seeing which frameworks users actually use. Framework detection logic needs validation.
- [ ] Claude config validation warnings - Complex feature. Add after core firewall proves valuable. Requires maintaining Claude settings schema.
- [ ] Violation audit log - Security teams will request this. Add when enterprise adoption starts.

### Future Consideration (v2+)

Features to defer until product-market fit is established.

- [ ] Integration with external security tools - SIEM integration, webhook notifications. Wait for enterprise demand signals.
- [ ] Advanced traffic analysis - Protocol-specific allowlisting (git://, ssh://). Complexity doesn't justify value unless users request it.
- [ ] Multi-profile support - Different security levels (development/staging/production). Nice to have but adds UX complexity.
- [ ] Browser extension for configuration - Point-and-click domain management. Wait to see if CLI-first approach is adoption blocker.

## Feature Prioritization Matrix

| Feature | User Value | Implementation Cost | Priority |
|---------|------------|---------------------|----------|
| Network firewall (core) | HIGH | MEDIUM | P1 |
| Domain allowlist config | HIGH | LOW | P1 |
| Interactive domain review | HIGH | MEDIUM | P1 |
| Per-project config | HIGH | LOW | P1 |
| Mount awareness warnings | MEDIUM | MEDIUM | P1 |
| Installation mechanism | HIGH | LOW | P1 |
| Global config precedence | MEDIUM | MEDIUM | P2 |
| Domain templates | MEDIUM | LOW | P2 |
| Claude config validation | MEDIUM | HIGH | P2 |
| Violation audit log | LOW | LOW | P2 |
| SIEM integration | LOW | HIGH | P3 |
| Advanced traffic analysis | LOW | HIGH | P3 |
| Multi-profile support | LOW | MEDIUM | P3 |
| Browser extension | LOW | HIGH | P3 |

**Priority key:**
- P1: Must have for launch - core security functionality and DDEV addon basics
- P2: Should have, add when possible - enhance usability and security but not blocking
- P3: Nice to have, future consideration - enterprise features waiting for demand validation

## Competitor Feature Analysis

| Feature | Claude Code Native Sandbox | Generic AI Sandbox (E2B, Daytona) | ddev-claude Approach |
|---------|----------------------------|----------------------------------|----------------------|
| Network isolation | Proxy-based domain allowlisting with user confirmation | MicroVM isolation (Firecracker) with network namespace | Proxy-based domain allowlisting adapted to DDEV container architecture |
| Filesystem isolation | OS-level primitives (Seatbelt/bubblewrap) with configurable allowed/denied paths | Full VM isolation with dedicated kernel | Mount awareness warnings (can't isolate within DDEV architecture) + point to Claude's native sandbox |
| Configuration scope | Global Claude settings.json with sandbox section | Per-container/workspace config | Per-project (.ddev) + global (~/.ddev) with precedence, matching DDEV patterns |
| User interaction | Permission prompts for new domains with remember option | None - fully automated | Interactive review with deny/allow-once/allow-permanently options |
| Installation | Built into Claude Code desktop app | Requires infrastructure (cloud VMs, Kubernetes) | DDEV addon install - single command, works locally |
| Target use case | General-purpose AI coding assistant sandboxing | Production AI agent deployment at scale | DDEV-specific development environment security |

**Key differentiators:**
- **DDEV-native:** Integrates with existing DDEV projects, no infrastructure required
- **Mount awareness:** Unique insight into DDEV mount security that generic solutions miss
- **Interactive UX:** Balances security with developer productivity better than fully automated approaches
- **Local-first:** Runs on developer machine, no cloud dependencies unlike E2B/Daytona

## Domain-Specific Feature Considerations

### DDEV Ecosystem Patterns

DDEV addons typically provide:
- Service containers (database, cache, mail catchers)
- Development tools (Xdebug, performance profiling)
- External integrations (Playwright, accessibility testing)

**ddev-claude is different:** It's a security boundary, not a service. Implications:
- Won't add a new container (firewall runs as sidecar or host process)
- Won't expose new ports (closes ports instead)
- Won't provide new commands beyond `ddev claude-security` for config management
- Primary interaction is blocking/allowing, not enabling new functionality

### AI Code Assistant Security Requirements

Based on OpenSSF and industry best practices for 2026:
- **Defense in depth:** Network isolation alone insufficient. Needs filesystem awareness, config validation.
- **Least privilege:** Default-deny network policy. Only allow explicitly approved domains.
- **Transparency:** Users must see what's blocked and why. Audit logs for compliance.
- **Escape hatches:** Some tools (Docker, watchman) incompatible with sandboxing. Need exclude mechanism.
- **Human oversight:** Interactive approval prevents automation-induced blindness. User vets every new domain.

### Container Security Considerations

DDEV uses Docker. Container security best practices for 2026:
- **Don't mount Docker socket:** Equivalent to root access. Mount awareness should flag /var/run/docker.sock.
- **Minimize bind mounts:** Each mount is attack surface. Warn when SSH keys, AWS credentials mounted.
- **Use hardened images:** DDEV offers use_hardened_images option. Addon should detect and recommend.
- **No elevated privileges:** Containers shouldn't run privileged. Check DDEV config for privileged: true.

## Feature Rationale

### Why Network Firewall is Table Stakes

Every modern AI sandbox (Claude Code, E2B, Daytona) implements network isolation. Without it:
- Prompt injection can exfiltrate SSH keys, API tokens, proprietary code
- Malicious dependencies can phone home to C2 servers
- AI hallucinations can download malware

Sources: [Claude Code Sandboxing](https://code.claude.com/docs/en/sandboxing), [Northflank Best AI Sandbox](https://northflank.com/blog/best-code-execution-sandbox-for-ai-agents)

### Why Interactive Review is Differentiator

Most sandboxes are either:
1. Fully automated (no user input) - convenient but less secure
2. Fully manual (block everything, configure allowlist before use) - secure but unusable

Interactive review combines security with UX:
- First request to new domain prompts user
- User sees context (what Claude is trying to do)
- User makes informed decision (temporary or permanent allow)
- Future requests to approved domains auto-allowed

This matches Claude Code's own pattern and addresses "approval fatigue" identified by Anthropic research (sandboxing reduced prompts by 84%).

### Why Filesystem Isolation is Anti-Feature

DDEV's architecture fundamentally conflicts with filesystem isolation:
- DDEV mounts entire project directory into web container
- Framework code (Composer, NPM) needs to modify vendor/, node_modules/
- Nested containers (running bubblewrap inside DDEV container) would tank performance
- DDEV hardened images address privileged access, not filesystem boundaries

**Better approach:**
1. Warn about risky mounts (SSH keys, cloud credentials)
2. Point users to Claude Code's native sandbox for filesystem controls
3. Validate Claude sandbox config to ensure it's not disabled

This is honest about DDEV's limitations while still adding security value.

## Technical Implementation Notes

### Network Firewall Architecture Options

**Option 1: Container-based Proxy**
- Add proxy container to docker-compose.yaml
- Route all traffic through proxy via DDEV network config
- Pros: Clean isolation, easy to configure
- Cons: Adds container overhead, complex routing

**Option 2: Host-based Proxy**
- Run proxy on host machine
- Configure DDEV containers to use host proxy
- Pros: No extra container, simpler networking
- Cons: Requires host-level installation, platform-specific

**Option 3: iptables/nftables Rules**
- Inject firewall rules for DDEV containers
- Pros: Native Linux, minimal overhead
- Cons: Platform-specific, requires root, complex rule management

**Recommendation:** Start with Option 2 (host-based proxy) for MVP. Lowest implementation complexity, works across platforms with DDEV's existing architecture.

### Interactive Review Mechanism Options

**Option 1: DDEV Web UI**
- Create simple web interface on localhost:port
- Blocked requests queue in UI for approval
- Pros: Visual, accessible, modern UX
- Cons: Adds web server dependency, assumes browser available

**Option 2: CLI Prompts**
- Block request, notify via terminal
- User runs `ddev claude-security review` to see pending
- Approves via CLI
- Pros: Matches DDEV patterns, no extra dependencies
- Cons: Interrupts workflow, requires context switching

**Option 3: Desktop Notifications**
- OS-level notifications (macOS Notification Center, Linux notify-send)
- Click notification to approve/deny
- Pros: Non-intrusive, modern
- Cons: Platform-specific, notification APIs vary

**Recommendation:** Hybrid approach. Option 1 (web UI) for review queue, Option 3 (notifications) for alerts. Matches Claude Code's pattern and provides best UX.

## Sources

### DDEV Ecosystem Research
- [DDEV Add-on Registry](https://addons.ddev.com/)
- [Creating DDEV Add-ons - Official Docs](https://docs.ddev.com/en/stable/users/extend/creating-add-ons/)
- [Using DDEV Add-ons - Official Docs](https://docs.ddev.com/en/stable/users/extend/using-add-ons/)
- [DDEV Add-on Maintenance Guide](https://ddev.com/blog/ddev-add-on-maintenance-guide/)
- [Advanced Add-On Techniques](https://ddev.com/blog/advanced-add-on-contributor-training/)
- [Diffy: Anatomy of an Advanced DDEV Add-on](https://ddev.com/blog/anatomy-advanced-ddev-addon/)
- [DDEV 2026 Plans](https://ddev.com/blog/2026-plans/)
- [DDEV Enhanced Security with ddev-hostname Binary](https://ddev.com/blog/ddev-hostname-security-improvements/)

### Claude Code Sandboxing Research
- [Claude Code Sandboxing Documentation](https://code.claude.com/docs/en/sandboxing)
- [Anthropic Engineering: Making Claude Code More Secure and Autonomous](https://www.anthropic.com/engineering/claude-code-sandboxing)
- [Anthropic Sandbox Runtime (GitHub)](https://github.com/anthropic-experimental/sandbox-runtime)
- [InfoQ: Anthropic Adds Sandboxing and Web Access to Claude Code](https://www.infoq.com/news/2025/11/anthropic-claude-code-sandbox/)

### AI Code Assistant Security Best Practices
- [OpenSSF Security-Focused Guide for AI Code Assistant Instructions](https://best.openssf.org/Security-Focused-Guide-for-AI-Code-Assistant-Instructions)
- [Knostic: How to Secure AI Coding Assistants](https://www.knostic.ai/blog/ai-coding-assistant-security)
- [Kiuwan: AI Code Security Risks and Best Practices](https://www.kiuwan.com/blog/ai-code-security/)
- [Backslash: Claude Code Security Best Practices](https://www.backslash.security/blog/claude-code-security-best-practices)
- [Medium: How to Use New Claude Code Sandbox Without Security Disasters](https://medium.com/@joe.njenga/how-to-use-new-claude-code-sandbox-to-autonomously-code-without-security-disasters-c6efc5e8e652)
- [Dark Reading: Coders Adopt AI Agents, Security Pitfalls Lurk in 2026](https://www.darkreading.com/application-security/coders-adopt-ai-agents-security-pitfalls-lurk-2026)

### AI Sandbox Platforms
- [Northflank: Best Code Execution Sandbox for AI Agents](https://northflank.com/blog/best-code-execution-sandbox-for-ai-agents)
- [Northflank: Top AI Sandbox Platforms 2026](https://northflank.com/blog/top-ai-sandbox-platforms-for-code-execution)
- [Better Stack: Best Sandbox Runners 2026](https://betterstack.com/community/comparisons/best-sandbox-runners/)
- [KDnuggets: 5 Code Sandboxes for AI Agents](https://www.kdnuggets.com/5-code-sandbox-for-your-ai-agents)

### Container Security
- [Docker Enhanced Container Isolation](https://docs.docker.com/enterprise/security/hardened-desktop/enhanced-container-isolation/)
- [SentinelOne: Container Security Best Practices 2026](https://www.sentinelone.com/cybersecurity-101/cloud-security/container-security-best-practices/)
- [Portainer: Container Security Best Practices for Enterprises 2026](https://www.portainer.io/blog/container-security-best-practices)
- [AccuKnox: Container Security in 2026](https://accuknox.com/blog/container-security)

### Development Tools Security Trends
- [DevActivity: DevSecOps in 2026](https://devactivity.com/posts/apps-tools/the-future-of-devsecops-integrating-security-into-the-2026-development-lifecycle/)
- [OX Security: Application Security Trends 2026](https://www.ox.security/blog/application-security-trends-in-2026/)
- [DebugLies: DevSecOps Trends 2026](https://debuglies.com/2026/01/07/devsecops-trends-2026-ai-agents-revolutionizing-secure-software-development/)

---
*Feature research for: DDEV addon for AI code assistant security sandboxing*
*Researched: 2026-01-24*
