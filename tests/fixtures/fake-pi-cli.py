#!/usr/bin/env python3
"""Deterministic Pi JSON-mode fixture for DS4 benchmark protocol tests."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def value_after(args: list[str], flag: str) -> str:
    try:
        return args[args.index(flag) + 1]
    except (ValueError, IndexError) as exc:
        raise SystemExit(f"missing {flag}") from exc


def emit(payload: dict) -> None:
    print(json.dumps(payload, separators=(",", ":")), flush=True)


def assistant(content: list[dict], stop_reason: str, usage: dict) -> dict:
    return {
        "role": "assistant",
        "content": content,
        "api": "openai-completions",
        "provider": "ds4",
        "model": "deepseek-v4-flash",
        "usage": usage,
        "stopReason": stop_reason,
        "timestamp": 1,
    }


def main() -> int:
    args = sys.argv[1:]
    if args == ["--version"]:
        print("pi 0.test")
        return 0

    required_flags = {
        "--mode": "json",
        "--provider": "ds4",
        "--model": "deepseek-v4-flash",
        "--thinking": "off",
        "--tools": "read,grep,find,ls",
    }
    for flag, expected in required_flags.items():
        actual = value_after(args, flag)
        if actual != expected:
            raise SystemExit(f"{flag}={actual!r}, expected {expected!r}")
    for flag in (
        "--no-session",
        "--offline",
        "--no-extensions",
        "--no-skills",
        "--no-prompt-templates",
        "--no-themes",
    ):
        if flag not in args:
            raise SystemExit(f"missing {flag}")

    instruction = Path(value_after(args, "--append-system-prompt"))
    if not instruction.is_file():
        raise SystemExit("instruction file is missing")
    extension_values = [
        args[index + 1]
        for index, arg in enumerate(args[:-1])
        if arg == "--extension"
    ]
    if not any(Path(value).name == "pi-payload-metrics.ts" for value in extension_values):
        raise SystemExit("payload meter extension is missing")
    if not any(Path(value).name == "pi-query-tools.ts" for value in extension_values):
        raise SystemExit("DS4 query extension is missing")

    prompt = args[-1]
    if "reliability metrics" in prompt:
        output = (
            "The complementary metrics are pass@k for capability and pass^k for "
            "reliability (.wiki/wiki/concepts/sample-concept.md)."
        )
        evidence = ".wiki/wiki/concepts/sample-concept.md"
    elif "Promptfoo" in prompt:
        output = (
            "- Promptfoo is YAML-driven.\n"
            "- DeepEval is Python-native.\n"
            ".wiki/wiki/references/sample-reference.md"
        )
        evidence = ".wiki/wiki/references/sample-reference.md"
    elif "Bitcointalk Archive" in prompt:
        output = (
            "Bitcointalk Archive: Profile available archive formats before ingestion. "
            "(.wiki/inventory/candidates/bitcointalk-archive.md)"
        )
        evidence = ".wiki/inventory/candidates/bitcointalk-archive.md"
    elif "PostgreSQL version" in prompt:
        output = "Not found in the Test Wiki."
        evidence = ".wiki/wiki/_index.md"
    else:
        raise SystemExit("unknown benchmark prompt")

    instruction_bytes = instruction.stat().st_size
    payload_sizes = [7000 + instruction_bytes, 9000 + instruction_bytes]
    metrics_path = Path(os.environ["LLM_WIKI_PI_METRICS_PATH"])
    with metrics_path.open("a", encoding="utf-8") as stream:
        for size in payload_sizes:
            stream.write(
                json.dumps(
                    {
                        "payload_bytes": size,
                        "payload_chars": size,
                        "estimated_tokens": (size + 2) // 3,
                    }
                )
                + "\n"
            )

    usage = {
        "input": 100,
        "output": 10,
        "cacheRead": 20,
        "cacheWrite": 0,
        "totalTokens": 110,
        "cost": {
            "input": 0,
            "output": 0,
            "cacheRead": 0,
            "cacheWrite": 0,
            "total": 0,
        },
    }
    emit({"type": "session", "version": 3, "id": "fake", "cwd": str(Path.cwd())})
    emit({"type": "agent_start"})
    emit({"type": "turn_start"})
    for number, path in enumerate((".wiki/_index.md", evidence), 1):
        call_id = f"read-{number}"
        tool_message = assistant(
            [{"type": "toolCall", "id": call_id, "name": "read", "arguments": {"path": path}}],
            "toolUse",
            usage,
        )
        emit({"type": "message_start", "message": tool_message})
        emit({"type": "message_end", "message": tool_message})
        emit(
            {
                "type": "tool_execution_start",
                "toolCallId": call_id,
                "toolName": "read",
                "args": {"path": path},
            }
        )
        emit(
            {
                "type": "tool_execution_end",
                "toolCallId": call_id,
                "toolName": "read",
                "result": {"content": [{"type": "text", "text": "fixture"}]},
                "isError": False,
            }
        )

    if os.environ.get("FAKE_PI_WRITE") == "1":
        emit(
            {
                "type": "tool_execution_start",
                "toolCallId": "write-1",
                "toolName": "write",
                "args": {"path": "outside.txt", "content": "unexpected"},
            }
        )
        emit(
            {
                "type": "tool_execution_end",
                "toolCallId": "write-1",
                "toolName": "write",
                "result": {"content": [{"type": "text", "text": "unexpected"}]},
                "isError": False,
            }
        )

    final = assistant([{"type": "text", "text": output}], "stop", usage)
    emit({"type": "message_start", "message": final})
    emit(
        {
            "type": "message_update",
            "message": final,
            "assistantMessageEvent": {"type": "text_delta", "delta": output},
        }
    )
    emit({"type": "message_end", "message": final})
    emit({"type": "turn_end", "message": final, "toolResults": []})
    emit({"type": "agent_end", "messages": [final]})
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
