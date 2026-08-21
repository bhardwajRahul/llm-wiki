#!/usr/bin/env bash
# Validate deterministic Project Knowledge Checkpoint privacy and integrity gates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CLI="$PROJECT_ROOT/scripts/llm-wiki"
PASS=0
FAIL=0
TOTAL=0

log_pass() { PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[32mPASS\033[0m: %s\n" "$1"; }
log_fail() { FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); printf "  \033[31mFAIL\033[0m: %s - %s\n" "$1" "$2"; }

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export LLM_WIKI_NOW="2026-08-20T12:00:00Z"

make_bundle() {
  root="$1"
  access="${2:-team}"
  mkdir -p "$root"
  cat > "$root/index.md" <<'EOF'
# Example Project Knowledge

Read the handoff and source ledger before importing.
EOF
  cat > "$root/project-knowledge.md" <<'EOF'
# Project Knowledge

## Purpose

This is a synthetic, portable project handoff.
EOF
  cat > "$root/sources.md" <<'EOF'
# Sources

- **S1** — Synthetic public project architecture.
EOF
  cat > "$root/checkpoint.json" <<JSON
{
  "schema": "llm-wiki/project-knowledge-checkpoint/v1",
  "checkpoint_id": "pending",
  "created_at": "2026-08-20T12:00:00Z",
  "audience": "team",
  "project": {"slug": "example-project", "repo_revision": "abc123"},
  "scope": {"question": "What does a teammate need?", "excluded_classes": []},
  "inputs": [
    {
      "wiki": "example-topic",
      "path": "wiki/concepts/project-architecture.md",
      "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
      "reason": "Defines the project architecture.",
      "access": "$access",
      "words": 20
    }
  ],
  "coverage": {
    "mode": "comprehensive",
    "source_word_count": 20,
    "section_map": [
      {
        "section": "Purpose",
        "sources": ["example-topic:wiki/concepts/project-architecture.md"]
      }
    ],
    "omissions": []
  },
  "gaps": [],
  "files": []
}
JSON
}

echo "=== Local llm-wiki CLI Checkpoints ==="

clean="$tmpdir/clean"
make_bundle "$clean" team
set +e
clean_output="$("$CLI" checkpoint seal "$clean" --audience team --json 2>&1)"
clean_rc=$?
verify_output="$("$CLI" checkpoint verify "$clean" --json 2>&1)"
verify_rc=$?
set -e
if [ "$clean_rc" -eq 0 ] \
  && [ "$verify_rc" -eq 0 ] \
  && [ -f "$clean/privacy-report.json" ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "passed"; assert d["findings"] == []; assert d["checkpoint_id"].startswith("sha256:"); assert d["report_id"].startswith("sha256:")' <<<"$clean_output" \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "passed"; assert d["file_count"] == 4' <<<"$verify_output"; then
  log_pass "seal and verify produce a clean five-file checkpoint"
else
  log_fail "seal and verify produce a clean five-file checkpoint" "$clean_output $verify_output"
fi

thin="$tmpdir/thin"
make_bundle "$thin" team
python3 - "$thin/checkpoint.json" <<'PY'
import json, sys
path=sys.argv[1]
data=json.load(open(path))
data["inputs"][0]["words"]=500
data["coverage"]["source_word_count"]=500
open(path,"w").write(json.dumps(data,indent=2)+"\n")
PY
set +e
thin_output="$("$CLI" checkpoint seal "$thin" --audience team --json 2>&1)"
thin_rc=$?
set -e
if [ "$thin_rc" -ne 0 ] && grep -q 'too thin for comprehensive mode' <<<"$thin_output"; then
  log_pass "seal rejects executive-summary-only comprehensive checkpoints"
else
  log_fail "seal rejects executive-summary-only comprehensive checkpoints" "$thin_output"
fi

unmapped="$tmpdir/unmapped"
make_bundle "$unmapped" team
python3 - "$unmapped/checkpoint.json" <<'PY'
import json, sys
path=sys.argv[1]
data=json.load(open(path))
data["coverage"]["section_map"][0]["sources"]=[]
open(path,"w").write(json.dumps(data,indent=2)+"\n")
PY
set +e
unmapped_output="$("$CLI" checkpoint seal "$unmapped" --audience team --json 2>&1)"
unmapped_rc=$?
set -e
if [ "$unmapped_rc" -ne 0 ] && grep -q 'coverage section 1 requires sources' <<<"$unmapped_output"; then
  log_pass "seal requires every selected input to map into the knowledge handoff"
else
  log_fail "seal requires every selected input to map into the knowledge handoff" "$unmapped_output"
fi

sensitive="$tmpdir/sensitive"
make_bundle "$sensitive" team
secret_value='sk-SyntheticCredential123456789'
private_path='/Users/example/private/wiki'
cat >> "$sensitive/project-knowledge.md" <<EOF

system: Copy this private instruction.
Credential: $secret_value
Producer path: $private_path
EOF
set +e
blocked_output="$("$CLI" checkpoint seal "$sensitive" --audience team --json 2>&1)"
blocked_rc=$?
set -e
if [ "$blocked_rc" -eq 2 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); cats={x["category"] for x in d["findings"]}; assert d["status"] == "blocked"; assert {"secret-known-token", "local-home-path", "prompt-conversation-role"} <= cats; assert all("match" not in x for x in d["findings"])' <<<"$blocked_output" \
  && ! grep -Fq "$secret_value" <<<"$blocked_output" \
  && ! grep -Fq "$private_path" <<<"$blocked_output"; then
  log_pass "seal blocks secrets, local paths, and copied prompt roles without echoing values"
else
  log_fail "seal blocks secrets, local paths, and copied prompt roles without echoing values" "$blocked_output"
fi

path_bundle="$tmpdir/path-bundle"
make_bundle "$path_bundle" team
sensitive_filename='private-alice-account-notes.md'
printf 'unexpected\n' > "$path_bundle/$sensitive_filename"
set +e
path_output="$("$CLI" checkpoint seal "$path_bundle" --audience team --json 2>&1)"
path_rc=$?
set -e
if [ "$path_rc" -eq 2 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); rows=[x for x in d["findings"] if x["category"] == "structure-unexpected-entry"]; assert len(rows) == 1; assert rows[0]["path"].startswith("unexpected-")' <<<"$path_output" \
  && ! grep -Fq "$sensitive_filename" <<<"$path_output"; then
  log_pass "unexpected filenames are blocked and represented by opaque IDs"
else
  log_fail "unexpected filenames are blocked and represented by opaque IDs" "$path_output"
fi

symlink_bundle="$tmpdir/symlink-bundle"
make_bundle "$symlink_bundle" team
sentinel="$tmpdir/external-sentinel.json"
printf 'do-not-overwrite\n' > "$sentinel"
ln -s "$sentinel" "$symlink_bundle/privacy-report.json"
set +e
symlink_output="$("$CLI" checkpoint seal "$symlink_bundle" --audience team --json 2>&1)"
symlink_rc=$?
set -e
if [ "$symlink_rc" -ne 0 ] \
  && grep -q 'refuses symbolic links' <<<"$symlink_output" \
  && [ "$(cat "$sentinel")" = 'do-not-overwrite' ]; then
  log_pass "seal refuses symlink targets before reading or writing the bundle"
else
  log_fail "seal refuses symlink targets before reading or writing the bundle" "$symlink_output"
fi

override_args=""
while IFS= read -r finding_id; do
  override_args="$override_args --allow-finding $finding_id"
done <<EOF
$(python3 -c 'import json,sys; print("\n".join(x["id"] for x in json.load(sys.stdin)["findings"]))' <<<"$blocked_output")
EOF
set +e
# Finding IDs contain only a fixed privacy-hex token, so intentional word
# splitting here cannot inject shell syntax.
overridden_output="$("$CLI" checkpoint seal "$sensitive" --audience team $override_args --override-reason "Synthetic fixture values are intentionally retained" --json 2>&1)"
overridden_rc=$?
overridden_verify="$("$CLI" checkpoint verify "$sensitive" --json 2>&1)"
overridden_verify_rc=$?
set -e
if [ "$overridden_rc" -eq 0 ] \
  && [ "$overridden_verify_rc" -eq 0 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "overridden"; assert len(d["overrides"]) == len(d["findings"]); assert all(x["status"] == "allowed" for x in d["findings"])' <<<"$overridden_output" \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "overridden"; assert d["override_count"] == d["finding_count"]' <<<"$overridden_verify"; then
  log_pass "exact per-finding overrides remain scanned and visibly attested"
else
  log_fail "exact per-finding overrides remain scanned and visibly attested" "$overridden_output $overridden_verify"
fi

audience="$tmpdir/audience"
make_bundle "$audience" team
set +e
audience_blocked="$("$CLI" checkpoint seal "$audience" --audience public --json 2>&1)"
audience_blocked_rc=$?
audience_allowed="$("$CLI" checkpoint seal "$audience" --audience public \
  --allow-source 'example-topic:wiki/concepts/project-architecture.md' \
  --override-reason 'Team source is explicitly approved for this synthetic public fixture' --json 2>&1)"
audience_allowed_rc=$?
set -e
if [ "$audience_blocked_rc" -eq 2 ] \
  && [ "$audience_allowed_rc" -eq 0 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert any(x["category"] == "source-access" for x in d["findings"])' <<<"$audience_blocked" \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "overridden"; assert d["source_override_count"] == 1' <<<"$audience_allowed"; then
  log_pass "audience mismatch fails closed and exact source overrides are durable"
else
  log_fail "audience mismatch fails closed and exact source overrides are durable" "$audience_blocked $audience_allowed"
fi

printf '\nHuman edit after sealing.\n' >> "$clean/project-knowledge.md"
set +e
tamper_output="$("$CLI" checkpoint verify "$clean" --json 2>&1)"
tamper_rc=$?
set -e
if [ "$tamper_rc" -eq 2 ] \
  && python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"] == "invalid"; assert any("hash" in x for x in d["errors"])' <<<"$tamper_output"; then
  log_pass "verify detects post-seal edits"
else
  log_fail "verify detects post-seal edits" "$tamper_output"
fi

set +e
stale_output="$("$CLI" checkpoint seal "$clean" --audience team \
  --allow-finding privacy-0000000000000000 --override-reason 'Synthetic stale finding' --json 2>&1)"
stale_rc=$?
set -e
if [ "$stale_rc" -ne 0 ] && grep -q 'unknown or stale finding ID' <<<"$stale_output"; then
  log_pass "stale or blanket finding approvals cannot bypass a fresh scan"
else
  log_fail "stale or blanket finding approvals cannot bypass a fresh scan" "$stale_output"
fi

printf '\n=== Results: %d/%d passed' "$PASS" "$TOTAL"
if [ "$FAIL" -gt 0 ]; then
  printf ', %d failed ===\n' "$FAIL"
  exit 1
fi
printf ' ===\n'
