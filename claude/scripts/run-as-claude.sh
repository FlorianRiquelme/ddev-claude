#!/bin/bash
#ddev-generated
set -euo pipefail

CLAUDE_USER="${CLAUDE_USER:-claude}"

if command -v runuser >/dev/null 2>&1 && id -u "$CLAUDE_USER" >/dev/null 2>&1; then
    exec runuser -u "$CLAUDE_USER" -- "$@"
fi

exec "$@"
