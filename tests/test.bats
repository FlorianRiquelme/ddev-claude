#!/usr/bin/env bats

setup() {
  export REPO_ROOT
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export DDEV_APPROOT="$REPO_ROOT"
  export CACHE_FILE="/tmp/ddev-claude-merged-whitelist.txt"
}

teardown() {
  rm -f "$CACHE_FILE"
}

run_hook() {
  local payload="$1"
  run bash -c 'printf "%s" "$1" | "$2"' _ "$payload" "$REPO_ROOT/claude/hooks/url-check.sh"
}

@test "allows non-network tools without output" {
  printf 'example.com\n' > "$CACHE_FILE"

  run_hook '{"tool_name":"Read","tool_input":{"file_path":"README.md"}}'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "allows WebFetch when domain is whitelisted" {
  printf 'example.com\n' > "$CACHE_FILE"

  run_hook '{"tool_name":"WebFetch","tool_input":{"url":"https://example.com/docs"}}'

  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "allow"'* ]]
}

@test "denies WebFetch when domain is not whitelisted" {
  printf 'example.com\n' > "$CACHE_FILE"

  run_hook '{"tool_name":"WebFetch","tool_input":{"url":"https://blocked.example.org/path"}}'

  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
  [[ "$output" == *'blocked.example.org'* ]]
  [[ "$output" == *'/opt/ddev-claude/bin/add-domain blocked.example.org'* ]]
}

@test "allows add-domain bash command as special case" {
  printf 'example.com\n' > "$CACHE_FILE"

  run_hook '{"tool_name":"Bash","tool_input":{"command":"/opt/ddev-claude/bin/add-domain api.example.com"}}'

  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "allow"'* ]]
}
