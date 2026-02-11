#!/usr/bin/env bats

load helpers

setup() {
  setup_base
  make_test_approot
}

teardown() {
  teardown_base
}

@test "merge-whitelist merges default global and project with unique domains" {
  global_file="$TEST_TMPDIR/global-whitelist.json"
  project_file="$TEST_TMPDIR/project-whitelist.json"

  cat > "$global_file" <<'EOF'
["api.global.test","dup.test"]
EOF
  cat > "$project_file" <<'EOF'
["api.project.test","dup.test"]
EOF

  run bash "$REPO_ROOT/claude/scripts/merge-whitelist.sh" "$global_file" "$project_file"

  [ "$status" -eq 0 ]
  [[ "$output" == *"api.global.test"* ]]
  [[ "$output" == *"api.project.test"* ]]
  [[ "$output" == *"dup.test"* ]]
  run grep -c '^dup.test$' /tmp/ddev-claude-merged-whitelist.txt
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "merge-denylist writes deny and allow caches" {
  global_file="$TEST_TMPDIR/global-denylist.json"
  project_file="$TEST_TMPDIR/project-denylist.json"

  cat > "$global_file" <<'EOF'
{"deny":["*.pem",".env"],"allow":[".env.example"]}
EOF
  cat > "$project_file" <<'EOF'
[".pgpass",".env"]
EOF

  run bash "$REPO_ROOT/claude/scripts/merge-denylist.sh" "$global_file" "$project_file"

  [ "$status" -eq 0 ]
  run grep -c '^\.env$' /tmp/ddev-claude-deny-patterns.txt
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run grep -c '^\.env\.example$' /tmp/ddev-claude-allow-patterns.txt
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
}

@test "merge-whitelist fails on invalid json" {
  bad_file="$TEST_TMPDIR/bad-whitelist.json"
  echo '{"not":"an-array"}' > "$bad_file"

  run bash "$REPO_ROOT/claude/scripts/merge-whitelist.sh" "$bad_file" "$bad_file"

  [ "$status" -ne 0 ]
  [[ "$output" == *"must contain a JSON array"* ]]
}
