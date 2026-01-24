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

TBD - Requires investigation:

1. Reproduce the issue with a known MCP server
2. Check Claude's MCP connection logs/errors
3. Determine if network, config, or dependency issue
4. Implement fix and verify MCP servers work
