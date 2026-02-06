# MCP Servers Investigation

**Status:** Research Complete — Ready for Implementation
**Priority:** V1 Release Blocker
**Created:** 2026-01-24
**Updated:** 2026-02-06

## Problem Statement

MCP (Model Context Protocol) servers don't work when running `ddev claude`. Users lose significant Claude functionality (database access, external tools, custom integrations) inside the container. User reports: "Exa MCP works correctly, the rest says needs authentication."

## How Claude Code Discovers MCP Servers

Claude Code uses a **three-tier configuration system** to discover MCP servers:

### Tier 1: Global config (`~/.mcp.json`)
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

### Tier 2: Per-project config in `~/.claude.json`
The main config file stores per-project MCP settings under `projects[path].mcpServers`:
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

Root-level `mcpServers` in `~/.claude.json` acts as global defaults (available to all projects).

### Tier 3: Project-local `.mcp.json`
Optional file in project root directory with additional/override servers.

### Discovery Resolution Order
1. Load global `~/.mcp.json`
2. Load root-level `mcpServers` from `~/.claude.json`
3. Load project-specific `mcpServers` from `~/.claude.json[projects][path]`
4. Load `.mcp.json` from project root
5. Apply enable/disable lists from `~/.claude.json`

## MCP Transport Types

Claude Code supports **four transport protocols**:

### 1. stdio (Standard I/O) — Most Common
Claude spawns MCP as a child process, communicates via stdin/stdout.
```json
{
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "exa-mcp-server"],
  "env": { "EXA_API_KEY": "..." }
}
```
**Requirement:** Binary/command must be executable in the environment.

### 2. HTTP (REST API)
Direct HTTP requests to a remote endpoint.
```json
{
  "type": "http",
  "url": "https://mcp.context7.com/mcp",
  "headers": { "CONTEXT7_API_KEY": "..." }
}
```
**Requirement:** Endpoint must be network-reachable.

### 3. SSE (Server-Sent Events) — Often with OAuth
HTTP streaming with OAuth authentication flows.
```json
{
  "type": "sse",
  "url": "https://mcp.atlassian.com/v1/sse"
}
```
**Requirement:** Network access + potentially a browser for OAuth.

### 4. URL-based (special HTTP variant)
Simplified HTTP config using just a URL:
```json
{
  "url": "https://mcp.exa.ai/mcp?exaApiKey=..."
}
```

## Root Cause Analysis

### What the user's container sees

The container mounts `~/.claude` → `/root/.claude` and `~/.claude.json` → `/root/.claude.json`, so Claude Code inside the container reads the **same MCP config** as on the host.

Root-level `mcpServers` in `~/.claude.json` (global defaults):

| Server | Transport | Endpoint | Status in Container | Root Cause |
|---|---|---|---|---|
| **Exa** | stdio | `npx -y exa-mcp-server` | **Works** | Node.js + npx installed, `registry.npmjs.org` whitelisted, `mcp.exa.ai` reachable |
| **Context7** | HTTP | `https://mcp.context7.com/mcp` | **Fails** | `mcp.context7.com` NOT in firewall whitelist → request blocked → reported as "auth error" |
| **Atlassian** | SSE + OAuth | `https://mcp.atlassian.com/v1/sse` | **Fails** | OAuth requires browser flow impossible in headless container + domain blocked |
| **Ray App** | HTTP | `http://localhost:2411/mcp` | **Fails** | `localhost` in container ≠ host's localhost. Would need `host.docker.internal:2411` |

### Key Findings

1. **"Needs authentication" is misleading** — For Context7, the firewall blocks the HTTP request to `mcp.context7.com`. The connection timeout/failure is reported by Claude Code as an authentication error, but the real issue is the firewall DROP rule.

