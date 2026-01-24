# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2025-01-24)

**Core value:** Enable `--dangerously-skip-permissions` with confidence — Claude can work autonomously without constant approval prompts, while network isolation prevents it from reaching arbitrary external endpoints.
**Current focus:** Phase 2 complete, ready for Phase 3

## Current Position

Phase: 2 of 4 (Configuration & Commands) - COMPLETE
Plan: 7 of 7 in current phase
Status: Phase complete
Last activity: 2026-01-24 — Completed 02-07-PLAN.md (User-friendly block notifications)

Progress: [██████████] 100% (10/10 plans complete)

## Performance Metrics

**Velocity:**
- Total plans completed: 10
- Average duration: 1.7 min
- Total execution time: 16 min 50s

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Firewall Foundation | 3 | 5 min | 1.7 min |
| 2. Configuration & Commands | 7 | 11 min 50s | 1.7 min |

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- **Dedicated claude container over web container modification** (2026-01-24): Web container needs unrestricted network for normal ops (composer, npm, APIs). Firewall on web container breaks the website. Claude runs in isolated container instead.
- Whitelist approach over blacklist: Safer default — block everything, allow known-good
- iptables over proxy: Simpler, no SSL interception needed, sufficient for domain-level
- Guidance over enforcement for file rules: User mounts their own Claude config, we warn but don't manage
- Global + per-project config: Teams need shared defaults, projects need overrides

**Lessons from failed web container approach:**
- iptables requires root or proper capabilities — DDEV web container runs as non-root user
- Firewall on web container blocks website's own outbound traffic (composer, npm, etc.)
- Architecture must isolate Claude from web container entirely

**Plan 01-01 decisions:**
- DDEV v1.24.10+ required for proper build context support
- Claude container runs as root (iptables requirement)
- ~/.claude mounted to /home/.claude for config persistence
- debian:bookworm-slim base matches DDEV web container OS

**Plan 01-02 decisions:**
- Critical rule ordering: loopback -> DNS -> established -> whitelist -> DROP to avoid self-blocking
- ipset timeout 3600 seconds (1 hour) for DNS TTL safety
- Rate-limited logging (2/sec) to prevent log flooding while maintaining visibility
- Graceful domain resolution failure: warn and continue, don't fail entire firewall

**Plan 01-03 decisions:**
- Five-check validation: iptables rules count, DROP policy, ipset exists, ipset entries (warn only), functional blocking test
- TEST-NET-2 (198.51.100.1) for blocking test - reserved IP that never routes
- Graceful empty ipset handling: warn but don't fail - legitimate if no domains configured
- Docker healthcheck integration: exit 0 on pass, exit 1 on fail

**Plan 02-01 decisions:**
- Three-tier whitelist merge: Default + global + project configs for layered customization
- JSON format over text: Structured format enables validation, merging, and tooling

**Plan 02-02 decisions:**
- Commands in commands/host/ since they run on host and exec into container
- "$@" for argument passing instead of $* (preserves spaces in args)
- Whitelist command as skeleton - gum interactive UI comes in 02-04

**Plan 02-03 decisions:**
- 2-second debounce window handles editor save patterns (temp file + atomic rename)
- Watch directories not files to catch atomic save events (moved_to)
- JSON validation before reload prevents broken configs from clearing firewall
- PID file singleton pattern prevents watcher duplication on restart

**Plan 02-04 decisions:**
- gum runs in container for consistent environment
- Best-effort reverse DNS with fallback to raw IP
- IPs without reverse DNS shown separately with guidance
- jq for JSON manipulation ensures valid output

**Plan 02-05 decisions:**
- Claude skills in claude/skills/{name}/SKILL.md with YAML frontmatter
- user-invocable: true enables /command access
- Skill provides full firewall context including hot reload timing

**Plan 02-07 decisions:**
- dmesg -w for real-time monitoring instead of polling
- Reverse DNS with timeout for better UX (show domains not just IPs)
- Deduplication via /tmp state file prevents message spam

### Pending Todos

1. **Make repository LLM-friendly with comprehensive docs** (docs) — Enable LLMs to understand and explain the project, assist with installation/configuration

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-01-24 13:00 UTC
Stopped at: Completed 02-07-PLAN.md (User-friendly block notifications - gap closure complete)
Resume file: None

Next action: Begin Phase 3 (Integration & Testing)
