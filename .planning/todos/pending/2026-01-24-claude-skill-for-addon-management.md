---
created: 2026-01-24T06:52
title: Create Claude skill for addon management
area: tooling
files:
  - .claude/commands/
  - config/whitelist.yaml
---

## Problem

Users currently need to manually configure the ddev-claude addon:
- Edit YAML files to add domains to whitelist
- Understand config file locations (global vs per-project)
- Run DDEV commands to apply changes
- Debug when things don't work

This friction reduces adoption and increases support burden. Users already have Claude Code running — it should be able to manage its own network isolation.

## Solution

Create a Claude skill (e.g., `/ddev-claude` or `/firewall`) that provides interactive addon management:

**Potential commands:**
- `/ddev-claude allow api.github.com` — Add domain to whitelist
- `/ddev-claude status` — Show current firewall rules, blocked attempts
- `/ddev-claude block <domain>` — Remove from whitelist
- `/ddev-claude config` — Show/edit configuration interactively
- `/ddev-claude logs` — View recent blocked requests
- `/ddev-claude test <domain>` — Check if a domain is reachable

**Implementation notes:**
- Skill lives in `.claude/commands/` within the addon
- When addon is installed, skill becomes available in projects using DDEV
- Skill wraps underlying DDEV/iptables commands
- Could use AskUserQuestion for confirmations ("Add api.stripe.com to whitelist?")

**Builds on:** LLM-friendly docs todo (skill can reference docs for explanations)
