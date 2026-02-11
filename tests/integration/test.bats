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

@test ".env file is masked inside claude container" {
  cd "$TESTDIR"

  # Remove any existing .env file and create a new one with fake secrets
  rm -f .env
  cat > .env << 'EOF'
SECRET_KEY=super-secret-value-123
DB_PASSWORD=do-not-leak-this
EOF

  # Verify the file has content on the host
  [ -s .env ]
  grep -q "SECRET_KEY" .env

  # Debug: Show what's actually in the file inside container
  echo "=== DEBUG: Content inside container ==="
  ddev exec -s claude bash -c 'cat ${DDEV_APPROOT}/.env'
  echo "=== DEBUG: File type and mount info ==="
  ddev exec -s claude bash -c 'ls -la ${DDEV_APPROOT}/.env'
  ddev exec -s claude bash -c 'mount | grep ".env"'

  # The critical security test: secrets are NOT visible inside container
  run ddev exec -s claude bash -c 'grep "SECRET_KEY" ${DDEV_APPROOT}/.env' 2>&1
  [ "$status" -ne 0 ]

  run ddev exec -s claude bash -c 'grep "DB_PASSWORD" ${DDEV_APPROOT}/.env' 2>&1
  [ "$status" -ne 0 ]
}

@test ".ddev/.env file is masked inside claude container" {
  cd "$TESTDIR"

  # Remove any existing .ddev/.env file and create a new one with DDEV-specific secrets
  rm -f .ddev/.env
  cat > .ddev/.env << 'EOF'
DDEV_ROUTER_HTTP_PORT=8080
ADMIN_TOKEN=sensitive-admin-token
EOF

  # Verify the file has content on the host
  [ -s .ddev/.env ]
  grep -q "ADMIN_TOKEN" .ddev/.env

  # The critical security test: secrets are NOT visible inside container
  run ddev exec -s claude bash -c 'grep "ADMIN_TOKEN" ${DDEV_APPROOT}/.ddev/.env' 2>&1
  [ "$status" -ne 0 ]

  run ddev exec -s claude bash -c 'grep "DDEV_ROUTER_HTTP_PORT" ${DDEV_APPROOT}/.ddev/.env' 2>&1
  [ "$status" -ne 0 ]
}

@test "ddev shim forwards runtime command: php" {
  cd "$TESTDIR"

  # Runtime commands should be forwarded and execute successfully
  run ddev exec -s claude ddev php --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"PHP"* ]]
}

@test "ddev shim forwards runtime command: composer" {
  cd "$TESTDIR"

  run ddev exec -s claude ddev composer --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"Composer"* ]]
}

@test "ddev shim forwards runtime command: node" {
  cd "$TESTDIR"

  run ddev exec -s claude ddev node --version
  [ "$status" -eq 0 ]
  [[ "$output" == *"v"* ]]
}

@test "ddev shim forwards runtime command: npm" {
  cd "$TESTDIR"

  run ddev exec -s claude ddev npm --version
  [ "$status" -eq 0 ]
  # npm version output is just the version number
  [[ "$output" =~ ^[0-9]+\.[0-9]+ ]]
}

@test "ddev lifecycle commands are blocked: restart" {
  cd "$TESTDIR"

  # Lifecycle commands should be blocked with helpful error
  run -127 ddev exec -s claude ddev restart 2>&1
  [ "$status" -eq 127 ]
  [[ "$output" == *"Lifecycle commands must run on the host"* ]]
  [[ "$output" == *"ddev restart"* ]]
}

@test "ddev lifecycle commands are blocked: exec" {
  cd "$TESTDIR"

  # exec is a lifecycle command and should be blocked
  run -127 ddev exec -s claude ddev exec -s web php -v 2>&1
  [ "$status" -eq 127 ]
  [[ "$output" == *"Lifecycle commands must run on the host"* ]]
  [[ "$output" == *"ddev exec -s web php -v"* ]]
}

@test "ddev shim is in PATH inside claude container" {
  cd "$TESTDIR"

  # Verify ddev command exists and is our shim
  run ddev exec -s claude which ddev
  [ "$status" -eq 0 ]
  [[ "$output" == *"/usr/local/bin/ddev"* ]]
}