2. **Exa works because of a perfect storm:**
   - Global `~/.mcp.json` has URL-based config (no subprocess needed)
   - Container has Node.js + npx (stdio fallback works too)
   - `mcp.exa.ai` seems to be reachable (possibly via CDN that resolves to a whitelisted IP, or the URL-based transport doesn't go through normal HTTP)

3. **stdio servers generally work** if:
   - The command exists in container (npx is available, Node.js installed)
   - The npm package can be downloaded (`registry.npmjs.org` is whitelisted)
   - The MCP server itself doesn't need external network access beyond whitelisted domains

4. **HTTP servers fail** if their domain isn't whitelisted — this is the primary issue.

5. **localhost-bound services** (Ray, Figma Desktop) are unreachable because `localhost` in Docker means the container itself. Need `host.docker.internal` instead.

6. **OAuth-based servers** (Atlassian SSE) cannot complete their auth flow in a headless container.

## Solution Options

### Option A: Whitelist MCP Domains (Quick Win)

Add common MCP server domains to the default whitelist.

**Changes:**
```json
// claude/config/default-whitelist.json — add:
"mcp.context7.com",
"mcp.exa.ai",
"mcp.atlassian.com"
```

Optionally add `host.docker.internal` for localhost-bound MCP servers:
```json
"host.docker.internal"
```

**Pros:**
- Minimal change, fixes HTTP-based MCP servers immediately
- Context7 would work right away
- `host.docker.internal` enables Ray App and similar local services

**Cons:**
- Whitelisting `host.docker.internal` opens a path to ALL host services (security concern)
- Doesn't fix OAuth auth flows (Atlassian still broken in headless mode)
- New MCP servers with custom domains need manual whitelist updates
- Users would need to add their own MCP server domains to project/global whitelist

**Effort:** Low (config-only change)
**Coverage:** HTTP MCPs with API key auth ✅ | stdio MCPs ✅ (already work) | OAuth MCPs ❌ | localhost MCPs ⚠️ (with `host.docker.internal`)

---

### Option B: MCP Proxy on Host (Recommended for Full Support)

Run [`mcp-proxy`](https://github.com/sparfenyuk/mcp-proxy) (2,200+ GitHub stars) on the host machine. It reads MCP config and exposes ALL servers (stdio, HTTP, SSE) over a single HTTP endpoint that the container can reach.

**Architecture:**
```
Host Machine
┌─────────────────────────────────────────────┐
│  MCP Server 1 (stdio)   MCP Server 2 (HTTP) │
│       │                       │              │
│  mcp-proxy --port=9100 --host=0.0.0.0       │
│  (aggregates all servers over HTTP)          │
└─────────────────────────────────────────────┘
         │ HTTP (Docker networking)
┌─────────────────────────────────────────────┐
│  DDEV Claude Container                       │
│  Claude Code → mcp-remote →                  │
│    host.docker.internal:9100                 │
└─────────────────────────────────────────────┘
```

**How it works:**
1. `ddev claude` command starts `mcp-proxy` on the host before launching container session
2. Proxy reads user's MCP config and bridges all servers to HTTP
3. Container's `.mcp.json` configured with `mcp-remote` pointing to `host.docker.internal:9100`
4. Firewall only needs to whitelist one endpoint: `host.docker.internal` on port 9100

**mcp-proxy features:**
- Supports config file in standard `mcpServers` format
- Named server routing: `/servers/context7/sse`, `/servers/exa/sse`
- Handles OAuth flows on the host side
- Aggregates multiple servers behind single endpoint

**Pros:**
- ALL MCP server types work (stdio, HTTP, SSE, OAuth)
- Container only needs one whitelisted endpoint
- OAuth flows complete on host (browser available)
- Transparent to the user — `ddev claude` "just works"
- Proxy handles server lifecycle

**Cons:**
- Requires `mcp-proxy` installed on host (Python pip or uvx)
- Additional process running on host during sessions
- Translation layer adds small latency
- More complex implementation

**Effort:** Medium (new host script, container config generation, proxy lifecycle management)
**Coverage:** ALL MCP types ✅✅✅✅

---

### Option C: Docker MCP Gateway Sidecar

Add Docker's official [MCP Gateway](https://github.com/docker/mcp-gateway) (1,200+ stars) as a DDEV service alongside the claude container.

**Architecture:**
```yaml
# docker-compose.mcp-gateway.yaml
services:
  mcp-gateway:
    image: docker/mcp-gateway
    command: ["--port=8080", "--transport=streaming", "--servers=..."]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DOCKER_MCP_IN_CONTAINER=1
```

Claude container connects to `http://mcp-gateway:8080/mcp` over Docker network.

**Pros:**
- Official Docker solution
- Manages server lifecycle, handles secrets
- MCP Catalog integration (200+ pre-built servers)
- Container-native, runs on Docker network

**Cons:**
- **Requires Docker socket access** (grants root-equivalent host access — major security risk for a security-focused addon)
- Requires Docker Desktop with MCP Toolkit for catalog features
- Heavier dependency
- Less flexible than mcp-proxy for custom configs

**Effort:** High
**Coverage:** Full, but security tradeoff is problematic for ddev-claude's philosophy

---

### Option D: Hybrid (Option A + Selective Proxy)

Combine both approaches:
1. **Default whitelist** includes common MCP domains (Context7, Exa) for zero-config HTTP MCPs
2. **Optional `ddev claude:mcp-proxy`** command starts proxy for stdio/OAuth servers
3. **Documentation** clearly explains which MCP types work out-of-box vs. need proxy

**Pros:**
- Most users get MCP working without any setup (HTTP MCPs auto-work)
- Power users can opt into full proxy support
- Progressive disclosure of complexity
- Best security posture (whitelist only what's needed)

**Cons:**
- Two systems to maintain
- Users need to understand which approach to use

**Effort:** Medium
**Coverage:** Progressive — basic ✅ out-of-box, full ✅ with proxy opt-in

---

### Option E: Unix Socket Forwarding (Advanced)

Forward a Unix socket from host into container. Run mcp-proxy on host listening on a Unix socket, bind-mount into container.

```bash
# Host: mcp-proxy listening on Unix socket
mcp-proxy --unix-socket=/tmp/ddev-claude-mcp.sock

# Container: mount the socket
volumes:
  - /tmp/ddev-claude-mcp.sock:/tmp/mcp.sock
```

**Pros:** No network exposure at all, perfect for security model
**Cons:** mcp-proxy doesn't natively support Unix sockets (needs socat bridge), complex setup

**Effort:** High
**Coverage:** Full, but complex

## Recommended Implementation Path

### Phase 1: Quick Win (Option A) — Immediate
1. Add `mcp.context7.com` and `mcp.exa.ai` to default whitelist
2. Create `claude/config/stack-templates/mcp-common.json` with popular MCP domains
3. Document in README which MCP servers work automatically
4. Add `host.docker.internal` as opt-in via per-project whitelist (not default — security)

### Phase 2: Full Support (Option B) — Next
1. Implement `mcp-proxy` integration in `ddev claude` host command
2. Auto-detect user's MCP config and generate proxy config
3. Manage proxy lifecycle (start/stop with container session)
4. Generate container-side MCP config pointing to proxy
5. Add proxy port to firewall whitelist automatically

### Future: Consider Option D hybrid as the final architecture.

## Related Tools & Projects

| Tool | Stars | Purpose | URL |
|---|---|---|---|
| **mcp-proxy** | 2,200+ | stdio↔HTTP MCP bridge | github.com/sparfenyuk/mcp-proxy |
| **mcp-remote** | 1,200+ | stdio→HTTP with OAuth | github.com/geelen/mcp-remote |
| **Docker MCP Gateway** | 1,200+ | Docker-native MCP management | github.com/docker/mcp-gateway |
| **claude-code-mcp-docker** | ~100 | Similar project (Claude in Docker) | github.com/akr4/claude-code-mcp-docker |

## Test Environment

- **Test repo:** `/Users/florianriquelme/Repos/carnival-website/.worktrees/ddev-claude-test`
- **Project:** Laravel 8.3 + MariaDB 10.11
- **Addon status:** Fully installed
- **Project MCP config:** Empty (no per-project MCP servers)
- **Global MCP servers active:** Exa (works), Context7 (fails), Atlassian (fails), Ray App (fails)

## Environment Variable Expansion

Claude Code supports variable substitution in MCP configs:
- `${CLAUDE_PROJECT_DIR}` — Current project directory
- `${CLAUDE_PLUGIN_ROOT}` — Plugin installation directory
- Any shell environment variable: `${MY_API_KEY}`, etc.

This is relevant for container config generation — environment variables can bridge host/container path differences.

## Notes

- The `~/.claude.json` file is **mounted read-write** at `/root/.claude.json` — any changes made inside the container persist to the host
- The `~/.claude/` directory is **mounted read-write** at `/root/.claude/` — session state persists
- Project path inside container uses `${DDEV_APPROOT}` (real host path), NOT `/var/www/html`
- This means project-specific MCP config in `~/.claude.json` matches because the container path equals the host path
