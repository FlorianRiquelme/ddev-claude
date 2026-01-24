# Architecture Research

**Domain:** DDEV Add-on with Container Modifications (Network Firewall)
**Researched:** 2026-01-24
**Confidence:** HIGH

## Standard Architecture

### DDEV Add-on Component Structure

```
┌─────────────────────────────────────────────────────────────┐
│                   Add-on Installation                        │
│  ┌──────────────────┐  ┌──────────────────┐                 │
│  │   install.yaml   │  │  README.md       │                 │
│  │  (manifest)      │  │  (docs)          │                 │
│  └────────┬─────────┘  └──────────────────┘                 │
│           │                                                  │
├───────────┴──────────────────────────────────────────────────┤
│              Build-Time Components                           │
│  ┌────────────────────┐  ┌─────────────────────────┐        │
│  │  web-build/        │  │  docker-compose.*.yaml  │        │
│  │  ├─ Dockerfile.*   │  │  (service definitions)  │        │
│  │  └─ config files   │  └─────────────────────────┘        │
│  └────────────────────┘                                      │
│           │                       │                          │
├───────────┴───────────────────────┴──────────────────────────┤
│              Runtime Components                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │  commands/   │  │  config/     │  │  hooks/      │       │
│  │  web/        │  │  *.yaml      │  │  scripts     │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Responsibility | Typical Implementation |
|-----------|----------------|------------------------|
| **install.yaml** | Installation manifest and lifecycle orchestration | YAML with pre/post hooks, file lists, dependencies |
| **web-build/Dockerfile** | Container image customization | Dockerfile extending `$BASE_IMAGE` with apt packages, scripts |
| **docker-compose.*.yaml** | Service definition and overrides | YAML extending/adding services, volumes, capabilities |
| **commands/web/** | Custom CLI commands | Bash scripts with DDEV annotations |
| **config/*.yaml** | DDEV configuration overrides | YAML fragments merged into config.yaml |
| **hooks/** | Lifecycle event handlers | Bash/PHP scripts for web-entrypoint.d, post-start, etc. |

## Recommended Project Structure

Based on [DDEV addon template](https://github.com/ddev/ddev-addon-template) and [official documentation](https://docs.ddev.com/en/stable/users/extend/creating-add-ons/):

```
ddev-claude/
├── .github/
│   └── workflows/
│       └── tests.yml          # CI/CD for addon testing
├── tests/
│   ├── test.bats              # BATS testing framework
│   └── testdata/              # Test fixtures
├── web-build/
│   └── Dockerfile.ddev-claude # Custom image extensions
├── commands/
│   └── web/
│       └── sandbox-init       # Runtime firewall commands
├── docker-compose.ddev-claude.yaml  # Service overrides (capabilities)
├── install.yaml               # Installation manifest
├── config.ddev-claude.yaml    # Optional config overrides
├── README.md                  # User documentation
└── LICENSE                    # Apache-2.0 recommended
```

### Structure Rationale

- **web-build/:** Container customization at build time (iptables, firewall tools installation)
- **commands/web/:** User-facing CLI for runtime operations (init/status/disable firewall)
- **docker-compose.*.yaml:** Service-level overrides (NET_ADMIN capability, privileged mode if needed)
- **install.yaml:** Orchestrates installation order, validates DDEV version, runs setup scripts
- **tests/:** BATS framework for automated testing per DDEV standards
- **.github/workflows/:** Continuous integration following DDEV ecosystem patterns

## Architectural Patterns

### Pattern 1: Dockerfile Extension (Build-Time Customization)

**What:** Add a `.ddev/web-build/Dockerfile.<addon-name>` to modify the base DDEV web container image.

**When to use:** When you need to install packages, tools, or modify the container filesystem before runtime.

**Trade-offs:**
- **Pro:** Changes are baked into image, persist across restarts
- **Pro:** Access to build-time variables (`$DDEV_PHP_VERSION`, `$BASE_IMAGE`, `$TARGETARCH`)
- **Con:** Requires rebuild (`ddev restart` or `ddev utility rebuild`) to apply changes
- **Con:** Project code not available during build (only at runtime)

**Example:**
```dockerfile
# .ddev/web-build/Dockerfile.ddev-claude

# Install iptables for firewall functionality
RUN apt-get update && apt-get install -y --no-install-recommends \
    iptables \
    iputils-ping \
    net-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Add initialization script
