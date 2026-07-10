#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE="$ROOT/claude-plugin/skills/wiki-manager/references/query-lite.md"
TARGET="$ROOT/profiles/query-lite/SKILL.md"

if [[ ! -f "$SOURCE" ]]; then
  echo "Missing query-lite source: $SOURCE" >&2
  exit 1
fi

mkdir -p "$(dirname "$TARGET")"
cat > "$TARGET" <<'EOF'
---
name: wiki-query
description: >
  Fast, read-only, index-first queries over an llm-wiki with bounded file
  reads, exact citations, and honest evidence gaps.
---

EOF
cat "$SOURCE" >> "$TARGET"

echo "Synced portable query-lite profile from Claude reference source."
echo "Source: $SOURCE"
echo "Target: $TARGET"
