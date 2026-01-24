---
created: 2026-01-24T18:15
title: Install common dev tools in Claude container with auth passthrough
area: tooling
files:
  - claude/Dockerfile.claude
  - claude/docker-compose.claude.yaml
---

## Problem

When using `ddev claude`, common development tools available on the host are missing from the container, AND their authentication state isn't passed through. This causes Claude plugin errors visible via `/doctor`:

```
Plugin Errors
 └ 2 plugin error(s) detected:
   └ beads@beads-marketplace: Plugin beads not found in marketplace beads-marketplace
   └ coderabbit@coderabbit: Plugin coderabbit not found in marketplace coderabbit
```

**Two distinct problems:**

1. **Tools not installed** - gh, coderabbit-cli, etc. missing from container image
2. **Auth state not passed** - Even if tools were installed, users would need to re-authenticate inside the container, breaking the seamless experience

Tools that need to be available with auth passthrough:
- **GitHub CLI** (`gh`) - needs `~/.config/gh/` mounted for auth tokens
- **CodeRabbit CLI** - needs its config/auth location mounted
- **beads** - investigate what this plugin actually needs
- Other common dev CLIs users might expect

## Investigation Needed

First, understand what these plugin errors actually mean:
- Are `beads@beads-marketplace` and `coderabbit@coderabbit` referring to:
  - CLI tools that need to be in PATH?
  - Claude plugins that need specific installation?
  - Something else entirely?
- Run `/doctor` locally vs in container to compare

## Solution

**Phase 1: Install tools in container**
- Update `claude/Dockerfile.claude` to install common dev tools
- GitHub CLI from GitHub's apt repo
- Determine other essential tools

**Phase 2: Pass auth state through**
- Mount host config directories into container:
  - `~/.config/gh/` → GitHub CLI auth
  - `~/.config/coderabbit/` (or wherever) → CodeRabbit auth
  - Other tool configs as needed
- Update `docker-compose.claude.yaml` with volume mounts
- Ensure permissions work (host user vs container user)

**Phase 3: Seamless experience**
- User authenticates once on host
- `ddev claude` "just works" with all their tools authenticated
- `/doctor` shows no plugin errors

Consider:
- Keep image size reasonable - don't install everything
- Document which tools are bundled and how to add more
- Security implications of mounting auth tokens into container
