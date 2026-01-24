# Technology Stack

**Project:** ddev-claude (DDEV addon with network firewall)
**Researched:** 2026-01-24
**Confidence:** HIGH

## Recommended Stack

### Core Technologies

| Technology | Version | Purpose | Why Recommended |
|------------|---------|---------|-----------------|
| DDEV | >= v1.24.10 | Container orchestration platform | Required base for addon ecosystem. v1.24.10+ provides `x-ddev.describe-*` extensions for custom describe output and latest docker-compose profile support |
| Bash | 5.x (via `/usr/bin/env bash`) | Scripting for install/commands | Standard scripting language for DDEV addons. Portable shebang ensures compatibility across environments. All DDEV commands use Bash |
| Docker Compose | v2 (via DDEV) | Service definition and orchestration | DDEV manages Docker Compose lifecycle. File naming pattern: `docker-compose.<service>.yaml` |
| iptables-nft | 1.8.9-2 (Debian 12) | Packet filtering inside web container | Default in Debian 12 Bookworm (DDEV web container base). Uses nftables backend while maintaining iptables syntax compatibility |
| ipset | 7.x | IP whitelist management | Efficient whitelist storage for iptables rules. Works with iptables-nft backend. Allows bulk IP operations without rule explosion |
| iptables-persistent | (via netfilter-persistent) | Firewall rule persistence | Debian standard for persisting iptables rules across container restarts. Auto-restores rules from `/etc/iptables/rules.v4` |

### Supporting Tools

| Tool | Version | Purpose | When to Use |
|------|---------|---------|-------------|
| shellcheck | Latest | Static analysis for shell scripts | REQUIRED: All Bash scripts must pass shellcheck validation. Run in CI pipeline. Catches subtle bugs before runtime |
| shfmt | Latest | Shell script formatter | RECOMMENDED: Auto-format scripts for consistency. Use `-i 2 -ci` for 2-space indent and case indent |
| bats-core | Latest | Bash testing framework | REQUIRED: Standard testing framework for DDEV addons. Used in `.github/workflows/tests.yml` |
| bats-support | Latest | Test helper library | REQUIRED: Provides assertion helpers for bats tests |
| bats-assert | Latest | Assertion library | REQUIRED: Provides readable assertions like `assert_output` and `assert_success` |
| bats-file | Latest | File assertion library | RECOMMENDED: Provides file-specific assertions for testing file creation/modification |
| yq | Latest (if needed) | YAML processing in scripts | OPTIONAL: For complex YAML manipulation in pre/post-install actions. DDEV provides Go templating for most cases |

### Container Capabilities

| Capability | Purpose | Notes |
|------------|---------|-------|
| NET_ADMIN | iptables/network interface manipulation | REQUIRED: Allows iptables rule creation and network interface configuration inside web container |
| NET_RAW | Raw socket access (ping, traceroute) | OPTIONAL: Not strictly required for iptables, but useful for debugging network issues |

## DDEV Addon Structure

### Required Files

```
.ddev/
├── install.yaml                          # Addon metadata and installation instructions
├── docker-compose.claude-firewall.yaml   # Service definition with capabilities
├── commands/
│   ├── web/
│   │   ├── claude                        # Main command (runs in web container)
│   │   └── claude-init                   # Firewall initialization
│   └── host/
│       └── claude:blocked                # Host-side command for blocked requests
├── config/
│   └── claude/
│       ├── whitelist.yaml                # IP whitelist configuration
│       └── iptables.rules.template       # iptables rules template
└── scripts/
    ├── install-firewall.sh               # Pre-install setup
    └── cleanup-firewall.sh               # Removal cleanup
```

### install.yaml Structure

```yaml
name: ddev-claude
ddev_version_constraint: '>= v1.24.10'

pre_install_actions:
  - |
    #ddev-description:Checking system requirements
    set -euo pipefail
    # Check for required base packages in DDEV web container

project_files:
  - docker-compose.claude-firewall.yaml
  - commands/web/claude
  - commands/web/claude-init
  - commands/host/claude:blocked
  - config/claude/whitelist.yaml
  - scripts/install-firewall.sh
  - scripts/cleanup-firewall.sh

post_install_actions:
  - |
    #ddev-description:Installing iptables and ipset
    ddev exec sudo apt-get update
    ddev exec sudo apt-get install -y iptables ipset iptables-persistent
  - |
    #ddev-description:Initializing firewall rules
    ddev claude-init

removal_actions:
  - |
    #ddev-description:Cleaning up firewall rules
    ddev exec bash /var/www/html/.ddev/scripts/cleanup-firewall.sh || true
  - |
    #ddev-description:Removing iptables packages
    ddev exec sudo apt-get remove -y iptables-persistent ipset || true
```

### docker-compose Configuration

```yaml
# docker-compose.claude-firewall.yaml
services:
  web:
    cap_add:
      - NET_ADMIN
    # NET_RAW not strictly required for iptables, add if needed for debugging
    environment:
      - CLAUDE_FIREWALL_ENABLED=1
    volumes:
      - ./config/claude:/etc/claude:ro
      - ./scripts:/usr/local/bin/claude-scripts:ro
```

