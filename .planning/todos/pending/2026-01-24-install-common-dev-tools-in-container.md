---
created: 2026-01-24T18:15
title: Install common dev tools in Claude container
area: tooling
files:
  - claude/Dockerfile.claude
---

## Problem

When using `ddev claude`, common development tools available on the host are missing from the container. This causes Claude plugin errors visible via `/doctor`:

```
Plugin Errors
 └ 2 plugin error(s) detected:
   └ beads@beads-marketplace: Plugin beads not found in marketplace beads-marketplace
   └ coderabbit@coderabbit: Plugin coderabbit not found in marketplace coderabbit
```

Tools that need to be available in the container for full Claude functionality:
- **GitHub CLI** (`gh`) - for GitHub operations, PR reviews, issue management
- **CodeRabbit CLI** - for code review functionality
- **beads** - for issue tracking plugin
- Other common dev CLIs users might expect

Without these tools, Claude's plugin ecosystem is degraded inside the container.

## Solution

Update `claude/Dockerfile.claude` to install common dev tools:

1. Add GitHub CLI installation (from GitHub's apt repo)
2. Consider which other tools should be bundled vs user-configurable
3. Document how users can add custom tools if needed
4. Test `/doctor` shows clean plugin status after installation

Consider:
- Keep image size reasonable - don't install everything
- Prioritize tools that Claude plugins depend on
- May need mechanism for users to extend with their own tools
