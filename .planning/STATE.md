# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2025-01-24)

**Core value:** Enable `--dangerously-skip-permissions` with confidence — Claude can work autonomously without constant approval prompts, while network isolation prevents it from reaching arbitrary external endpoints.
**Current focus:** Phase 2: Configuration & Commands

## Current Position

Phase: 1 of 4 (Firewall Foundation)
Plan: 1 of 3 in current phase
Status: In progress — DDEV addon skeleton complete
Last activity: 2026-01-24 — Completed 01-01-PLAN.md

Progress: [█░░░░░░░░░] 10%

## Performance Metrics

**Velocity:**
- Total plans completed: 1
- Average duration: 1 min
- Total execution time: 1 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Firewall Foundation | 1 | 1 min | 1 min |

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

### Pending Todos

1. **Make repository LLM-friendly with comprehensive docs** (docs) — Enable LLMs to understand and explain the project, assist with installation/configuration

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-01-24 07:04 UTC
Stopped at: Completed 01-01-PLAN.md (DDEV addon skeleton)
Resume file: None

Next action: Execute 01-02-PLAN.md (Firewall scripts)
