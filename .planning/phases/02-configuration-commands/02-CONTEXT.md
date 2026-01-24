# Phase 2: Configuration & Commands - Context

**Gathered:** 2026-01-24
**Status:** Ready for planning

<domain>
## Phase Boundary

Users configure domain whitelists and run Claude CLI through DDEV with firewall protection. Includes config file management, DDEV commands for running Claude, hot reload of configuration changes, and a Claude skill for firewall awareness.

</domain>

<decisions>
## Implementation Decisions

### Whitelist config format
- JSON format (pure JSON, no comments)
- One domain per entry in a JSON array
- Wildcards supported: `*.example.com` syntax for subdomains
- Global and per-project configs merge as union (global provides defaults, project adds more)
- Global config: `~/.ddev/ddev-claude/whitelist.json`
- Project config: `.ddev/ddev-claude/whitelist.json`

### Command interface
- `ddev claude` passes through Claude's output directly (no wrapper UI)
- `ddev claude --no-firewall` disables firewall with optional domain logging (for users who want to build a whitelist)
- `ddev claude:whitelist` is interactive — shows logged domains, lets user pick which to add with checkboxes

### Hot reload
- File watch triggers automatic reload when whitelist.json changes
- Brief log message on reload: "Whitelist reloaded: 12 domains"
- Debounce delay of 1-2 seconds to handle rapid edits/partial saves
- Invalid JSON blocks all traffic until fixed (fail safe)

### /whitelist skill
- Lives inside claude container only (part of addon, not user's global config)
- Skill file mounted from addon so users can customize if needed
- Triggers both ways: user can invoke `/whitelist`, and Claude proactively suggests when blocks detected
- Always asks user for confirmation before editing whitelist
- Explains why domains are needed: "api.github.com is needed for GitHub API access"
- Offers stack templates: "Detected Laravel project — add Laravel domains?"
- Smart default for target: project config for project-specific domains, global for common ones (npm, composer)
- Full management: can add and remove domains
- No verification before adding (DNS resolution happens at firewall level)
- Only shows whitelist status when explicitly asked

### Claude's Discretion
- Blocked domain logging mechanism (file vs container logs)
- Flag design for no-firewall + logging options
- Specific debounce timing within 1-2 second range
- Stack template detection logic
- How to determine if a domain is "common" vs "project-specific"

</decisions>

<specifics>
## Specific Ideas

- The /whitelist skill should feel native to Claude — proactive help when blocked, not just a command
- Stack templates should cover common frameworks: Laravel (packagist, etc.), npm projects, etc.
- Default whitelist should include Claude API, GitHub, Composer, npm registries out of the box

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-configuration-commands*
*Context gathered: 2026-01-24*
