#!/usr/bin/env bats

load helpers

setup() {
  setup_base
  make_test_approot
  export DDEV_APPROOT
}

teardown() {
  teardown_base
}

@test "host claude command runs default firewall mode" {
  mock_cmd ddev <<'EOF'
#!/usr/bin/env bash
echo "$*" >> /tmp/ddev-calls.log
exit 0
EOF

  run bash "$REPO_ROOT/commands/host/claude" "--help"

  [ "$status" -eq 0 ]
  run grep -c 'exec -s claude claude --dangerously-skip-permissions --help' /tmp/ddev-calls.log
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "host claude command supports --no-firewall path" {
  mock_cmd ddev <<'EOF'
#!/usr/bin/env bash
echo "$*" >> /tmp/ddev-calls.log
if [[ "$*" == *"cat /tmp/ddev-claude-accessed.log"* ]]; then
  echo "api.example.test"
fi
exit 0
EOF

  run bash "$REPO_ROOT/commands/host/claude" "--no-firewall" "--print" "ok"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Firewall disabled for this session"* ]]
  run grep -c 'run-claude-no-firewall.sh --print ok' /tmp/ddev-calls.log
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "host claude-whitelist exits cleanly when no domains are found" {
  mock_cmd ddev <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"parse-blocked-domains.sh"* ]]; then
  exit 0
fi
if [[ "$*" == *"cat /tmp/ddev-claude-accessed.log"* ]]; then
  exit 0
fi
if [[ "$*" == *"merge-whitelist.sh"* ]]; then
  echo "example.com"
  exit 0
fi
exit 0
EOF

  run bash "$REPO_ROOT/commands/host/claude-whitelist"

  [ "$status" -eq 0 ]
  [[ "$output" == *"No blocked or accessed domains found."* ]]
}

@test "host claude-whitelist handles one-sided counts without pipefail crash" {
  mock_cmd ddev <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *"parse-blocked-domains.sh"* ]]; then
  exit 0
fi
if [[ "$*" == *"cat /tmp/ddev-claude-accessed.log"* ]]; then
  echo "registry.npmjs.org"
  exit 0
fi
if [[ "$*" == *"which gum"* ]]; then
  exit 1
fi
exit 0
EOF

  run bash "$REPO_ROOT/commands/host/claude-whitelist"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Accessed in no-firewall mode: 1 domain(s)"* ]]
}
