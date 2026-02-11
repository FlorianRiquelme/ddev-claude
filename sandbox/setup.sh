#!/usr/bin/env bash
set -euo pipefail

# Bootstrap a minimal DDEV project for testing ddev-claude locally.
# Usage: cd sandbox && bash setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$SCRIPT_DIR/.ddev/config.yaml" ]; then
    echo "DDEV project already exists in sandbox/. To reset: ddev delete -Oy && rm -rf .ddev && bash setup.sh"
    exit 0
fi

echo "==> Creating minimal DDEV project..."
cd "$SCRIPT_DIR"

# Create a dummy index.php so DDEV has something to serve
mkdir -p web
echo '<?php echo "ddev-claude sandbox";' > web/index.php

# Initialize DDEV project
ddev config --project-name=claude-sandbox --project-type=php --docroot=web

echo "==> Installing ddev-claude from local repo..."
ddev get "$REPO_ROOT"
ddev restart

echo ""
echo "=== Sandbox ready ==="
echo "  ddev claude                          # Run Claude with firewall"
echo "  ddev claude --no-firewall            # Run without firewall"
echo "  ddev claude:whitelist                # Manage whitelist"
echo "  ddev exec -s claude iptables -L -n   # Inspect firewall rules"
echo ""
echo "After making changes to the addon, reinstall with:"
echo "  ddev get $REPO_ROOT && ddev restart"
