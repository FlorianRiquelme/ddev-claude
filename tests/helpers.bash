#!/usr/bin/env bash

setup_base() {
  export REPO_ROOT
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

  export TEST_TMPDIR
  TEST_TMPDIR="$(mktemp -d)"

  export HOME="$TEST_TMPDIR/home"
  mkdir -p "$HOME"

  export MOCK_BIN="$TEST_TMPDIR/bin"
  mkdir -p "$MOCK_BIN"
  export PATH="$MOCK_BIN:$PATH"

  rm -f /tmp/ipset-calls.log
  rm -f /tmp/iptables-calls.log
  rm -f /tmp/ddev-calls.log
  rm -f /tmp/claude-calls.log
  rm -f /tmp/entrypoint-script-calls.log
  rm -f /tmp/entrypoint-iptables.log
  rm -f /tmp/entrypoint-ipset.log
  rm -f /tmp/ddev-claude-seen-blocks
}

teardown_base() {
  rm -rf "$TEST_TMPDIR"
  rm -f /tmp/ddev-claude-merged-whitelist.txt
  rm -f /tmp/ddev-claude-deny-patterns.txt
  rm -f /tmp/ddev-claude-allow-patterns.txt
  rm -f /tmp/ddev-claude-secret-override
  rm -f /tmp/ddev-claude-accessed.log
  rm -f /tmp/ddev-claude-traffic-raw.log
  rm -f /tmp/ddev-claude-tcpdump.pid
  rm -f /tmp/ipset-calls.log
  rm -f /tmp/iptables-calls.log
  rm -f /tmp/ddev-calls.log
  rm -f /tmp/claude-calls.log
  rm -f /tmp/entrypoint-script-calls.log
  rm -f /tmp/entrypoint-iptables.log
  rm -f /tmp/entrypoint-ipset.log
  rm -f /tmp/ddev-claude-seen-blocks
}

make_test_approot() {
  export DDEV_APPROOT="$TEST_TMPDIR/app"
  mkdir -p "$DDEV_APPROOT/.ddev" "$DDEV_APPROOT/.ddev/ddev-claude"
  ln -s "$REPO_ROOT/claude" "$DDEV_APPROOT/.ddev/claude"
}

mock_cmd() {
  local name="$1"
  cat > "$MOCK_BIN/$name"
  chmod +x "$MOCK_BIN/$name"
}
