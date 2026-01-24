# ddev-claude

A DDEV addon that runs [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) in a sandboxed container with network isolation. Enable `--dangerously-skip-permissions` with confidence while protecting against prompt injection attacks.

## Overview

This addon creates a dedicated `claude` container with:

- **Network firewall** - Whitelist-based outbound filtering blocks unauthorized network access
- **File containment** - Only project files are accessible via container mount boundaries
- **Git tracking** - All file changes remain visible in version control

The web container remains completely unchanged.

## Requirements

- DDEV v1.24.10 or later
- Docker with NET_ADMIN capability support (verified during installation)

## Installation

```bash
ddev get florianriquelme/ddev-claude
ddev restart
```

## Authentication

Claude Code requires authentication. Choose one method:

### OAuth (Recommended)

Run the device code flow inside the container:

```bash
ddev exec -s claude claude login
```

Follow the browser prompts to complete authentication.

### API Key

Set `ANTHROPIC_API_KEY` in your project's `.ddev/.env` file:

```bash
ANTHROPIC_API_KEY=sk-ant-...
```

Then restart DDEV:

```bash
ddev restart
```

## Usage

### Basic Usage

```bash
# Run Claude with firewall protection
ddev claude

# Run with autonomous mode (firewall still active)
ddev claude --dangerously-skip-permissions

# Pass any Claude CLI arguments
ddev claude --help
```

### Firewall Bypass

When Claude needs access to a domain not in the whitelist, use the `--no-firewall` flag:

```bash
# Temporarily disable firewall for unrestricted access
ddev claude --no-firewall
```

### Customizing the Whitelist

Edit `.ddev/ddev-claude/whitelist.json` in your project:

```json
[
  "api.example.com",
  "cdn.example.com"
]
```

Restart to apply changes:

```bash
ddev restart
```

## Default Whitelist

The addon ships with a default whitelist covering common development needs:

- **Claude API**: `api.anthropic.com`, `claude.ai`
- **GitHub**: `github.com`, `api.github.com`, `raw.githubusercontent.com`
- **Package registries**: `registry.npmjs.org`, `packagist.org`, `repo.packagist.org`
- **CDNs**: `cdn.jsdelivr.net`, `unpkg.com`

## Architecture

```
┌─────────────────────────────────────────────┐
│                 DDEV Project                │
├─────────────────┬───────────────────────────┤
│   web container │       claude container    │
│   (unchanged)   │   ┌───────────────────┐   │
│                 │   │ iptables firewall │   │
│                 │   │   (default deny)  │   │
│                 │   └───────────────────┘   │
│                 │   Claude CLI + tools      │
│                 │   PHP, Node.js, Composer  │
└─────────────────┴───────────────────────────┘
```

The claude container:
- Based on `debian:bookworm-slim`
- Includes PHP, Node.js, Composer, git, curl
- Mounts project files at `/var/www/html`
- Mounts `~/.claude` for persistent configuration
- Runs with `NET_ADMIN` capability for iptables firewall

## Roadmap

**v2** will add:

- Domain access logging during `--no-firewall` sessions
- Interactive whitelist management (`ddev claude:whitelist`)
- Hot reload on whitelist config changes
- User-friendly block notifications
- `/whitelist` Claude skill for firewall-aware assistance

**Future releases:**

- Safety warnings for risky configurations
- Automatic `.env` file protection checks
- Dynamic IP refresh for CDN compatibility
- Comprehensive test suite

## Removing the Addon

```bash
ddev addon remove ddev-claude
ddev restart
```

## Contributing

Contributions are welcome. Please open an issue or pull request on GitHub.

## License

MIT License - see [LICENSE](LICENSE) for details.

---

**Maintained by:** [Florian Riquelme](https://github.com/florianriquelme)
