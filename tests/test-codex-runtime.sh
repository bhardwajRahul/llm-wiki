#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(dirname "$SCRIPT_DIR")"

if ! command -v codex >/dev/null 2>&1; then
  echo "SKIP: codex binary not found"
  exit 0
fi

mkdir -p "$ROOT/.tmp"
TMP_ROOT="$(mktemp -d "$ROOT/.tmp/codex-test.XXXXXX")"
USER_HOME="$TMP_ROOT/user-home"
PROJECT_ROOT="$TMP_ROOT/project"
mkdir -p "$USER_HOME" "$PROJECT_ROOT"
git -C "$PROJECT_ROOT" init -q
trap 'rm -rf "$TMP_ROOT"' EXIT

echo "=== Codex clean-home user install ==="
"$ROOT/scripts/bootstrap-codex-plugin.sh" \
  --scope user \
  --user-home "$USER_HOME" \
  --verify

# Reinstalling the same local version should refresh the cache without
# duplicating the plugin table in config.toml.
"$ROOT/scripts/bootstrap-codex-plugin.sh" \
  --scope user \
  --user-home "$USER_HOME" \
  --verify

USER_VERSION="$(python3 - "$USER_HOME/.codex/config.toml" <<'PY'
import sys
from pathlib import Path

config = Path(sys.argv[1]).read_text()
if '[plugins."wiki@llm-wiki"]' not in config:
    raise SystemExit("user install did not enable wiki@llm-wiki")
print("ok")
PY
)"
[[ "$USER_VERSION" == "ok" ]]
if [[ "$(grep -Fc '[plugins."wiki@llm-wiki"]' "$USER_HOME/.codex/config.toml")" -ne 1 ]]; then
  echo "FAIL: repeated bootstrap duplicated wiki@llm-wiki config" >&2
  exit 1
fi

echo
echo "=== Unsupported project-scope guard ==="
set +e
PROJECT_SCOPE_OUTPUT="$("$ROOT/scripts/bootstrap-codex-plugin.sh" \
  --scope project \
  --project-root "$PROJECT_ROOT" \
  --user-home "$USER_HOME" 2>&1)"
PROJECT_SCOPE_STATUS=$?
set -e
if [[ "$PROJECT_SCOPE_STATUS" -eq 0 ]] || [[ "$PROJECT_SCOPE_OUTPUT" != *"not supported by Codex 0.144"* ]]; then
  echo "FAIL: project scope should fail with a clear Codex 0.144 compatibility message" >&2
  exit 1
fi

echo "OK: Codex clean-home user install resolves @wiki without interactive materialization."
