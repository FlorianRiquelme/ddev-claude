# MCP Servers Brainstorm — 2026-02-06

**Context:** Research session to figure out how MCP servers can work inside the ddev-claude container.
**Test repo:** `/Users/florianriquelme/Repos/carnival-website/.worktrees/ddev-claude-test`
**Observation:** Exa MCP works correctly, the rest says "needs authentication"

---

## How Claude Code Discovers MCP Servers

Claude Code uses a **three-tier configuration system**:

### Tier 1: Global `~/.mcp.json`
Servers available to ALL projects. Loaded first.
```json
{
  "mcpServers": {
    "exa": {
      "url": "https://mcp.exa.ai/mcp?exaApiKey=..."
    }
  }
}
```

### Tier 2: Root-level + per-project config in `~/.claude.json`
The main config file has two relevant sections:
- **Root-level `mcpServers`** — global defaults available to all projects
- **`projects[path].mcpServers`** — per-project overrides

```json
{
  "projects": {
    "/path/to/project": {
      "mcpServers": { /* project-specific servers */ },
      "enabledMcpjsonServers": [],
      "disabledMcpjsonServers": []
    }
  },
  "mcpServers": { /* root-level = global default MCP servers */ }
}
```

### Tier 3: Project-local `.mcp.json`
Optional file in project root directory.

### Discovery Resolution Order
1. Load global `~/.mcp.json`
2. Load root-level `mcpServers` from `~/.claude.json`
3. Load project-specific `mcpServers` from `~/.claude.json[projects][path]`
4. Load `.mcp.json` from project root
5. Apply enable/disable lists

---

## MCP Transport Types

| Transport | How it works | Config key | Container requirement |
|---|---|---|---|
| **stdio** | Spawns child process, communicates via stdin/stdout | `command`, `args`, `env` | Binary must be executable |
| **HTTP** | REST API calls to endpoint | `url`, `headers` | Endpoint must be network-reachable |
| **SSE** | HTTP streaming, often with OAuth | `url` (type: sse) | Network access + possibly browser for OAuth |
| **URL-based** | Simplified HTTP (just a URL) | `url` only | Endpoint must be network-reachable |

---

## Current User's Global MCP Servers (root-level in `~/.claude.json`)

| Server | Transport | Endpoint | Container Status | Root Cause |
|---|---|---|---|---|
| **Exa** | stdio | `npx -y exa-mcp-server` | **Works** | Node.js + npx installed, `registry.npmjs.org` whitelisted |
| **Context7** | HTTP | `https://mcp.context7.com/mcp` | **Fails** | `mcp.context7.com` NOT in firewall whitelist |
| **Atlassian** | SSE + OAuth | `https://mcp.atlassian.com/v1/sse` | **Fails** | OAuth needs browser + domain blocked |
| **Ray App** | HTTP | `http://localhost:2411/mcp` | **Fails** | `localhost` in container != host's localhost |

Plus `~/.mcp.json` has Exa via URL-based HTTP — also works.

---

## Why "Needs Authentication" Is Misleading

For **Context7**: the firewall blocks the HTTP request to `mcp.context7.com`. The connection timeout/failure is reported by Claude Code as an authentication error, but the real issue is the iptables DROP rule.

For **Atlassian**: SSE transport with OAuth genuinely needs authentication — the OAuth flow requires a browser redirect that can't work headless.

For **Ray App**: `localhost:2411` resolves to the container itself (nothing running there), so the connection is refused.

---

## Why Exa Works

Exa works because of a perfect storm:
1. Global `~/.mcp.json` uses URL-based config (API key in URL, no subprocess needed)
2. Container has Node.js + npx (stdio fallback from `~/.claude.json` also works)
3. `registry.npmjs.org` is whitelisted (npx can download the package)
4. `mcp.exa.ai` is reachable (either directly or via the URL-based transport mechanism)

---

## Solution Options

### Option A: Whitelist MCP Domains (Quick Win)

Add common MCP server domains to the default whitelist.

```json
// Add to claude/config/default-whitelist.json:
"mcp.context7.com",
"mcp.exa.ai",
"mcp.atlassian.com"
```

Optionally add `host.docker.internal` for localhost-bound MCP servers.

| Aspect | Details |
|---|---|
| **Effort** | Low — config-only change |
| **Fixes** | HTTP MCPs with API key auth (Context7, Exa) |
| **Doesn't fix** | OAuth MCPs (Atlassian), localhost MCPs (without host.docker.internal) |
| **Security** | `host.docker.internal` opens path to ALL host services — concern for security-focused addon |

---

### Option B: MCP Proxy on Host (Full Support)

