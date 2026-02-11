#!/usr/bin/env bats

load helpers

setup() {
  setup_base
  make_test_approot
  export CACHE_FILE="/tmp/ddev-claude-merged-whitelist.txt"
  export DENY_CACHE="/tmp/ddev-claude-deny-patterns.txt"
  export ALLOW_CACHE="/tmp/ddev-claude-allow-patterns.txt"
}

teardown() {
  teardown_base
}

run_url_hook() {
  local payload="$1"
  run bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload" "$REPO_ROOT/claude/hooks/url-check.sh"
}

run_secret_hook() {
  local payload="$1"
  run bash -c 'printf "%s" "$1" | bash "$2"' _ "$payload" "$REPO_ROOT/claude/hooks/secret-check.sh"
}

@test "url hook allows non-network tools" {
  printf 'example.com\n' > "$CACHE_FILE"

  run_url_hook '{"tool_name":"Read","tool_input":{"file_path":"README.md"}}'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "url hook allows whitelisted WebFetch domain" {
  printf 'example.com\n' > "$CACHE_FILE"

  run_url_hook '{"tool_name":"WebFetch","tool_input":{"url":"https://example.com/docs"}}'

  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "allow"'* ]]
}

@test "url hook denies non-whitelisted WebFetch domain" {
  printf 'example.com\n' > "$CACHE_FILE"

  run_url_hook '{"tool_name":"WebFetch","tool_input":{"url":"https://blocked.example.org/path"}}'

  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
  [[ "$output" == *'blocked.example.org'* ]]
}

@test "url hook allows add-domain bash special case" {
  printf 'example.com\n' > "$CACHE_FILE"

  run_url_hook '{"tool_name":"Bash","tool_input":{"command":"/opt/ddev-claude/bin/add-domain api.example.com"}}'

  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "allow"'* ]]
}

@test "secret hook allows bash command that only mentions secret-like token" {
  printf '.env\n' > "$DENY_CACHE"
  : > "$ALLOW_CACHE"

  run_secret_hook '{"tool_name":"Bash","tool_input":{"command":"echo \".env\""}}'

  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "secret hook denies read of denied file" {
  printf '.env\n' > "$DENY_CACHE"
  : > "$ALLOW_CACHE"

  run_secret_hook '{"tool_name":"Read","tool_input":{"file_path":"/project/.env"}}'

  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "deny"'* ]]
  [[ "$output" == *'Secret file access blocked: .env'* ]]
}

@test "secret hook allows exempt-secret bash special case" {
  printf '.env\n' > "$DENY_CACHE"
  : > "$ALLOW_CACHE"

  run_secret_hook '{"tool_name":"Bash","tool_input":{"command":"/opt/ddev-claude/bin/exempt-secret .env"}}'

  [ "$status" -eq 0 ]
  [[ "$output" == *'"permissionDecision": "allow"'* ]]
}
