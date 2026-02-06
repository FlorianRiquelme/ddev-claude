# MCP Auto-Whitelist Design

**Date:** 2026-02-06
**Status:** Approved
**Prerequisite research:** [MCP-BRAINSTORM-2026-02-06.md](./MCP-BRAINSTORM-2026-02-06.md)

---

## Problem

MCP servers configured on the host fail inside the ddev-claude container because the firewall blocks their domains. Users see misleading "needs authentication" errors. The real cause is iptables DROP rules.

## Solution

Auto-detect MCP server domains from the user's existing Claude config files at container startup. Add those domains to the firewall whitelist before rules are finalized. Zero configuration required from the user.

## What Works After This

| MCP Type | Example | Status |
|---|---|---|
| HTTP with API key | Context7 (`mcp.context7.com`) | **Fixed** — domain auto-whitelisted |
| URL-based HTTP | Exa (`mcp.exa.ai`) | Already works, now explicitly whitelisted |
| stdio (npx/node) | Exa via `npx exa-mcp-server` | Already works, no change |

## Known Limitations (Documented, Not Solved)

| MCP Type | Example | Why | Workaround |
|---|---|---|---|
| OAuth/SSE | Atlassian | Needs browser for OAuth flow — impossible headless | None currently. Out of scope. |
| localhost | Ray App (`localhost:2411`) | Container localhost != host localhost | User configures `host.docker.internal` in per-project MCP override |
| Exotic stdio | Custom Go binary | Binary not installed in container | User installs binary via custom Dockerfile extension |

---

## Config Sources (All Three Tiers)

### 1. `~/.mcp.json` (global)

```json
{
  "mcpServers": {
    "exa": { "url": "https://mcp.exa.ai/mcp?exaApiKey=..." }
  }
}
```

Extraction: `.mcpServers[]?.url? // empty`

### 2. `~/.claude.json` (global + current project)

```json
{
  "mcpServers": {
    "context7": { "url": "https://mcp.context7.com/mcp" }
  },
  "projects": {
    "/path/to/project": {
      "mcpServers": {
        "ray": { "url": "http://localhost:2411/mcp" }
      }
    }
  }
}
```

Extraction (two targeted queries):
- Global: `.mcpServers[]?.url? // empty`
- Current project only: `.projects["${DDEV_APPROOT}"]?.mcpServers[]?.url? // empty`

**Important:** Only the current project's MCP domains are whitelisted, not all projects.

### 3. `${DDEV_APPROOT}/.mcp.json` (project-local)

Same flat structure as `~/.mcp.json`.

Extraction: `.mcpServers[]?.url? // empty`

---

## Implementation: entrypoint.sh Integration

The new logic slots between existing steps 6 (whitelist merge) and 7 (iptables ipset rule).

### Insertion Point

```
Line 51: fi  (end of existing whitelist merge)
          ↓
NEW:    MCP domain extraction block (~30 lines)
          ↓
Line 53: iptables -A OUTPUT -m set --match-set whitelist_ips dst -j ACCEPT
```

### Logic

```bash
# --- MCP Domain Auto-Whitelist ---
extract_mcp_domains() {
    local domains=""
    local mcp_json="/root/.mcp.json"
    local claude_json="/root/.claude.json"
    local project_mcp="${DDEV_APPROOT}/.mcp.json"

    # Tier 1: ~/.mcp.json
    if [[ -f "$mcp_json" ]]; then
        domains+=$(jq -r '.mcpServers[]?.url? // empty' "$mcp_json" 2>/dev/null || true)
        domains+=$'\n'
    fi

    # Tier 2: ~/.claude.json (global mcpServers)
    if [[ -f "$claude_json" ]]; then
        domains+=$(jq -r '.mcpServers[]?.url? // empty' "$claude_json" 2>/dev/null || true)
        domains+=$'\n'
        # Tier 2: ~/.claude.json (current project only)
        domains+=$(jq -r --arg proj "$DDEV_APPROOT" \
            '.projects[$proj]?.mcpServers[]?.url? // empty' "$claude_json" 2>/dev/null || true)
        domains+=$'\n'
    fi

    # Tier 3: project .mcp.json
    if [[ -f "$project_mcp" ]]; then
        domains+=$(jq -r '.mcpServers[]?.url? // empty' "$project_mcp" 2>/dev/null || true)
        domains+=$'\n'
    fi

    # Extract hostnames from URLs, filter localhost, deduplicate
    echo "$domains" \
        | grep -oP '://\K[^/:?]+' \
        | grep -v -E '^(localhost|127\.0\.0\.1|0\.0\.0\.0)$' \
        | sort -u
}

if mcp_domains=$(extract_mcp_domains 2>/dev/null) && [[ -n "$mcp_domains" ]]; then
    log "Whitelisting MCP domains: $(echo "$mcp_domains" | tr '\n' ', ' | sed 's/,$//')"
    temp_mcp=$(mktemp)
    echo "$mcp_domains" > "$temp_mcp"
    "$SCRIPT_DIR/resolve-and-apply.sh" "$temp_mcp" || log "WARNING: Some MCP domains failed to resolve"
    rm -f "$temp_mcp"
else
    log "No MCP domains detected"
fi
```

---

## Error Handling

**Principle: warn and continue, never block startup.**

The entire MCP extraction block is isolated from the main ERR trap. If any part fails, Claude starts normally — just without MCP servers whitelisted.

| Failure | Behavior |
|---|---|
| Config file doesn't exist | Skip silently |
| JSON is malformed | `jq` fails, `|| true` catches it, skip that file |
| `jq` returns empty | "No MCP domains detected" logged |
| Domain resolution fails | Handled by existing `resolve-and-apply.sh` (logs per domain) |
| All domains are localhost | Filtered out, "No MCP domains detected" logged |

---

## Logging

Single log line during startup:

```
[ddev-claude] Whitelisting MCP domains: mcp.context7.com, mcp.exa.ai
```

Or if none found:

```
[ddev-claude] No MCP domains detected
```

---

## Testing Plan

Manual verification (no bats suite yet):

1. **With MCP config:** Start container, verify Context7 domain appears in `ipset list whitelist_ips`
2. **Without MCP config:** Start container with no `~/.claude.json`, verify "No MCP domains detected" in logs
3. **Malformed JSON:** Put invalid JSON in `~/.mcp.json`, verify container starts with warning
4. **localhost filtering:** Add localhost MCP to config, verify it's skipped
5. **Per-project scoping:** Add MCP to different project in `~/.claude.json`, verify it's NOT whitelisted

---

## Future Considerations

- **mcp-proxy integration:** If OAuth/localhost support becomes critical, the next step is an optional mcp-proxy running inside the container or as a sidecar. This design doesn't preclude that.
- **Hot reload:** The existing `watch-config.sh` watches whitelist files. Could be extended to also watch MCP config changes, but out of scope for now.