COPY web-build/sandbox-init.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/sandbox-init.sh
```

**Available build variables:**
- `$BASE_IMAGE`: Base image reference (e.g., `ddev/ddev-webserver:v1.24.0`)
- `$DDEV_PHP_VERSION`: Configured PHP version
- `$TARGETARCH`: Target architecture (`arm64` or `amd64`)
- `$username`, `$uid`, `$gid`: Host user information

**Processing order:**
1. `prepend.Dockerfile*` (before generated content, multi-stage builds)
2. `pre.Dockerfile*` (early insertion, proxy/SSL settings)
3. `Dockerfile` and `Dockerfile.*` (alphabetical, after main build)

Source: [Customizing DDEV Images](https://docs.ddev.com/en/stable/users/extend/customizing-images/)

### Pattern 2: Docker Compose Override (Service-Level Capabilities)

**What:** Add `docker-compose.<addon-name>.yaml` to modify service definitions, especially for privileged operations.

**When to use:** When you need special Docker capabilities, network settings, or volume mounts.

**Trade-offs:**
- **Pro:** No rebuild required, takes effect on `ddev restart`
- **Pro:** Can add capabilities without rebuilding images
- **Con:** Capabilities granted at runtime, security implications
- **Con:** Must understand Docker Compose merge semantics

**Example:**
```yaml
# docker-compose.ddev-claude.yaml

services:
  web:
    cap_add:
      - NET_ADMIN        # Required for iptables modifications
    # Alternative: privileged: true (grants all capabilities, less secure)
    environment:
      - DDEV_CLAUDE_SANDBOX_ENABLED=true
```

**Merge behavior:**
- DDEV processes all `docker-compose.*.yaml` files alphabetically
- Later files override earlier ones for scalar values
- Arrays and objects are merged (can extend existing definitions)
- Verify merged result: `ddev utility compose-config`

**For addon-specific overrides:**
Create `docker-compose.<addon>_extra.yaml` for user customizations that won't be overwritten.

Source: [Docker Compose Files](https://docs.ddev.com/en/stable/users/extend/custom-compose-files/)

### Pattern 3: Install Lifecycle Hooks (Pre/Post Actions)

**What:** Use `pre_install_actions` and `post_install_actions` in `install.yaml` to run scripts during addon installation.

**When to use:** For validation, initial setup, file generation, or user prompts during `ddev get` installation.

**Trade-offs:**
- **Pro:** Runs once at install time, can validate environment
- **Pro:** Can prompt user for configuration (tokens, settings)
- **Con:** Not re-run on project start (use post-start hooks for that)
- **Con:** Pre-install runs before files are copied (limited context)

**Example:**
```yaml
# install.yaml

name: ddev-claude

pre_install_actions:
  # Bash action - runs on host
  - |
    #ddev-description:Validating DDEV version
    if [ "$(ddev version | grep 'DDEV version' | cut -d' ' -f3)" \< "v1.24.0" ]; then
      echo "Error: ddev-claude requires DDEV v1.24.0+"
      exit 1
    fi

project_files:
  - web-build/
  - commands/
  - docker-compose.ddev-claude.yaml

post_install_actions:
  # PHP action - better for cross-platform
  - |
    #ddev-description:Creating firewall configuration
    <?php
    $configPath = '.ddev/config.ddev-claude.yaml';
    $config = [
      'allowed_hosts' => [
        'api.anthropic.com',
        'cdn.jsdelivr.net'
      ]
    ];
    file_put_contents($configPath, yaml_emit($config));
    ?>

ddev_version_constraint: '>= v1.24.0'
```

**Action types:**
- **Bash:** File permissions, system commands, environment checks (host-side)
- **PHP:** YAML manipulation, cross-platform compatibility, conditional logic

**Available variables:**
- `$DDEV_PROJECT`: Project name
- `$DDEV_PROJECT_TYPE`: CMS type (drupal, wordpress, etc.)
- `$DDEV_PHP_VERSION`: PHP version
- `$DDEV_UID`/`$DDEV_GID`: User/group IDs

Source: [Creating Add-ons](https://docs.ddev.com/en/stable/users/extend/creating-add-ons/)

### Pattern 4: Custom Commands (User Interface)

**What:** Bash scripts in `.ddev/commands/<container>/` that become `ddev <command>` CLI tools.

**When to use:** For user-facing operations that need to run inside containers.

**Trade-offs:**
- **Pro:** Natural DDEV CLI integration
- **Pro:** Access to container environment and tools
- **Con:** Must follow strict annotation format
- **Con:** Filename vs command name can be confusing (name comes from `## Usage:`)