Run [`mcp-proxy`](https://github.com/sparfenyuk/mcp-proxy) (2,200+ stars) on the host. It reads MCP config and exposes ALL servers over a single HTTP endpoint.

```
Host Machine
+--------------------------------------------------+
|  MCP Server 1 (stdio)   MCP Server 2 (HTTP)      |
|       |                       |                   |
|  mcp-proxy --port=9100 --host=0.0.0.0            |
|  (aggregates all servers over HTTP)               |
+--------------------------------------------------+
         | HTTP (Docker networking)
+--------------------------------------------------+
|  DDEV Claude Container                            |
|  Claude Code -> mcp-remote ->                     |
|    host.docker.internal:9100                      |
+--------------------------------------------------+
```

**How `ddev claude` would work:**
1. Host command starts `mcp-proxy` before launching container session
2. Proxy reads user's MCP config, bridges all servers to HTTP
3. Container `.mcp.json` auto-generated with `mcp-remote` pointing to proxy
4. Firewall only needs `host.docker.internal` on proxy port

**mcp-proxy features:**
- Config file in standard `mcpServers` format
- Named server routing: `/servers/context7/sse`, `/servers/exa/sse`
- Handles OAuth flows on host side (browser available)
- Aggregates multiple servers behind single endpoint

| Aspect | Details |
|---|---|
| **Effort** | Medium — new host script, container config generation, proxy lifecycle |
| **Fixes** | ALL MCP types (stdio, HTTP, SSE, OAuth) |
| **Dependency** | `mcp-proxy` must be installed on host (pip/uvx) |
| **Security** | Only one whitelisted endpoint needed |

---

### Option C: Docker MCP Gateway Sidecar

Add Docker's [MCP Gateway](https://github.com/docker/mcp-gateway) (1,200+ stars) as a DDEV service.

```yaml
services:
  mcp-gateway:
    image: docker/mcp-gateway
    command: ["--port=8080", "--transport=streaming"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

| Aspect | Details |
|---|---|
| **Effort** | High |
| **Fixes** | All MCP types |
| **Blocker** | Requires Docker socket access (root-equivalent host access) — **conflicts with security-first philosophy** |

---

### Option D: Hybrid (A + selective proxy)

1. Default whitelist includes common MCP domains (zero-config for HTTP MCPs)
2. Optional `ddev claude:mcp-proxy` command starts proxy for stdio/OAuth servers
3. Documentation explains which types work out-of-box vs. need proxy

| Aspect | Details |
|---|---|
| **Effort** | Medium |
| **Fixes** | Progressive — basic out-of-box, full with proxy opt-in |
| **UX** | Best balance of simplicity and power |

---

### Option E: Unix Socket Forwarding (Advanced)

Run mcp-proxy on host listening on a Unix socket, bind-mount into container.

| Aspect | Details |
|---|---|
| **Effort** | High |
| **Fixes** | All MCP types |
| **Blocker** | mcp-proxy doesn't natively support Unix sockets (needs socat bridge) |

---

## Recommended Path

1. **Phase 1 (Quick Win):** Option A — whitelist `mcp.context7.com`, `mcp.exa.ai`, create MCP stack template
2. **Phase 2 (Full Support):** Option B — implement mcp-proxy integration
3. **Long-term:** Option D hybrid as final architecture

---

## Related Tools & Projects

| Tool | Stars | Purpose |
|---|---|---|
| [mcp-proxy](https://github.com/sparfenyuk/mcp-proxy) | 2,200+ | stdio<->HTTP MCP bridge |
| [mcp-remote](https://github.com/geelen/mcp-remote) | 1,200+ | stdio->HTTP with OAuth |
| [Docker MCP Gateway](https://github.com/docker/mcp-gateway) | 1,200+ | Docker-native MCP management |
| [claude-code-mcp-docker](https://github.com/akr4/claude-code-mcp-docker) | ~100 | Similar project (Claude in Docker with firewall) |

---

## Technical Details for Implementation

### Container mounts affecting MCP
- `~/.claude` -> `/root/.claude` (rw) — Claude config/sessions
- `~/.claude.json` -> `/root/.claude.json` (rw) — MCP server definitions live here
- `${DDEV_APPROOT}` -> `${DDEV_APPROOT}` (cached) — project path matches host path

### Why project paths work
Project mounted at real host path `${DDEV_APPROOT}`, not `/var/www/html`. So project-specific MCP configs in `~/.claude.json` match because the container path equals the host path.

### Environment variable expansion in MCP configs
Claude Code supports: `${CLAUDE_PROJECT_DIR}`, `${CLAUDE_PLUGIN_ROOT}`, and any shell env var.

### Current default whitelist (for reference)
```
api.anthropic.com, claude.ai, statsig.anthropic.com, sentry.io,
github.com, api.github.com, raw.githubusercontent.com,
objects.githubusercontent.com, codeload.github.com,
registry.npmjs.org, packagist.org, repo.packagist.org,
cdn.jsdelivr.net, unpkg.com
```

### Test environment
- **Repo:** `/Users/florianriquelme/Repos/carnival-website/.worktrees/ddev-claude-test`
- **Stack:** Laravel 8.3 + MariaDB 10.11
- **Per-project MCP:** Empty (`mcpServers: {}`)
- **Global MCP active:** Exa (works), Context7 (fails), Atlassian (fails), Ray App (fails)
