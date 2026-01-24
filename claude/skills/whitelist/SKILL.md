---
name: whitelist
description: Manage firewall whitelist for ddev-claude. Use when blocked requests occur or user asks about network access.
user-invocable: true
---

# Firewall Whitelist Management

You are running inside a ddev-claude container with a network firewall. Outbound traffic is blocked by default, and only whitelisted domains are allowed.

## Environment

- **Global config:** `~/.ddev/ddev-claude/whitelist.json`
- **Project config:** `/var/www/html/.ddev/ddev-claude/whitelist.json`
- **Default domains:** `/var/www/html/.ddev/claude/config/default-whitelist.json`
- **Hot reload:** Config changes apply automatically in 2-3 seconds

## Detecting Blocked Requests

When you see errors like:
- "Connection refused"
- "Could not resolve host"
- "Network is unreachable"
- "Connection timed out"

Check for blocked requests:
```bash
dmesg | grep '\[FIREWALL-BLOCK\]' | tail -10
```

Extract blocked IPs and attempt reverse DNS:
```bash
/var/www/html/.ddev/claude/scripts/parse-blocked-domains.sh
```

## Adding Domains to Whitelist

**ALWAYS ask for user confirmation before editing whitelist files.**

1. Explain why the domain is needed:
   - "I need access to api.example.com to fetch the API documentation"
   - "registry.npmjs.org is required for npm package installation"

2. Ask which config to use:
   - **Global config** for common tools (npm, composer, github)
   - **Project config** for project-specific APIs

3. After confirmation, add the domain:
```bash
# Read current domains
current=$(jq -r '.[]' ~/.ddev/ddev-claude/whitelist.json 2>/dev/null)

# Add new domain and write back
echo -e "$current\nnew-domain.com" | sort -u | grep -v '^$' | \
  jq -R -s 'split("\n") | map(select(length > 0))' > ~/.ddev/ddev-claude/whitelist.json
```

4. Confirm reload (happens automatically):
   - "Domain added. Hot reload will apply in 2-3 seconds."

## Removing Domains

```bash
# Remove a domain from project config
jq 'map(select(. != "domain-to-remove.com"))' \
  /var/www/html/.ddev/ddev-claude/whitelist.json > /tmp/whitelist.json && \
  mv /tmp/whitelist.json /var/www/html/.ddev/ddev-claude/whitelist.json
```

## Viewing Current Whitelist

Only show whitelist when explicitly asked. Don't proactively display it.

```bash
# Show merged whitelist (default + global + project)
/var/www/html/.ddev/claude/scripts/merge-whitelist.sh
```

## Stack Templates

When you detect a project type, offer to add common domains.

**Detection:**
- Laravel: `artisan` file + `composer.json` with `laravel/framework`
- npm: `package.json` exists

**Templates available at:**
- Laravel: `/var/www/html/.ddev/claude/config/stack-templates/laravel.json`
- npm: `/var/www/html/.ddev/claude/config/stack-templates/npm.json`

**Offer:**
"This appears to be a Laravel project. Would you like me to add the Laravel stack domains (packagist.org, repo.packagist.org)?"

To add a stack template:
```bash
# Merge stack template with project config
jq -s 'add | unique' \
  /var/www/html/.ddev/claude/config/stack-templates/laravel.json \
  /var/www/html/.ddev/ddev-claude/whitelist.json > /tmp/merged.json && \
  mv /tmp/merged.json /var/www/html/.ddev/ddev-claude/whitelist.json
```

## Wildcard Domains

Wildcards are supported: `*.example.com` matches all subdomains.

Note: Wildcards are resolved at firewall level. Each subdomain must be resolvable via DNS.

## Troubleshooting

**Check if firewall is active:**
```bash
iptables -L OUTPUT -n | head -5
```

**Check current ipset entries:**
```bash
ipset list whitelist_ips | tail -20
```

**Check watcher process:**
```bash
ps aux | grep watch-config
```

## Important Rules

1. **Always ask before editing** - Never modify whitelist.json without explicit user approval
2. **Explain domain purpose** - Tell users why each domain is needed
3. **Prefer project config** for project-specific APIs, global for common tools
4. **Don't proactively show whitelist** - Only display when asked
5. **Confirm success** - Tell users when domains are added and that hot reload is automatic
