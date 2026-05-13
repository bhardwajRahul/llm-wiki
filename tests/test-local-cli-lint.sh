#!/bin/bash
# Validate the local deterministic llm-wiki lint helper.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLI="$PROJECT_ROOT/scripts/llm-wiki"
GOLDEN="$SCRIPT_DIR/fixtures/golden-wiki"
PASS=0
FAIL=0
TOTAL=0

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s - %s\n" "$1" "$2"; }

expect_success() {
  local name="$1"
  shift
  local output
  if output="$("$@" 2>&1)" && grep -q "Result: PASS" <<<"$output"; then
    log_pass "$name"
  else
    log_fail "$name" "$output"
  fi
}

expect_failure_contains() {
  local name="$1"
  local expected="$2"
  shift 2
  local output
  set +e
  output="$("$@" 2>&1)"
  local rc=$?
  set -e
  if [ "$rc" -ne 0 ] && grep -q "$expected" <<<"$output"; then
    log_pass "$name"
  else
    log_fail "$name" "$output"
  fi
}

echo "=== Local llm-wiki CLI Lint ==="

if [ -x "$CLI" ]; then
  log_pass "scripts/llm-wiki is executable"
else
  log_fail "scripts/llm-wiki is executable" "missing executable bit"
fi

expect_success "golden wiki passes local lint" "$CLI" lint "$GOLDEN"

expect_failure_contains \
  "missing-index fixture fails local lint" \
  "Required _index.md is missing" \
  "$CLI" lint "$SCRIPT_DIR/fixtures/defects/missing-index"

expect_failure_contains \
  "bad-frontmatter fixture fails local lint" \
  "Invalid type" \
  "$CLI" lint "$SCRIPT_DIR/fixtures/defects/bad-frontmatter"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
mkdir "$tmpdir/wiki"
cp -R "$GOLDEN/." "$tmpdir/wiki/"
mv "$tmpdir/wiki/wiki/concepts/sample-concept.md" \
  "$tmpdir/wiki/wiki/references/sample-concept.md"

expect_failure_contains \
  "misplaced file is reported" \
  "File is in the wrong directory" \
  "$CLI" lint "$tmpdir/wiki"

set +e
fix_output="$("$CLI" lint --fix "$tmpdir/wiki" 2>&1)"
fix_rc=$?
set -e
if [ "$fix_rc" -eq 0 ] \
  && grep -q "Moved wiki/references/sample-concept.md to wiki/concepts/sample-concept.md" <<<"$fix_output" \
  && [ -f "$tmpdir/wiki/wiki/concepts/sample-concept.md" ]; then
  log_pass "--fix moves misplaced wiki files"
else
  log_fail "--fix moves misplaced wiki files" "$fix_output"
fi

portable_home="$tmpdir/portable-home"
portable_hub="$portable_home/Library/Mobile Documents/com~apple~CloudDocs/wiki"
mkdir -p "$portable_home/.config/llm-wiki" "$portable_hub/topics/portable-topic"
cp -R "$GOLDEN/." "$portable_hub/topics/portable-topic/"
cat > "$portable_home/.config/llm-wiki/config.json" <<'JSON'
{
  "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki",
  "resolved_path": "/Users/olduser/Library/Mobile Documents/com~apple~CloudDocs/wiki"
}
JSON
cat > "$portable_hub/_index.md" <<'EOF'
# Hub Index
EOF
cat > "$portable_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "portable-topic": {
      "path": "/Users/olduser/Library/Mobile Documents/com~apple~CloudDocs/wiki/topics/portable-topic",
      "description": "Portable topic"
    }
  },
  "local_wikis": []
}
JSON

expect_success \
  "portable hub_path beats stale resolved_path and registry path" \
  env HOME="$portable_home" "$CLI" lint --wiki portable-topic

lag_home="$tmpdir/lag-home"
lag_hub="$lag_home/Library/Mobile Documents/com~apple~CloudDocs/wiki"
stale_resolved_hub="$tmpdir/stale-resolved-hub"
mkdir -p "$lag_home/.config/llm-wiki" "$lag_hub/topics/lag-topic" "$stale_resolved_hub"
cp -R "$GOLDEN/." "$lag_hub/topics/lag-topic/"
cat > "$lag_home/.config/llm-wiki/config.json" <<JSON
{
  "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki",
  "resolved_path": "$stale_resolved_hub"
}
JSON
cat > "$lag_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "lag-topic": { "path": "topics/lag-topic", "description": "Lag topic" }
  },
  "local_wikis": []
}
JSON
cat > "$stale_resolved_hub/_index.md" <<'EOF'
# Stale Hub Index
EOF

expect_success \
  "existing hub_path wins even when hub _index is not present yet" \
  env HOME="$lag_home" "$CLI" lint --wiki lag-topic

relative_hub="$tmpdir/relative-hub"
mkdir -p "$relative_hub/topics/relative-topic"
cp -R "$GOLDEN/." "$relative_hub/topics/relative-topic/"
cat > "$relative_hub/wikis.json" <<'JSON'
{
  "default": "<HUB>",
  "wikis": {
    "hub": { "path": "<HUB>", "description": "Hub" },
    "relative-topic": { "path": "topics/relative-topic", "description": "Relative topic" }
  },
  "local_wikis": []
}
JSON

expect_success \
  "relative wikis.json paths resolve from hub" \
  "$CLI" lint --hub "$relative_hub" --wiki relative-topic

bad_registry_hub="$tmpdir/bad-registry-hub"
mkdir -p "$bad_registry_hub/topics/bad-registry-topic"
cp -R "$GOLDEN/." "$bad_registry_hub/topics/bad-registry-topic/"
printf '' > "$bad_registry_hub/wikis.json"

expect_success \
  "topic directory fallback works when wikis.json is unreadable" \
  "$CLI" lint --hub "$bad_registry_hub" --wiki bad-registry-topic

echo ""
echo "==========================================="
printf "Results: \033[32m%d passed\033[0m, \033[31m%d failed\033[0m, %d total\n" "$PASS" "$FAIL" "$TOTAL"

if [ "$FAIL" -ne 0 ]; then
  exit 1
fi