**Example:**
```bash
#!/usr/bin/env bash

## Description: Initialize Claude Code sandbox firewall
## Usage: claude-sandbox-init
## Example: "ddev claude-sandbox-init"
## ExecRaw: true
## AutocompleteTerms: ["--reset","--status"]

set -euo pipefail

case "${1:-}" in
  --status)
    iptables -L OUTPUT -n --line-numbers
    ;;
  --reset)
    iptables -F OUTPUT
    ;;
  *)
    # Initialize default firewall rules
    iptables -P OUTPUT ACCEPT
    iptables -F OUTPUT

    # Block all except allowed hosts
    iptables -A OUTPUT -d api.anthropic.com -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
    iptables -A OUTPUT -j REJECT

    echo "Firewall initialized. Only api.anthropic.com accessible."
    ;;
esac
```

**Key annotations:**
- `## Description:` Brief explanation (shown in `ddev -h`)
- `## Usage:` **Command name** (this is what users type, not filename)
- `## Example:` Help text example
- `## ExecRaw: true` Pass arguments directly (recommended for container commands)
- `## AutocompleteTerms:` Tab completion options
- `## ProjectTypes:` Limit to specific CMS types
- `## OSTypes:` Limit to specific operating systems

**Environment variables in commands:**
- `DDEV_APPROOT`: Project path (container or host)
- `DDEV_DOCROOT`: Document root relative path
- `DDEV_PRIMARY_URL`: Main project URL
- `IS_DDEV_PROJECT=true`: Flag for detection

