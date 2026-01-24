---
created: 2026-01-24T06:50
title: Make repository LLM-friendly with comprehensive docs
area: docs
files:
  - README.md
  - .planning/PROJECT.md
---

## Problem

When a user points an LLM at this repository, it lacks the context to:

1. **Explain what ddev-claude is** — A DDEV add-on providing network isolation for Claude Code, enabling safe use of `--dangerously-skip-permissions`
2. **Articulate the value proposition** — Claude can work autonomously without constant approval prompts, while iptables firewall prevents it from reaching arbitrary external endpoints
3. **Guide installation and configuration** — Steps to add the add-on to DDEV, configure whitelisted domains, set up per-project overrides

Currently the repo has planning docs but no user-facing documentation optimized for LLM consumption.

## Solution

Create LLM-optimized documentation:

- **README.md** — Clear overview with:
  - One-sentence description
  - Problem/solution framing (why this exists)
  - Quick start (installation command)
  - Configuration examples (global + per-project)
  - Architecture summary (whitelist approach, iptables, no SSL interception)

- **docs/configuration.md** — Detailed config reference with examples

- **docs/architecture.md** — How it works technically (for curious users/LLMs)

Consider a `.claude/` or `AGENTS.md` file that LLMs specifically look for when analyzing repos.
