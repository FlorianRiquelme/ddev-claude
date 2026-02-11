#!/usr/bin/env bash
set -euo pipefail

# Reinstall ddev-claude from the local repo into the sandbox project.
# Usage: cd sandbox && bash reinstall.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$SCRIPT_DIR"

if [ ! -f .ddev/config.yaml ]; then
    echo "ERROR: No DDEV project found in sandbox/. Run setup.sh first."
    exit 1
fi

echo "==> Reinstalling ddev-claude from $REPO_ROOT..."
ddev get "$REPO_ROOT"
ddev restart

echo ""
echo "=== Reinstall complete ==="
ddev describe
