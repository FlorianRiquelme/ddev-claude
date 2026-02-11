#!/usr/bin/env bash
set -euo pipefail

# Tear down the sandbox DDEV project and clean generated files.
# Usage: cd sandbox && bash teardown.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [ -f .ddev/config.yaml ]; then
    echo "==> Removing DDEV project..."
    ddev delete -Oy
else
    echo "==> No DDEV project found, skipping deletion."
fi

echo "==> Cleaning generated files..."
rm -rf .ddev web

echo "=== Sandbox cleaned ==="
