---
created: 2026-01-24T18:12
title: Investigate MCP servers not working with ddev claude
area: tooling
files: []
---

## Problem

MCP (Model Context Protocol) servers are not working when using `ddev claude`. This is a **v1 release blocker**.

MCP servers enable Claude to connect to external tools and data sources (databases, APIs, file systems, etc.). Without working MCP support, users lose significant Claude functionality when running inside the ddev-claude container.

Possible causes to investigate:
- Network isolation blocking MCP server connections
- Missing environment variables or config not passed to container
- Socket/IPC issues between Claude and MCP servers
- Firewall rules blocking MCP traffic
- Container lacking required dependencies for MCP

## Solution

**Investigation plan created:** `.planning/investigations/MCP-INVESTIGATION.md`

Key hypotheses to test:
1. **stdio MCP servers** - Binaries don't exist in container (HIGH probability)
2. **HTTP MCP servers** - Blocked by firewall, need `host.docker.internal`
3. **Path translation** - Host paths in config don't map to container
4. **Missing dependencies** - Container lacks required runtimes

Recommended v1 approach:
- Pre-install common MCP npm packages in Dockerfile
- Whitelist `host.docker.internal` for HTTP MCP servers
- Document supported vs unsupported MCP configurations

See full investigation plan for detailed steps and solutions.
