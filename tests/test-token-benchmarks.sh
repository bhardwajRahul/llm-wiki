#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"
BENCH="$ROOT/scripts/benchmark-token-efficiency"
FAKE_SERVER="$ROOT/tests/fixtures/fake-codex-app-server.py"
FAKE_CLAUDE="$ROOT/tests/fixtures/fake-claude-cli.py"

mkdir -p "$ROOT/.tmp"
TMP_ROOT="$(mktemp -d "$ROOT/.tmp/token-benchmark.XXXXXX")"
trap 'rm -rf "$TMP_ROOT"' EXIT

echo "=== Token Efficiency Benchmarks ==="

"$BENCH" static --root "$ROOT" --check --output "$TMP_ROOT/static.json" >/dev/null
python3 - "$TMP_ROOT/static.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["kind"] == "static_context_budget"
assert report["passed"] is True
assert all(row["passed"] for row in report["metrics"].values())
print("  PASS: deterministic context budgets")
PY

python3 - "$ROOT/tests/budgets/token-budgets.json" "$TMP_ROOT/failing-budgets.json" <<'PY'
import json, sys
budgets = json.load(open(sys.argv[1]))
budgets["metrics"]["portable_protocol_bytes"]["max"] = 1
json.dump(budgets, open(sys.argv[2], "w"))
PY
if "$BENCH" static --root "$ROOT" --budgets "$TMP_ROOT/failing-budgets.json" \
  --check --output "$TMP_ROOT/static-failure.json" >/dev/null 2>&1; then
  echo "FAIL: static budget regression should fail" >&2
  exit 1
fi
echo "  PASS: static regression gate rejects over-budget context"

"$BENCH" live \
  --root "$ROOT" \
  --server-command "python3 '$FAKE_SERVER'" \
  --repeats 2 \
  --output "$TMP_ROOT/live.json" >/dev/null
python3 - "$TMP_ROOT/live.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["kind"] == "codex_app_server"
assert report["summary"]["passed"] is True
assert report["summary"]["turns"] == 6
assert report["summary"]["quality_passes"] == 6
assert report["summary"]["fixture_changed"] is False
assert report["summary"]["cached_input_tokens"] > 0
assert report["summary"]["fixture_reads"] == 6
assert all(row["token_usage"]["input_tokens"] > 0 for row in report["runs"])
assert all(row["ttft_ms"] is not None for row in report["runs"])
assert all(row["quality"]["fixture_reads"] == 1 for row in report["runs"])
print("  PASS: app-server event and quality accounting")
PY

cp "$TMP_ROOT/live.json" "$TMP_ROOT/candidate.json"
"$BENCH" compare "$TMP_ROOT/live.json" "$TMP_ROOT/candidate.json" \
  --check --output "$TMP_ROOT/comparison.json" >/dev/null
python3 - "$TMP_ROOT/comparison.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["kind"] == "benchmark_comparison"
assert report["passed"] is True
assert report["metrics"]["uncached_input_tokens"]["delta_pct"] == 0.0
print("  PASS: paired report comparison and regression gates")
PY

python3 - "$TMP_ROOT/candidate.json" "$TMP_ROOT/candidate-regression.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
report["summary"]["passed"] = False
report["summary"]["quality_passes"] -= 1
json.dump(report, open(sys.argv[2], "w"))
PY
if "$BENCH" compare "$TMP_ROOT/live.json" "$TMP_ROOT/candidate-regression.json" \
  --check --output "$TMP_ROOT/comparison-failure.json" >/dev/null 2>&1; then
  echo "FAIL: quality regression should fail comparison" >&2
  exit 1
fi
echo "  PASS: comparison rejects quality regression"

"$BENCH" pair \
  --baseline-root "$ROOT" \
  --candidate-root "$ROOT" \
  --output-dir "$TMP_ROOT/pair" \
  --server-command "python3 '$FAKE_SERVER'" \
  --case reliability-metrics >/dev/null
python3 - "$TMP_ROOT/pair/comparison.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["passed"] is True
print("  PASS: AB/BA pair orchestration")
PY

"$BENCH" claude-live \
  --root "$ROOT" \
  --claude-command "python3 '$FAKE_CLAUDE'" \
  --repeats 2 \
  --output "$TMP_ROOT/claude-live.json" >/dev/null
python3 - "$TMP_ROOT/claude-live.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
summary = report["summary"]
assert report["kind"] == "claude_code"
assert summary["passed"] is True
assert summary["turns"] == 6
assert summary["quality_passes"] == 6
assert summary["fixture_reads"] == 12
assert summary["cache_creation_input_tokens"] == 1200
assert summary["cache_read_input_tokens"] == 4800
assert summary["total_cost_usd"] == 0.3
assert all(row["permission_denials"] == [] for row in report["runs"])
print("  PASS: Claude stream, cache, cost, tool-evidence, and quality accounting")
PY

"$BENCH" compare "$TMP_ROOT/claude-live.json" "$TMP_ROOT/claude-live.json" \
  --check --output "$TMP_ROOT/claude-comparison.json" >/dev/null
python3 - "$TMP_ROOT/claude-comparison.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["passed"] is True
assert report["metrics"]["total_cost_usd"]["delta_pct"] == 0.0
assert report["gates"]["cost_regression_within_pct"] is True
print("  PASS: Claude token and cost comparison gates")
PY

"$BENCH" claude-pair \
  --baseline-root "$ROOT" \
  --candidate-root "$ROOT" \
  --output-dir "$TMP_ROOT/claude-pair" \
  --claude-command "python3 '$FAKE_CLAUDE'" \
  --case reliability-metrics >/dev/null
python3 - "$TMP_ROOT/claude-pair/comparison.json" <<'PY'
import json, sys
report = json.load(open(sys.argv[1]))
assert report["passed"] is True
print("  PASS: Claude AB/BA pair orchestration")
PY

echo "OK: token benchmark suite passed."
