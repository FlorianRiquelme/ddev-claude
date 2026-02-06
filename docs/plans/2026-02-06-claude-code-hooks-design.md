# Claude Code Hooks for Domain Whitelisting

**Date:** 2026-02-06
**Status:** Validated

## Problem

The current firewall whitelist workflow is reactive: users discover blocked domains only after iptables drops the request, then must manually run `ddev claude:whitelist`. This creates discovery friction — users don't know the command exists or forget to use it.

## Design Decision

Add Claude Code hooks as a UX layer on top of the existing iptables firewall. The hooks intercept tool calls, detect unwhitelisted domains, and guide the user through approval — all before the network request is attempted.

**Key principle:** The container is the sandbox, not just Claude's hook system. iptables remains the kernel-level security foundation. Hooks improve UX without weakening security.

## Architecture: Deny + Dedicated Command

### Why Not Simpler Approaches

We evaluated and rejected several alternatives:

- **Hook returns `"ask"` + temp ipset add:** Creates a security window where the domain is reachable while the user decides. A prompt injection could exploit this to exfiltrate data.
- **Hook returns `"ask"` + JSON write + sleep:** Same security window problem — firewall opens before user consents.
- **Hook returns `"ask"` with no side effects:** The tool call fails (iptables blocks it), but nothing gets written, creating an infinite retry loop since the domain never gets whitelisted.

The chosen approach decouples approval from execution: the hook denies, Claude asks the user in natural language, and a dedicated command performs the whitelisting as a separate, auditable action.

### Flow

```
Claude calls WebFetch("https://example.com/api")
  |
PreToolUse hook (url-check.sh) fires
  |
Extract domain: "example.com"
  |
Check merged whitelist cache -> NOT FOUND
  |
Return: permissionDecision: "deny"
  reason: "Domain example.com is not in the firewall whitelist.
           Ask the user if they'd like to whitelist it.
           If yes, run: /opt/ddev-claude/bin/add-domain example.com"
  |
Claude tells user: "I need access to example.com but it's blocked
  by the firewall. Would you like me to whitelist it?"
  |
User: "yes"
  |
Claude calls Bash("/opt/ddev-claude/bin/add-domain example.com")
  |
PreToolUse hook -> recognizes add-domain command -> "allow"
  |
add-domain script:
  1. Validates domain format
  2. Writes domain to .ddev/ddev-claude/whitelist.json
  3. Resolves domain -> IPs via dig
  4. Adds IPs to ipset immediately
  5. Updates merged whitelist cache
  |
Claude retries: WebFetch("https://example.com/api")
  |
PreToolUse hook -> domain IS in whitelist -> "allow"
  |
Network request succeeds (IPs already in ipset)
```

### Security Properties

- **No pre-emptive firewall opening.** The firewall stays closed until the user explicitly approves and `add-domain` runs.
- **User consent in natural language.** The user sees exactly which domain will be whitelisted and approves in the chat conversation.
- **Prompt injection resistance.** A malicious prompt can trigger the deny, but cannot silently whitelist — Claude must ask the user, and the user must say yes.
- **Auditable single entry point.** All whitelisting goes through `add-domain`, which validates, logs, and persists.
- **iptables as safety net.** Even if hooks are bypassed (bug, edge case), the firewall blocks unauthorized traffic.

## Components

### PreToolUse Hook: `claude/hooks/url-check.sh`

Intercepts WebFetch, Bash, and MCP tool calls. Three-way logic:

| Condition | Action |
|-----------|--------|
| Domain in whitelist | Return `permissionDecision: "allow"` |
| Domain not in whitelist | Return `permissionDecision: "deny"` with instructions |
| Bash command is `add-domain` | Return `permissionDecision: "allow"` |
| Non-network tool / no domains found | Exit 0 (pass through) |

**Domain extraction by tool type:**

- **WebFetch:** Parse `url` field from tool input JSON
- **Bash:** Regex-match URLs from `command` field (covers curl, wget, npm, composer, git)
- **MCP (`mcp__*`):** Recursively extract URLs from any string values in tool input
- **Other tools:** Pass through (not network-related)

### Whitelist Command: `claude/bin/add-domain`

Single-purpose script that Claude calls after user approval:

1. Validates domain format (alphanumeric, dots, hyphens)
2. Reads project whitelist JSON (`.ddev/ddev-claude/whitelist.json`)
3. Appends domain, deduplicates with `jq`
4. Resolves domain to IPs via `dig +short`
5. Adds each IP to `whitelist_ips` ipset (3600s TTL)
6. Appends domain to merged whitelist cache (`/tmp/ddev-claude-merged-whitelist.txt`)

### Settings Generator: `claude/scripts/generate-settings.sh`

Runs during `entrypoint.sh` to register hooks in Claude's `settings.json`:

- Reads existing `~/.claude/settings.json` (if any, from mounted host volume)
- Deep-merges hook configuration using `jq`
- Preserves user's existing settings and hooks
- Writes back to `~/.claude/settings.json`

Hook configuration registered:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "WebFetch|Bash|mcp__.*",
        "hooks": [
          {
            "type": "command",
            "command": "/opt/ddev-claude/hooks/url-check.sh"
          }
        ]
      }
    ]
  }
}
```

## File Changes

### New files

| File | Purpose |
|------|---------|
| `claude/hooks/url-check.sh` | PreToolUse hook for domain allowlist check |
| `claude/bin/add-domain` | Whitelist command (add to JSON + ipset) |
| `claude/scripts/generate-settings.sh` | Merge hook config into settings.json |

### Modified files

| File | Change |
|------|--------|
| `claude/Dockerfile.claude` | COPY hooks/ and bin/ into container, chmod +x |
| `claude/entrypoint.sh` | Call generate-settings.sh after firewall setup |
| `claude/scripts/merge-whitelist.sh` | Write merged domains to cache file for hooks |

### Unchanged files

`docker-compose.claude.yaml`, `commands/host/claude`, `commands/host/claude-whitelist`, `watch-config.sh`, `reload-whitelist.sh` — all existing infrastructure works as-is.

## Interaction with Existing Systems

- **inotify watcher:** Still works. When `add-domain` writes to the JSON, the watcher detects it and reloads. This is redundant (add-domain already updates ipset) but harmless and ensures consistency.
- **`ddev claude:whitelist`:** Still works for batch whitelisting from blocked domains log. Complementary to hooks.
- **MCP auto-whitelist:** Still works in entrypoint. Hooks add runtime discovery on top.
- **`--no-firewall` mode:** Hooks still fire but all domains pass through (no iptables to block). The hook's deny message won't match reality. Consider: skip hooks when `--no-firewall` is active.

## Open Questions for Implementation

1. **`--no-firewall` + hooks:** Should hooks be disabled when running without firewall? Probably yes — set an env var that the hook checks.
2. **Multiple blocked domains:** When a Bash command references 3 domains and 2 are blocked, the deny message should list all blocked domains and the `add-domain` command should accept multiple arguments.
3. **Subdomain matching:** Should `*.example.com` in the whitelist match `api.example.com`? Current implementation uses exact match. Consider glob support later.
4. **Settings.json persistence:** The generated settings.json is written to `~/.claude/` which is mounted from host. This means hook config persists outside the container. Need to handle cleanup or use a container-local path.
