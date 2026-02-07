<!-- #ddev-generated -->
---
name: secrets
description: Manage secret file protection for ddev-claude. Use when file access is denied or user asks about secret/credential file handling.
user-invocable: true
---

# Secret File Protection

You are running inside a ddev-claude container with secret file protection. Files matching sensitive patterns (`.env`, private keys, credentials) are blocked from reading by a PreToolUse hook.

## Environment

- **Default patterns:** `$DDEV_APPROOT/.ddev/claude/config/default-denylist.json`
- **Global config:** `~/.ddev/ddev-claude/denylist.json`
- **Project config:** `$DDEV_APPROOT/.ddev/ddev-claude/denylist.json`
- **Session overrides:** `/tmp/ddev-claude-secret-override` (lost on restart)
- **Hot reload:** Config changes apply automatically in 2-3 seconds

## How Secret Blocking Works

A PreToolUse hook automatically intercepts Read, Edit, Write, and Bash tool calls and checks if the target file matches a denied pattern. If a file is blocked:

1. The hook **denies** the tool call before the file is read
2. You receive a message with the blocked file and an `exempt-secret` command
3. **Ask the user** if they'd like to grant temporary access
4. If approved, run the provided `exempt-secret` command
5. Retry the original tool call — it will succeed

**Important:** Secret protection stays active even with `--no-firewall`. The firewall is the exfiltration backstop; the hook prevents secrets from entering the context.

## Default Denied Patterns

- `.env`, `.env.*` (but NOT `.env.example`, `.env.dist`)
- `*.pem`, `*.key`, `*.p12`, `*.pfx` (TLS/SSL certificates and keys)
- `id_rsa*`, `id_ed25519*`, `id_ecdsa*`, `id_dsa*` (SSH keys)
- `*.keystore`, `*.jks` (Java keystores)
- `.npmrc`, `.netrc`, `.htpasswd`, `.pgpass` (credentials)
- `.vault-token`, `vault.yml`, `secrets.yml`, `secrets.yaml`
- `*.secret`, `*.secrets`

## Granting Temporary Access

**ALWAYS ask for user confirmation before exempting files.**

1. Explain why you need the file:
   - "I need to read `.env` to check the database configuration for debugging"
   - "The `.env.local` file may contain the API URL I need"

2. After confirmation, run the exemption command:
```bash
# Exempt a specific file path
/opt/ddev-claude/bin/exempt-secret /project/.env

# Exempt by basename (matches any path)
/opt/ddev-claude/bin/exempt-secret .env

# Exempt multiple files
/opt/ddev-claude/bin/exempt-secret .env .pgpass
```

3. Retry the original tool call — it will now succeed.

Exemptions are **session-scoped only** — they are lost when the container restarts. This is intentional for security.

## Configuring Patterns

### Denylist format

The denylist supports two formats:

**Simple array** (all patterns are deny):
```json
["custom-secret.conf", "*.credentials"]
```

**Object with deny/allow** (allow overrides deny):
```json
{
  "deny": [".env", ".env.*", "custom-secret.conf"],
  "allow": [".env.example", ".env.dist", ".env.testing"]
}
```

### Adding permanent exemptions

To permanently allow a file pattern, add it to the `allow` array in the project denylist:

```bash
# Create or update project denylist
cat > $DDEV_APPROOT/.ddev/ddev-claude/denylist.json <<'EOF'
{
  "deny": [],
  "allow": [".env.testing"]
}
EOF
```

The allow list from all tiers is merged — you don't need to repeat the default allow patterns.

### Adding custom deny patterns

```bash
# Add project-specific deny patterns
cat > $DDEV_APPROOT/.ddev/ddev-claude/denylist.json <<'EOF'
{
  "deny": ["database.yml", "credentials.json"],
  "allow": []
}
EOF
```

## Viewing Current Patterns

Only show patterns when explicitly asked.

```bash
# Show merged deny patterns
cat /tmp/ddev-claude-deny-patterns.txt

# Show merged allow patterns
cat /tmp/ddev-claude-allow-patterns.txt

# Show session overrides
cat /tmp/ddev-claude-secret-override 2>/dev/null || echo "No overrides"
```

## Important Rules

1. **Always ask before exempting** — Never run `exempt-secret` without explicit user approval
2. **Explain why you need access** — Tell users why you need each secret file
3. **Prefer alternatives** — Can you accomplish the task without reading the secret file?
4. **Session-only exemptions** — Don't promise permanent access via `exempt-secret`
5. **Permanent changes** — Direct users to edit `denylist.json` for permanent allow rules