Source: [Custom Commands](https://docs.ddev.com/en/stable/users/extend/custom-commands/)

## Data Flow

### Addon Installation Flow

```
User: ddev get <addon-repo>
    ↓
[DDEV CLI] → Download install.yaml
    ↓
[Pre-Install Actions] (bash/PHP on host)
    ├─ Validate DDEV version
    ├─ Check dependencies
    └─ Prompt for configuration
    ↓
[Copy Files]
    ├─ project_files → .ddev/
    └─ global_files → ~/.ddev/
    ↓
[Post-Install Actions] (bash/PHP in .ddev context)
    ├─ Generate config files
    ├─ Run setup scripts
    └─ Display next steps
    ↓
[Dependency Resolution]
    └─ Auto-install dependencies (unless --skip-deps)
```

### Container Build & Startup Flow

```
User: ddev start
    ↓
[Config Loading]
    ├─ Read config.yaml (project)
    ├─ Merge config.*.yaml fragments
    └─ Load environment overrides
    ↓
[Image Build] (if needed)
    ├─ Process prepend.Dockerfile*
    ├─ Process pre.Dockerfile*
    ├─ DDEV's generated Dockerfile
    ├─ Process Dockerfile and Dockerfile.* (alphabetically)
    └─ Build image with build args ($DDEV_PHP_VERSION, etc.)
    ↓
[Docker Compose Generation]
    ├─ Generate .ddev-docker-compose-base.yaml
    ├─ Merge docker-compose.*.yaml files (alphabetically)
    └─ Write .ddev-docker-compose-full.yaml
    ↓
[Container Launch]
    ├─ Start ddev-router (global)
    ├─ Start ddev-ssh-agent (global)
    ├─ Start project containers (web, db, services)
    └─ Apply capabilities (NET_ADMIN, etc.)
    ↓
[Web Container Initialization]
    ├─ Run web-entrypoint.d scripts
    ├─ Execute post-start hooks
    └─ Start nginx + PHP-FPM
```

Source: [DDEV Architecture](https://docs.ddev.com/en/stable/users/usage/architecture/)

### Runtime Command Execution

```
User: ddev claude-sandbox-init
    ↓
[DDEV CLI] → Parse command annotations
    ↓
[Container Selection] → web (from commands/web/)
    ↓
[Execute in Container]
    ├─ Access DDEV_* environment variables
    ├─ Run bash script with iptables
    └─ Return output to host
```

### Key Data Flows

1. **Build-time customization:** `web-build/Dockerfile.*` → Docker build → Modified image → Container startup
2. **Configuration cascade:** Global `.ddev` → Project `.ddev` → Environment-specific `config.*.yaml` → Merged config
3. **Service capabilities:** `docker-compose.*.yaml` (cap_add: NET_ADMIN) → Docker daemon → Container capabilities → iptables access
4. **Command execution:** `ddev <command>` → Container execution → Script runs with DDEV env vars → Output returns to host

## Scaling Considerations

| Scale | Architecture Adjustments |
|-------|--------------------------|
| Single developer | Simple addon structure; Dockerfile + docker-compose + single command |
| Team (5-20 devs) | Add config validation; version constraints; better error messages |
| Multi-project | Move to global_files for shared configs; consider ddev-dotenv for secrets |
| Organization-wide | Publish to DDEV addon registry; comprehensive testing; semantic versioning |

### Scaling Priorities

1. **First bottleneck:** Build time increases with complex Dockerfiles
   - **Fix:** Use multi-stage builds, cache layers, minimal RUN commands
2. **Second bottleneck:** Merge conflicts in docker-compose files
   - **Fix:** Use `*_extra.yaml` pattern for user customization, document override behavior

## Anti-Patterns

### Anti-Pattern 1: Editing Generated Files

**What people do:** Modify `.ddev/.ddev-docker-compose-base.yaml` or `.ddev/.ddev-docker-compose-full.yaml` directly.

**Why it's wrong:** DDEV regenerates these files on every `ddev start`, erasing changes. Documented in [Docker Compose Files](https://docs.ddev.com/en/stable/users/extend/custom-compose-files/).

**Do this instead:** Create `docker-compose.<name>.yaml` in `.ddev/` directory. DDEV merges all `docker-compose.*.yaml` files automatically.

### Anti-Pattern 2: Using `privileged: true` for Minimal Capabilities

**What people do:** Set `privileged: true` in docker-compose to get one capability (like NET_ADMIN).

**Why it's wrong:** Grants all Linux capabilities, major security risk. From [Docker capabilities documentation](https://dockerlabs.collabnix.com/advanced/security/capabilities/), privileged mode removes all isolation.

**Do this instead:** Use minimal `cap_add` for specific capabilities:
```yaml
services:
  web:
    cap_add:
      - NET_ADMIN  # Only what you need
```

### Anti-Pattern 3: Installing Tools at Runtime (Not Build Time)

**What people do:** Run `apt-get install` in post-start hooks or commands.

**Why it's wrong:** Slows every startup, downloads fail if offline, ephemeral (lost on rebuild).

**Do this instead:** Install in `web-build/Dockerfile.*` so tools are baked into image:
```dockerfile
RUN apt-get update && apt-get install -y iptables \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
```

### Anti-Pattern 4: Ignoring `#ddev-generated` Markers

**What people do:** Modify addon files without `#ddev-generated` marker, expecting them to be safe.

**Why it's wrong:** Files with `#ddev-generated` are replaced on addon updates. Without the marker, they're preserved but cause upgrade conflicts.

**Do this instead:**
- Add `#ddev-generated` to all addon-provided files
- Document override pattern using `*_extra.yaml` or `config.*.yaml` for user customizations

### Anti-Pattern 5: Assuming Code Availability During Build

**What people do:** Try to run `npm install /var/www/html` in Dockerfile.

**Why it's wrong:** Project code isn't mounted during image build. From [Customizing Images](https://docs.ddev.com/en/stable/users/extend/customizing-images/): "Remember that the Dockerfile is building a Docker image that will be used later with DDEV."

**Do this instead:** Install global tools in Dockerfile, run project-specific commands in post-start hooks when code is mounted.

## Integration Points

### External Services

| Service | Integration Pattern | Notes |
|---------|---------------------|-------|
| DDEV Router | Automatic (global container) | Reverse proxy, no addon action needed unless custom ports |
| SSH Agent | Via `ddev-ssh-agent` container | Shared across projects after `ddev auth ssh` |
| Docker Daemon | Via docker-compose config | Addon defines services, capabilities, volumes |
| Host Filesystem | Volume mounts | Project code at `/var/www/html`, DDEV global cache at `/mnt/ddev-global-cache` |

### Internal Boundaries

| Boundary | Communication | Notes |
|----------|---------------|-------|
| install.yaml ↔ Docker Compose | File copying | install.yaml lists files, DDEV copies them before compose processing |
| Dockerfile ↔ Container Runtime | Image build | Dockerfile runs at build time, results persist in image |
| Commands ↔ Web Container | Exec API | Commands run in container via `docker exec`, access runtime environment |
| Pre-install ↔ Post-install | File system state | Pre-install runs on host before files exist in `.ddev`, post-install runs after |
| Global ↔ Project configs | Cascade merge | Global `~/.ddev` loaded first, project `.ddev` overrides |

## Recommended Build Order for ddev-claude

Based on DDEV addon architecture, suggested implementation order:

### Phase 1: Minimal Viable Addon (Foundation)
**Build order:**
1. `install.yaml` (manifest with minimal pre/post hooks)
2. `README.md` (documentation first, clarifies scope)
3. `docker-compose.ddev-claude.yaml` (NET_ADMIN capability)
4. `tests/test.bats` (basic install/uninstall test)

**Why this order:** Establishes addon structure that DDEV can install. Validates capability granting works before building complex Dockerfile.

### Phase 2: Container Customization
**Build order:**
1. `web-build/Dockerfile.ddev-claude` (install iptables, tools)
2. Test rebuild: `ddev restart`
3. Verify tools available: `ddev exec which iptables`

**Why this order:** Build on Phase 1's working addon. Image customization requires capability from Phase 1 to be useful.

### Phase 3: Runtime Interface
**Build order:**
1. `web-build/sandbox-init.sh` (firewall initialization script)
2. `commands/web/claude-sandbox-init` (user-facing command)
3. `commands/web/claude-sandbox-status` (status checking)
4. Update install.yaml `post_install_actions` to call init script

**Why this order:** Script before command (command calls script). Both depend on Phase 2's iptables installation.

### Phase 4: Configuration & Polish
**Build order:**
1. `config.ddev-claude.yaml` (allowed hosts configuration)
2. Enhanced `install.yaml` (version constraints, better messages)
3. Comprehensive `tests/test.bats` (test all commands, firewall rules)
4. `.github/workflows/tests.yml` (CI/CD)

**Why this order:** Configuration informs command behavior. Testing validates everything works. CI prevents regressions.

**Dependencies:**
- Phase 2 depends on Phase 1 (needs capability granted)
- Phase 3 depends on Phase 2 (needs iptables installed)
- Phase 4 depends on Phase 3 (needs commands to test)

**Critical path:** install.yaml → docker-compose.yaml (capabilities) → Dockerfile (tools) → commands (interface)

## Sources

**Official DDEV Documentation:**
- [Creating DDEV Add-ons](https://docs.ddev.com/en/stable/users/extend/creating-add-ons/)
- [Customizing Docker Images](https://docs.ddev.com/en/stable/users/extend/customizing-images/)
- [Custom Commands](https://docs.ddev.com/en/stable/users/extend/custom-commands/)
- [Docker Compose Files](https://docs.ddev.com/en/stable/users/extend/custom-compose-files/)
- [DDEV Architecture](https://docs.ddev.com/en/stable/users/usage/architecture/)

**DDEV Blog & Guides:**
- [Advanced Add-on Contributor Training](https://ddev.com/blog/advanced-add-on-contributor-training/)
- [DDEV Add-on Maintenance Guide](https://ddev.com/blog/ddev-add-on-maintenance-guide/)
- [Customizing DDEV Images with a Custom Dockerfile](https://ddev.com/blog/customizing-ddev-local-images-with-a-custom-dockerfile/)

**GitHub Resources:**
- [ddev-addon-template](https://github.com/ddev/ddev-addon-template) - Official template
- [ddev-addon-template install.yaml](https://github.com/ddev/ddev-addon-template/blob/main/install.yaml) - Installation manifest example

**Docker Security:**
- [Docker Capabilities](https://dockerlabs.collabnix.com/advanced/security/capabilities/)
- [CAP_NET_ADMIN for non-root user in Docker container](https://marcoguerri.github.io/2023/10/13/capabilities-and-docker.html)

**Community Examples:**
- [ddev-laravel-queue](https://github.com/tyler36/ddev-laravel-queue) - Web container extension pattern
- [DDEV Add-on Registry](https://addons.ddev.com/) - Official and community addons

---
*Architecture research for: DDEV Add-on with Network Firewall*
*Researched: 2026-01-24*
