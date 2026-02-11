#!/usr/bin/env bats

load helpers

setup() {
  setup_base
}

teardown() {
  teardown_base
}

@test "all executable addon scripts are bash-parseable" {
  run bash -lc '
    set -euo pipefail
    cd "'"$REPO_ROOT"'"
    for f in $(find claude commands -type f | sort); do
      if head -n1 "$f" | grep -q "^#!"; then
        bash -n "$f"
      fi
    done
  '

  [ "$status" -eq 0 ]
}
