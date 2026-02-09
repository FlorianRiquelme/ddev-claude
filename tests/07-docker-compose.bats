#!/usr/bin/env bats

load helpers

setup() {
  setup_base
}

teardown() {
  teardown_base
}

@test "docker compose includes host HOME .claude alias mount for plugin paths" {
  run grep -F '${HOME}/.claude:${HOME}/.claude:rw' "$REPO_ROOT/docker-compose.claude.yaml"

  [ "$status" -eq 0 ]
}

