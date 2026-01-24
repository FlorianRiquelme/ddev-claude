---
phase: 02-configuration-commands
plan: 01
subsystem: configuration-infrastructure
tags: [json, jq, inotify, gum, whitelist, merge]
dependency-graph:
  requires: [01-firewall-foundation]
  provides: [json-merge-infrastructure, configuration-tools, stack-templates]
  affects: [02-02-PLAN, 02-03-PLAN]
tech-stack:
  added: [jq, inotify-tools, gum]
  patterns: [json-whitelist-format, merge-strategy]
key-files:
  created:
    - claude/scripts/merge-whitelist.sh
    - claude/config/default-whitelist.json
    - claude/config/stack-templates/laravel.json
    - claude/config/stack-templates/npm.json
  modified:
    - claude/Dockerfile.claude
decisions:
  - title: "Three-tier whitelist merge"
    choice: "Default + global + project configs"
    rationale: "Layered approach: addon defaults, user global, project-specific"
  - title: "JSON format over text"
    choice: "JSON arrays for whitelist files"
    rationale: "Structured format enables validation, merging, and tooling"
metrics:
  duration: 1m 25s
  completed: 2026-01-24
---

# Phase 02 Plan 01: Configuration Infrastructure Summary

JSON-based whitelist management with jq merging, container tools, and stack templates for framework detection.

## What Was Built

### 1. Container Configuration Tools (Dockerfile.claude)
Added required tooling to the Claude container:
- **jq**: JSON processing for whitelist merge operations
- **inotify-tools**: File watching for hot-reload (future use)
- **gum**: Interactive CLI prompts from Charm (for /whitelist skill)

Gum installed from Charm APT repository with proper GPG key verification.

### 2. Whitelist Merge Script (merge-whitelist.sh)
Shell script that combines three whitelist sources:
1. Default whitelist (built into addon at `/var/www/html/.ddev/claude/config/default-whitelist.json`)
2. Global user config (`~/.ddev/ddev-claude/whitelist.json`)
3. Project config (`.ddev/ddev-claude/whitelist.json`)

Features:
- JSON validation before merging (fails fast on invalid JSON)
- Handles missing config files gracefully (treats as empty array)
- Outputs unique, deduplicated domains as line-delimited text
- Designed for use by `resolve-and-apply.sh`

### 3. Default Whitelist (default-whitelist.json)
Pre-configured domains essential for Claude development:
- **Claude API**: api.anthropic.com, claude.ai, statsig.anthropic.com, sentry.io
- **GitHub**: github.com, api.github.com, raw.githubusercontent.com, objects.githubusercontent.com, codeload.github.com
- **Package registries**: registry.npmjs.org, packagist.org, repo.packagist.org
- **CDNs**: cdn.jsdelivr.net, unpkg.com

### 4. Stack Templates
Pre-built domain lists for common frameworks:

**Laravel** (laravel.json):
- packagist.org, repo.packagist.org
- GitHub domains for package sources

**npm** (npm.json):
- registry.npmjs.org, registry.yarnpkg.com
- GitHub domains for package sources

## Task Commits

| Task | Commit | Description |
|------|--------|-------------|
| 1 | 0db68db | Add jq, inotify-tools, gum to Dockerfile |
| 2 | 8954dc7 | Add merge-whitelist.sh and default-whitelist.json |
| 3 | 463be71 | Add Laravel and npm stack templates |

## Deviations from Plan

None - plan executed exactly as written.

## Key Files

```
claude/
  Dockerfile.claude          # Updated with jq, inotify-tools, gum
  scripts/
    merge-whitelist.sh       # Merges JSON whitelist sources
  config/
    default-whitelist.json   # Built-in essential domains
    stack-templates/
      laravel.json           # Laravel framework domains
      npm.json               # npm ecosystem domains
```

## Integration Points

- `merge-whitelist.sh` outputs line-delimited domains for `resolve-and-apply.sh`
- Stack templates will be offered by `/whitelist` skill (02-02)
- inotify-tools enables future hot-reload watching (03-01)

## Next Phase Readiness

Plan 02-02 can proceed:
- jq available for JSON processing in DDEV commands
- Stack templates ready for framework detection
- Merge infrastructure ready for `ddev claude:whitelist` implementation
