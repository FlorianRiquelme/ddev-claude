# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

A DDEV addon that runs Claude Code CLI in a sandboxed container with network firewall (iptables, whitelist-based, default-deny). Enables `--dangerously-skip-permissions` with confidence by preventing prompt injection attacks from reaching arbitrary endpoints.

## Development Commands

```bash
# Install addon into a DDEV project (copies files to .ddev/)
ddev get florianriquelme/ddev-claude
ddev restart

# Rebuild claude container after Dockerfile changes
ddev restart

# Run Claude CLI with firewall
ddev claude
ddev claude --dangerously-skip-permissions
ddev claude --no-firewall        # Bypass firewall, logs domains accessed

# Manage whitelist
ddev claude:whitelist

# Debug firewall inside container
ddev exec -s claude iptables -L OUTPUT -n
ddev exec -s claude ipset list whitelist_ips
```

There is no formal test suite yet (planned for Phase 3 with bats).

## Architecture

**Dedicated container approach:** The addon creates a separate `claude` container rather than modifying the web container. The web container needs unrestricted network for normal ops — Claude isolation shouldn't break the website.

**Key components:**

- `docker-compose.claude.yaml` — Service definition. Mounts project at `${DDEV_APPROOT}` (real host path, not `/var/www/html`). Requires NET_ADMIN + NET_RAW capabilities.
- `install.yaml` — DDEV addon manifest. Copies `claude/` dir and host commands into `.ddev/`.
- `claude/Dockerfile.claude` — Builds on `debian:bookworm-slim`. Installs PHP, Node.js, Composer, iptables, ipset, jq, gum, Claude CLI.
- `claude/entrypoint.sh` — Firewall initialization. Rule order matters: loopback → DNS → established → whitelisted IPs → log → DROP.
- `claude/resolve-and-apply.sh` — Resolves domains to IPs via `dig` and adds to ipset.
- `claude/scripts/merge-whitelist.sh` — 3-tier config merge (default + global + per-project).
- `claude/scripts/watch-config.sh` — inotify watcher for hot reload on whitelist changes (2s debounce).
- `claude/scripts/reload-whitelist.sh` — Flushes ipset and re-resolves on config change.
- `commands/host/claude` — Host command: `ddev claude [args]`. Handles `--no-firewall` flag.
- `commands/host/claude-whitelist` — Host command: `ddev claude:whitelist`. Interactive domain selection via gum.

**Whitelist config hierarchy (merged with `jq`):**
1. Default: `claude/config/default-whitelist.json` (Claude API, GitHub, npm, Composer, CDNs)
2. Global: `~/.ddev/ddev-claude/whitelist.json`
3. Per-project: `.ddev/ddev-claude/whitelist.json`

Stack templates in `claude/config/stack-templates/` (laravel.json, npm.json).

## Coding Conventions

- **Language:** All scripts are Bash. Use `set -euo pipefail` in every script.
- **Logging:** `LOG_PREFIX="[ddev-claude]"` with `log()` and `error()` helper functions.
- **DDEV marker:** Files managed by DDEV start with `#ddev-generated` comment.
- **JSON whitelist format:** Simple arrays: `["domain1.com", "domain2.com"]`. Validated with `jq empty`.
- **Error handling:** Entrypoint uses `trap ... ERR` to fail closed if firewall setup fails.

## Project Planning

Planning artifacts live in `.planning/`:
- `PROJECT.md` — Core value, constraints, key decisions
- `REQUIREMENTS.md` — v1 requirements with traceability IDs (FIRE-*, CONF-*, UI-*, SAFE-*, DDEV-*, SKILL-*)
- `ROADMAP.md` — 4-phase roadmap. Phases 1-2 complete, 3-4 pending.
- `STATE.md` — Current position and accumulated context
- Phase plans in `phases/` subdirectories

## Current Status

Phases 1 (Firewall Foundation) and 2 (Configuration & Commands) are complete. Next up is Phase 3 (Safety Warnings & Documentation) which includes mount detection warnings, `.env` protection checks, and a bats test suite.