## Shell Scripting Standards

### Error Handling

All Bash scripts MUST start with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Why each option:**
- `set -e`: Exit immediately on any command failure (errexit)
- `set -u`: Exit on undefined variable references (nounset)
- `set -o pipefail`: Return exit status of first failed command in pipeline
- `/usr/bin/env bash`: Portable shebang (works across different environments)

### Script Headers (DDEV Commands)

```bash
#!/usr/bin/env bash

## Description: Run Claude CLI with network sandboxing
## Usage: claude [args]
## Example: "ddev claude --help"

set -euo pipefail
```

### ShellCheck Configuration

Create `.shellcheckrc`:

```
# Disable SC2086 (double quote to prevent globbing) when intentional
# disable=SC2086

# Enable all optional checks
enable=all
```

Run shellcheck on all scripts:

```bash
shellcheck .ddev/commands/**/* .ddev/scripts/*.sh
```

## iptables Architecture

### Rule Chain Strategy

Use DOCKER-USER chain for custom rules:

```bash
# DOCKER-USER chain processes BEFORE Docker's DOCKER-FORWARD chain
# This gives our firewall rules priority

# Create ipset for whitelist
ipset create claude-whitelist hash:net

# Add rule to DOCKER-USER chain
iptables -I DOCKER-USER -m set ! --match-set claude-whitelist src -j DROP
```

**Why DOCKER-USER:**
- Processes before Docker's automatic rules
- Rules appended to FORWARD chain are processed AFTER Docker rules (too late)
- Survives Docker restarts (when persisted)

### iptables-nft vs iptables-legacy

Debian 12 uses iptables-nft by default (iptables syntax with nftables backend).

**For this addon:**
- Use standard `iptables` commands (auto-routes to iptables-nft)
- NO need to explicitly use `iptables-nft` binary
- Compatibility managed by Debian's update-alternatives

