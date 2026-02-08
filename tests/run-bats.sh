#!/usr/bin/env bash
set -euo pipefail

# Homebrew installs on macOS may not be on PATH in non-interactive shells.
if [[ -x /opt/homebrew/bin/bats ]] && ! command -v bats >/dev/null 2>&1; then
  export PATH="/opt/homebrew/bin:$PATH"
fi

if ! command -v bats >/dev/null 2>&1; then
  echo "ERROR: bats is not installed. Install bats-core and rerun."
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bats "$repo_root/tests/test.bats"
