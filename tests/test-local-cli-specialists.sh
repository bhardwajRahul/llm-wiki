#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT/scripts/llm-wiki"
TMP="$(mktemp -d)"
HUB="$TMP/hub"
PASS=0
FAIL=0

cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT

pass() { PASS=$((PASS + 1)); printf '  PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL + 1)); printf '  FAIL: %s\n' "$1"; }
check() {
  local label="$1"
  shift
  if "$@"; then pass "$label"; else fail "$label"; fi
}

mkdir -p "$HUB/topics/demo" "$HUB/topics/other" "$HUB/topics/.archive/old"
cat > "$HUB/wikis.json" <<'EOF'
{
  "wikis": {
    "demo": {"path": "topics/demo", "status": "active"},
    "other": {"path": "topics/other", "status": "active"},
    "old": {"path": "topics/.archive/old", "status": "archived"}
  }
}
EOF
printf '# Wiki Hub Index\n' > "$HUB/_index.md"
printf '# Wiki Activity Log\n' > "$HUB/log.md"
for topic in demo other old; do
  if [ "$topic" = old ]; then topic_root="$HUB/topics/.archive/old"; else topic_root="$HUB/topics/$topic"; fi
  printf '# %s\n' "$topic" > "$topic_root/_index.md"
  printf '%s\n' '---' "title: $topic" '---' > "$topic_root/config.md"
  printf '# Wiki Activity Log\n' > "$topic_root/log.md"
done

echo '=== Local specialist CLI ==='

LLM_WIKI_TODAY=2026-08-17 "$CLI" specialist --hub "$HUB" init --json > "$TMP/init.json"
check 'init reports created library' python3 -c '
import json,sys
d=json.load(open(sys.argv[1])); assert d["status"] == "created" and d["library"].endswith("/.skills")
' "$TMP/init.json"
check 'init creates control files' test -f "$HUB/.skills/_index.md"
check 'init creates schema-v1 registry' python3 -c '
import json,sys
d=json.load(open(sys.argv[1])); assert d == {"schema_version": 1, "topics": {}}
' "$HUB/.skills/registry.json"

LLM_WIKI_TODAY=2026-08-17 "$CLI" specialist --hub "$HUB" create research-methodologist \
  --description 'Reviews study design, causal claims, evidence quality, and reproducibility.' \
  --risk-tier medium --json > "$TMP/create.json"
check 'create writes SKILL.md scaffold' test -f "$HUB/.skills/research-methodologist/SKILL.md"
check 'scaffold carries bounded specialist metadata and contract' sh -c '
  f="$1"
  grep -q "^name: research-methodologist$" "$f" &&
  grep -q "^  llm-wiki-kind: specialist$" "$f" &&
  grep -q "^# Non-claims$" "$f" &&
  grep -q "^# Stop and escalation rules$" "$f" &&
  grep -q "^# Evaluation cases$" "$f"
' sh "$HUB/.skills/research-methodologist/SKILL.md"

"$CLI" specialist --hub "$HUB" validate --json > "$TMP/validate.json"
check 'valid library passes specialist validation' python3 -c '
import json,sys
d=json.load(open(sys.argv[1])); assert d["status"] == "pass" and d["issues"] == []
' "$TMP/validate.json"
"$CLI" lint "$HUB" --json > "$TMP/lint.json"
check 'hub lint accepts and validates .skills' python3 -c '
import json,sys
d=json.load(open(sys.argv[1])); assert d["status"] == "pass" and d["counts"]["critical"] == 0
' "$TMP/lint.json"

if "$CLI" specialist --hub "$HUB" create research-methodologist --description duplicate >/dev/null 2>&1; then
  fail 'duplicate specialist is rejected'
else
  pass 'duplicate specialist is rejected'
fi
if "$CLI" specialist --hub "$HUB" create 'Research Doctor' --description invalid >/dev/null 2>&1; then
  fail 'invalid credential-style name is rejected'
else
  pass 'invalid credential-style name is rejected'
fi

"$CLI" specialist --hub "$HUB" enable research-methodologist --wiki demo --json > "$TMP/enable.json"
check 'enable writes explicit topic allowlist' python3 -c '
import json,sys
d=json.load(open(sys.argv[1])); assert d["topics"] == {"demo": ["research-methodologist"]}
' "$HUB/.skills/registry.json"
"$CLI" specialist --hub "$HUB" list --wiki demo --json > "$TMP/list.json"
check 'topic list returns only enabled specialists with provenance' python3 -c '
import json,sys
d=json.load(open(sys.argv[1])); rows=d["specialists"]
assert len(rows) == 1 and rows[0]["name"] == "research-methodologist"
assert rows[0]["version"] == "0.1.0" and len(rows[0]["sha256"]) == 64
' "$TMP/list.json"
check 'enable appends hub and topic logs' sh -c '
  grep -q "enabled research-methodologist for topic demo" "$1" &&
  grep -q "enabled research-methodologist" "$2"
' sh "$HUB/log.md" "$HUB/topics/demo/log.md"

if "$CLI" specialist --hub "$HUB" enable research-methodologist --wiki old >/dev/null 2>&1; then
  fail 'archived topic cannot enable a specialist'
else
  pass 'archived topic cannot enable a specialist'
fi
if "$CLI" specialist --hub "$HUB" enable research-methodologist --wiki missing >/dev/null 2>&1; then
  fail 'unknown topic cannot enable a specialist'
else
  pass 'unknown topic cannot enable a specialist'
fi

mv "$HUB/.skills/research-methodologist" "$TMP/research-methodologist"
"$CLI" specialist --hub "$HUB" disable research-methodologist --wiki demo --json > "$TMP/repair-disable.json"
check 'disable repairs an allowlist even when its package is missing' python3 -c '
import json,sys
d=json.load(open(sys.argv[1])); assert d["topics"] == {}
' "$HUB/.skills/registry.json"
mv "$TMP/research-methodologist" "$HUB/.skills/research-methodologist"
"$CLI" specialist --hub "$HUB" enable research-methodologist --wiki demo >/dev/null

mkdir "$HUB/.skills/research-methodologist/scripts"
printf '#!/bin/sh\n' > "$HUB/.skills/research-methodologist/scripts/run.sh"
if "$CLI" specialist --hub "$HUB" validate research-methodologist >/dev/null 2>&1; then
  fail 'instruction-only validator rejects scripts'
else
  pass 'instruction-only validator rejects scripts'
fi
if "$CLI" lint "$HUB" --json > "$TMP/bad-lint.json"; then
  fail 'hub lint fails invalid specialist package'
else
  check 'hub lint reports invalid specialist package' python3 -c '
import json,sys
d=json.load(open(sys.argv[1])); assert d["status"] == "fail" and d["counts"]["critical"] >= 1
' "$TMP/bad-lint.json"
fi
rm -rf "$HUB/.skills/research-methodologist/scripts"

cp "$HUB/.skills/research-methodologist/SKILL.md" "$TMP/skill.good"
python3 - "$HUB/.skills/research-methodologist/SKILL.md" <<'PY'
import sys
from pathlib import Path
p=Path(sys.argv[1]); text=p.read_text(); p.write_text(text.replace("metadata:\n", "allowed-tools: Bash\nmetadata:\n"))
PY
if "$CLI" specialist --hub "$HUB" validate research-methodologist >/dev/null 2>&1; then
  fail 'validator rejects specialist-owned allowed-tools'
else
  pass 'validator rejects specialist-owned allowed-tools'
fi
mv "$TMP/skill.good" "$HUB/.skills/research-methodologist/SKILL.md"

python3 - "$HUB/.skills/research-methodologist/SKILL.md" <<'PY'
import sys
from pathlib import Path
p=Path(sys.argv[1]); text=p.read_text(); p.write_text(text.replace("Reviews study design, causal claims, evidence quality, and reproducibility.", "Reviews research design and reproducibility."))
PY
LLM_WIKI_TODAY=2026-08-18 "$CLI" specialist --hub "$HUB" refresh --json > "$TMP/refresh.json"
check 'refresh rebuilds index after manual edits' grep -q 'Reviews research design and reproducibility.' "$HUB/.skills/_index.md"

"$CLI" specialist --hub "$HUB" disable research-methodologist --wiki demo --json > "$TMP/disable.json"
check 'disable removes empty topic allowlist' python3 -c '
import json,sys
d=json.load(open(sys.argv[1])); assert d["topics"] == {}
' "$HUB/.skills/registry.json"

"$CLI" specialist --hub "$HUB" init --json > "$TMP/reinit.json"
check 'init is idempotent' python3 -c '
import json,sys
d=json.load(open(sys.argv[1])); assert d["status"] == "already-initialized"
' "$TMP/reinit.json"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
