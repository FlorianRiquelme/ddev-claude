#!/usr/bin/env bash
set -euo pipefail

if ! command -v bats >/dev/null 2>&1; then
  echo "ERROR: bats is not installed. Install bats-core and rerun."
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bats "$repo_root/tests/test.bats"
