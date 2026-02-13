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

@test "docker compose masks project env files in claude container" {
  run grep -F 'source: ${DDEV_APPROOT}/.ddev/claude/config/empty.env' "$REPO_ROOT/docker-compose.claude.yaml"
  [ "$status" -eq 0 ]
  run grep -F 'target: ${DDEV_APPROOT}/.env' "$REPO_ROOT/docker-compose.claude.yaml"
  [ "$status" -eq 0 ]
  run grep -F 'target: ${DDEV_APPROOT}/.ddev/.env' "$REPO_ROOT/docker-compose.claude.yaml"
  [ "$status" -eq 0 ]
}

@test "docker compose mounts git config for root user" {
  run grep -F '~/.gitconfig:/root/.gitconfig:ro' "$REPO_ROOT/docker-compose.claude.yaml"
  [ "$status" -eq 0 ]
  run grep -F '~/.config/git:/root/.config/git:ro' "$REPO_ROOT/docker-compose.claude.yaml"
  [ "$status" -eq 0 ]
}

@test "docker compose mounts git config for claude user" {
  run grep -F '~/.gitconfig:/home/claude/.gitconfig:ro' "$REPO_ROOT/docker-compose.claude.yaml"
  [ "$status" -eq 0 ]
  run grep -F '~/.config/git:/home/claude/.config/git:ro' "$REPO_ROOT/docker-compose.claude.yaml"
  [ "$status" -eq 0 ]
}
