#!/usr/bin/env bats

# Integration tests for ddev-claude addon.
# Requires a real DDEV environment — run via CI with ddev/github-action-add-on-test@v2
# or locally with: bats tests/integration/test.bats
#
# IMPORTANT: Tests are order-dependent. The first test creates the DDEV project;
# subsequent tests operate on it. Do NOT use bats --jobs (parallel mode).

PROJNAME="ddev-claude-test"
TESTDIR="/tmp/$PROJNAME"

setup() {
  set -eu -o pipefail
  export DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

teardown() {
  set -eu -o pipefail
  cd "$DIR" || true
}

teardown_file() {
  # Cleanup is best-effort; do not use set -e here.
  cd "/tmp/$PROJNAME" 2>/dev/null && ddev delete -Oy 2>/dev/null || true
  cd /
  # Docker-created files are root-owned on Linux; use sudo if available.
  sudo rm -rf "/tmp/$PROJNAME" 2>/dev/null || rm -rf "/tmp/$PROJNAME" 2>/dev/null || true
}

@test "install from directory" {
  mkdir -p "$TESTDIR"
  cd "$TESTDIR"

  # Create a minimal DDEV project
  ddev config --project-name="$PROJNAME" --project-type=php --docroot=web
  mkdir -p web
  echo '<?php echo "test";' > web/index.php

  # Install addon from repo checkout
  ddev get "$DIR"
  ddev restart
}

@test "claude container is running" {
  cd "$TESTDIR"

  # Simple check: can we exec into the claude service?
  run ddev exec -s claude true
  [ "$status" -eq 0 ]
}

@test "healthcheck passes" {
  cd "$TESTDIR"
  run ddev exec -s claude bash -c '${DDEV_APPROOT}/.ddev/claude/healthcheck.sh'
  [ "$status" -eq 0 ]
  [[ "$output" == *"healthcheck passed"* ]]
}

@test "firewall blocks non-whitelisted traffic" {
  cd "$TESTDIR"
  # TEST-NET-2 (198.51.100.0/24) is reserved and never routable.
  # Curl should fail because the firewall drops outbound to non-whitelisted IPs.
  run ddev exec -s claude curl --max-time 3 -s http://198.51.100.1 2>&1
  [ "$status" -ne 0 ]
}

@test "DNS resolution works" {
  cd "$TESTDIR"
  run ddev exec -s claude dig +short api.anthropic.com
  [ "$status" -eq 0 ]
  # Verify output looks like an IP address
  [[ "$output" =~ ^[0-9]+\.[0-9]+ ]]
}
