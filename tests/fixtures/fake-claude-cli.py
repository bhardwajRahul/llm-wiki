#!/usr/bin/env python3
"""Emit a small Claude Code stream-json transcript for deterministic tests."""

from __future__ import annotations

import json
import sys
from pathlib import Path


def argument(name: str, default: str = "") -> str:
    try:
        return sys.argv[sys.argv.index(name) + 1]
    except (ValueError, IndexError):
        return default


def emit(payload: dict) -> None:
    print(json.dumps(payload, separators=(",", ":")), flush=True)


prompt = argument("-p")
model = argument("--model", "fake-claude-model")
cwd = Path.cwd()
if "reliability" in prompt:
    target = "wiki/concepts/sample-concept.md"
    answer = "The two complementary metrics are pass@k and pass^k."
elif "Promptfoo" in prompt:
    target = "wiki/references/sample-reference.md"
    answer = "- Promptfoo is YAML-driven.\n- DeepEval is Python-native."
else:
    target = "inventory/candidates/bitcointalk-archive.md"
    answer = "Bitcointalk Archive: Profile available archive formats before ingestion."

emit(
    {
        "type": "system",
        "subtype": "init",
        "cwd": str(cwd),
        "session_id": "fake-session",
        "tools": ["Read", "Skill"],
        "model": model,
        "permissionMode": "dontAsk",
        "mcp_servers": [],
        "plugins": [{"name": "wiki", "source": "wiki@inline"}],
    }
)

for number, relative in enumerate(("_index.md", target), 1):
    full_path = cwd / ".wiki" / relative
    tool_id = f"tool-{number}"
    emit(
        {
            "type": "assistant",
            "message": {
                "model": model,
                "content": [
                    {
                        "type": "tool_use",
                        "id": tool_id,
                        "name": "Read",
                        "input": {"file_path": str(full_path)},
                    }
                ],
            },
        }
    )
    emit(
        {
            "type": "user",
            "message": {
                "role": "user",
                "content": [
                    {"type": "tool_result", "tool_use_id": tool_id, "content": "fixture"}
                ],
            },
            "tool_use_result": {
                "type": "text",
                "file": {
                    "filePath": str(full_path),
                    "content": "fixture",
                    "numLines": 1,
                },
            },
        }
    )

emit(
    {
        "type": "result",
        "subtype": "success",
        "is_error": False,
        "duration_ms": 1200,
        "duration_api_ms": 900,
        "ttft_ms": 300,
        "num_turns": 3,
        "result": answer,
        "session_id": "fake-session",
        "total_cost_usd": 0.05,
        "usage": {
            "input_tokens": 10,
            "cache_creation_input_tokens": 200,
            "cache_read_input_tokens": 800,
            "output_tokens": 20,
            "cache_creation": {
                "ephemeral_1h_input_tokens": 200,
                "ephemeral_5m_input_tokens": 0,
            },
        },
        "modelUsage": {
            model: {
                "inputTokens": 10,
                "outputTokens": 20,
                "cacheReadInputTokens": 800,
                "cacheCreationInputTokens": 200,
                "costUSD": 0.05,
            }
        },
        "permission_denials": [],
        "terminal_reason": "completed",
    }
)