**DO NOT:**
- Mix iptables-nft and iptables-legacy (rules won't coexist)
- Assume pure nftables (users expect iptables syntax)

### Persistence Strategy

```bash
# Save rules after creation
iptables-save > /etc/iptables/rules.v4

# Auto-restore on container start
# iptables-persistent handles this via systemd/init

# For ipset persistence
ipset save > /etc/iptables/ipsets
# Restore in startup script
ipset restore < /etc/iptables/ipsets
```

## Testing Framework

### Bats Test Structure

```bash
# tests/test.bats
setup() {
  set -eu -o pipefail
  export DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" >/dev/null 2>&1 && pwd)"
  export TESTDIR=~/tmp/test-ddev-claude
  mkdir -p $TESTDIR
  cd $TESTDIR
  ddev config --project-type=php --project-name=test-claude
  ddev start -y
  ddev add-on get ddev/ddev-claude
}

teardown() {
  set -eu -o pipefail
  cd $TESTDIR || true
  ddev delete -Oy || true
  rm -rf $TESTDIR
}

@test "firewall blocks non-whitelisted IPs" {
  run ddev exec iptables -L DOCKER-USER -n
  assert_success
  assert_output --partial "claude-whitelist"
}

@test "claude command executes" {
  run ddev claude --help
  assert_success
}
```

### GitHub Actions CI

```yaml
# .github/workflows/tests.yml
name: tests
on:
  pull_request:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ddev/github-action-add-on-test@v2
        with:
          addon_path: .
          addon_name: ddev-claude
```

## Alternatives Considered

| Category | Recommended | Alternative | When to Use Alternative |
|----------|-------------|-------------|-------------------------|
| Firewall | iptables-nft | Pure nftables | If DDEV moves to nftables-only in future. More complex syntax, less familiar |
| Testing | bats-core | shunit2 | Never for DDEV addons. Bats is ecosystem standard |
| IP storage | ipset | Individual iptables rules | Never. 100+ IPs = 100+ rules = performance nightmare |
| Persistence | iptables-persistent | Custom save/restore scripts | Only if iptables-persistent unavailable. More error-prone |
| Scripting | Bash | Python/PHP (via install.yaml) | Complex YAML manipulation or cross-platform logic. Overkill for iptables commands |

## What NOT to Use

| Avoid | Why | Use Instead |
|-------|-----|-------------|
| iptables-legacy | Deprecated in Debian 12. Incompatible with iptables-nft rules | iptables (auto-routes to iptables-nft) |
| `#!/bin/bash` shebang | Not portable across systems where bash is in different locations | `#!/usr/bin/env bash` |
| Unquoted variables | ShellCheck SC2086. Causes word splitting and globbing bugs | Always quote: `"$VARIABLE"` |
| `&&` chains without `set -e` | Silent failures in middle of chain | Use `set -e` and separate commands |
| Direct editing of generated files | DDEV overwrites `.ddev/.ddev-docker-compose-*.yaml` on every start | Use `docker-compose.<service>.yaml` or override files |
| Removing `#ddev-generated` marker | Breaks addon removal, prevents clean updates | Use `.ddev/docker-compose.<service>_extra.yaml` for overrides |
| Docker privileged mode | Excessive permissions. Security risk | Use specific capabilities: `cap_add: [NET_ADMIN]` |

## Version Compatibility

| Package | Compatible With | Notes |
|---------|-----------------|-------|
| DDEV v1.24.10+ | Docker Engine v28.5.2+ | Docker v28 introduced container networking hardening (Feb 2025) |
| iptables-nft 1.8.9 | Debian 12 Bookworm | DDEV web container base image |
| ipset 7.x | iptables-nft backend | Works transparently with nftables backend |
| bats-core latest | DDEV GitHub Actions | ddev/github-action-add-on-test@v2 includes bats |

## Installation (Development)

```bash
# Install shellcheck and shfmt for local development
# macOS
brew install shellcheck shfmt

# Debian/Ubuntu
sudo apt-get install shellcheck
go install mvdan.cc/sh/v3/cmd/shfmt@latest

# Install bats for local testing
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local

# Install bats libraries
git clone https://github.com/bats-core/bats-support.git ~/.bats/bats-support
git clone https://github.com/bats-core/bats-assert.git ~/.bats/bats-assert
git clone https://github.com/bats-core/bats-file.git ~/.bats/bats-file
```

## Stack Patterns by Variant

**If modifying existing DDEV web container (recommended for ddev-claude):**
- Use `services: web:` override in docker-compose file
- Install packages via `post_install_actions` in install.yaml
- Commands in `.ddev/commands/web/` run inside web container
- Firewall rules apply to web container's network namespace

**If creating separate service container:**
- Use `services: <new-service>:` in docker-compose file
- Container name: `ddev-${DDEV_SITENAME}-<servicename>`
- Mount `/mnt/ddev-global-cache` for custom command support
- More complex but better isolation

**For ddev-claude: Modifying web container is correct approach** because:
- Claude CLI runs in web container (needs web container's PHP/Composer)
- Firewall must filter web container's outbound traffic
- Simpler architecture (no inter-container networking complexity)

## Confidence Assessment

| Area | Level | Source |
|------|-------|--------|
| DDEV addon structure | HIGH | Official docs, template repository |
| Docker capabilities | HIGH | Official Docker docs, Debian documentation |
| iptables-nft | HIGH | Debian 12 documentation, docker networking docs |
| Bash best practices | HIGH | Multiple authoritative sources, shellcheck documentation |
| Testing framework | HIGH | Official DDEV addon template and CI examples |
| ipset persistence | MEDIUM | Community articles verified against official docs. Needs testing in DDEV context |

## Sources

### Official Documentation
- [DDEV Creating Add-ons](https://docs.ddev.com/en/stable/users/extend/creating-add-ons/) — Addon structure and install.yaml
- [DDEV Custom Commands](https://docs.ddev.com/en/stable/users/extend/custom-commands/) — Command directory structure
- [DDEV Custom Docker Compose](https://docs.ddev.com/en/stable/users/extend/custom-compose-files/) — Service configuration
- [DDEV Add-on Template](https://github.com/ddev/ddev-addon-template) — Official template repository
- [Docker Firewall iptables](https://docs.docker.com/engine/network/firewall-iptables/) — DOCKER-USER chain
- [Docker Packet Filtering](https://docs.docker.com/engine/network/packet-filtering-firewalls/) — Networking security
- [Debian nftables Wiki](https://wiki.debian.org/nftables) — iptables-nft backend information

### Technical References
- [DDEV Add-on Maintenance Guide](https://ddev.com/blog/ddev-add-on-maintenance-guide/) — Best practices (Nov 2025)
- [DDEV Advanced Add-on Techniques](https://ddev.com/blog/advanced-add-on-contributor-training/) — Advanced patterns
- [Docker Engine v28 Security](https://www.docker.com/blog/docker-engine-28-hardening-container-networking-by-default/) — Container networking hardening (Feb 2025)
- [ShellCheck](https://www.shellcheck.net/) — Shell script analysis tool
- [Bash Best Practices 2025](https://medium.com/@prasanna.a1.usage/best-practices-we-need-to-follow-in-bash-scripting-in-2025-cebcdf254768) — Error handling patterns

### Community Resources
- [ipset with Docker](https://medium.com/@udomsak/simple-secure-you-staging-docker-environment-with-ipset-and-iptables-aafb679f9a7a) — Firewall patterns
- [iptables-persistent on Debian 12](https://linux-packages.com/debian-12-bookworm/package/iptables) — Package version info
- [Bash Error Handling 2025](https://dev.to/rociogarciavf/how-to-handle-errors-in-bash-scripts-in-2025-3bo) — set -euo pipefail

---
*Stack research for: ddev-claude*
*Researched: 2026-01-24*
*Confidence: HIGH*
