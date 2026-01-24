# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2025-01-24)

**Core value:** Enable `--dangerously-skip-permissions` with confidence — Claude can work autonomously without constant approval prompts, while network isolation prevents it from reaching arbitrary external endpoints.
**Current focus:** Phase 2: Configuration & Commands

## Current Position

Phase: 1 of 4 (Firewall Foundation)
Plan: 0 of 3 in current phase
Status: Replanning — architecture change to dedicated container
Last activity: 2026-01-24 — UAT revealed web container approach breaks website

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**
- Total plans completed: 0 (reset after architecture change)
- Average duration: —
- Total execution time: —

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Firewall Foundation | 0 | — | — |

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

### Pending Todos

1. **Make repository LLM-friendly with comprehensive docs** (docs) — Enable LLMs to understand and explain the project, assist with installation/configuration

### Blockers/Concerns

None yet.

## Session Continuity

Last session: 2026-01-24 UAT and architecture revision
Stopped at: Phase 1 needs replanning with dedicated container architecture
Resume file: None

Next action: `/gsd:plan-phase 1` to create new plans for dedicated claude container
