# ddev-claude

## What This Is

A public DDEV addon that sandboxes Claude Code for safer autonomous operation. Installs Claude CLI in the web container with a network firewall (whitelist-based, default-deny) that protects against prompt injection attacks while allowing normal development workflows. Built for agency use, shared with the DDEV community.

## Core Value

Enable `--dangerously-skip-permissions` with confidence — Claude can work autonomously without constant approval prompts, while network isolation prevents it from reaching arbitrary external endpoints.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Claude CLI installed in DDEV web container
- [ ] Network firewall with whitelist-based outbound filtering
- [ ] Default whitelist covers Claude API, GitHub, Composer, npm
- [ ] `ddev claude [args]` command runs Claude with firewall active
- [ ] `ddev claude:blocked` shows blocked domains, allows interactive whitelisting
- [ ] Global whitelist config (`~/.ddev/claude-code/whitelist.txt`)
- [ ] Per-project whitelist config (`.ddev/claude-code/whitelist.txt`)
- [ ] Hot reload whitelist without container restart
- [ ] Mount user's existing `~/.claude` config into container
- [ ] Startup warning if additional directories mounted (require acknowledgment)
- [ ] Startup warning if user's Claude config lacks `.env` deny rule
- [ ] Clear install documentation about security boundaries

### Out of Scope

- Managing Claude's settings.json — user's config, their responsibility
- URL-path level filtering — iptables works at IP/domain level only
- Real-time desktop notifications for blocks — container-to-host notification is complex
- Full attack protection — we protect network vector, document limitations clearly
- Audio feedback for blocks — nice-to-have, not v1

## Context

DDEV is a Docker-based local development environment popular for PHP/Laravel projects. Claude Code's `--dangerously-skip-permissions` flag enables autonomous operation but exposes risk from prompt injection (malicious prompts could instruct Claude to exfiltrate data or reach attacker endpoints).

By running Claude inside a DDEV container with strict network egress rules, we get:
- **File containment**: Only project files are accessible (container mount boundary)
- **Network containment**: Only whitelisted domains reachable (iptables firewall)
- **Git tracking**: All file changes visible in version control

The firewall whitelist must be project-configurable since different projects need different external API access.

Preliminary implementation plan exists at: `~/.claude/plans/goofy-humming-thompson.md`

## Constraints

- **DDEV version**: Requires v1.23+ for proper build context support
- **Container capabilities**: Needs NET_ADMIN and NET_RAW for iptables
- **Platform**: Linux containers only (iptables). macOS/Windows users run Linux containers via Docker anyway
- **Firewall scope**: IP/domain level only, not URL paths (iptables limitation)

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Whitelist approach over blacklist | Safer default — block everything, allow known-good | — Pending |
| iptables over proxy | Simpler, no SSL interception needed, sufficient for domain-level | — Pending |
| Guidance over enforcement for file rules | User mounts their own Claude config, we warn but don't manage | — Pending |
| Global + per-project config | Teams need shared defaults, projects need overrides | — Pending |
| Public repo from start | Built for agency, valuable to DDEV community | — Pending |

---
*Last updated: 2025-01-24 after initialization*
