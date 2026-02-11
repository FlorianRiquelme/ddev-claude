#!/usr/bin/env bats

load helpers

setup() {
  setup_base
  make_test_approot
}

teardown() {
  teardown_base
}

@test "parse-blocked-domains parses dmesg and reverse DNS" {
  mock_cmd dmesg <<'EOF'
#!/usr/bin/env bash
cat <<'LOG'
[FIREWALL-BLOCK] DST=203.0.113.5
[FIREWALL-BLOCK] DST=198.51.100.8
LOG
EOF
  mock_cmd dig <<'EOF'
#!/usr/bin/env bash
if [[ "$3" == "203.0.113.5" ]]; then
  echo "api.example.test."
fi
EOF

  run bash "$REPO_ROOT/claude/scripts/parse-blocked-domains.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"api.example.test"* ]]
  [[ "$output" == *"198.51.100.8 (no reverse DNS)"* ]]
}

@test "log-network-traffic stop extracts accessed domains from raw log" {
  cat > /tmp/ddev-claude-traffic-raw.log <<'EOF'
12:00:00.000 IP 1.1.1.1 > 2.2.2.2: example.com. A 203.0.113.1
12:00:01.000 IP 1.1.1.1 > 2.2.2.2: api.example.com. AAAA 2001:db8::1
EOF

  run bash "$REPO_ROOT/claude/scripts/log-network-traffic.sh" stop 999999

  [ "$status" -eq 0 ]
  run grep -c '^example\.com$' /tmp/ddev-claude-accessed.log
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run grep -c '^api\.example\.com$' /tmp/ddev-claude-accessed.log
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "run-claude-no-firewall captures domains and runs claude" {
  mock_cmd tcpdump <<'EOF'
#!/usr/bin/env bash
trap 'exit 0' TERM
echo "12:00:00.000 IP 1.1.1.1 > 2.2.2.2: api.capture.test. A 203.0.113.7"
sleep 5
EOF
  mock_cmd iptables <<'EOF'
#!/usr/bin/env bash
echo "$*" >> /tmp/iptables-calls.log
exit 0
EOF
  mock_cmd claude <<'EOF'
#!/usr/bin/env bash
echo "$*" >> /tmp/claude-calls.log
exit 0
EOF

  run bash "$REPO_ROOT/claude/scripts/run-claude-no-firewall.sh" "--help"

  [ "$status" -eq 0 ]
  run grep -c '^api\.capture\.test$' /tmp/ddev-claude-accessed.log
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run grep -c '^-F OUTPUT$' /tmp/iptables-calls.log
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "healthcheck passes with mocked firewall state" {
  mock_cmd iptables <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "-L" && "$2" == "OUTPUT" && "$3" == "-n" ]]; then
  cat <<'OUT'
Chain OUTPUT (policy DROP)
target     prot opt source               destination
ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
ACCEPT     all  --  0.0.0.0/0            0.0.0.0/0
OUT
  exit 0
fi
if [[ "$1" == "-L" && "$2" == "OUTPUT" ]]; then
  echo "Chain OUTPUT (policy DROP)"
  exit 0
fi
exit 0
EOF
  mock_cmd ipset <<'EOF'
#!/usr/bin/env bash
if [[ "$1" == "list" && "$2" == "whitelist_ips" ]]; then
  cat <<'OUT'
Name: whitelist_ips
Members:
203.0.113.10 timeout 3200
OUT
  exit 0
fi
exit 0
EOF
  mock_cmd timeout <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  mock_cmd nc <<'EOF'
#!/usr/bin/env bash
exit 1
EOF

  run bash "$REPO_ROOT/claude/healthcheck.sh"

  [ "$status" -eq 0 ]
  [[ "$output" == *"Firewall healthcheck passed"* ]]
}
