#!/usr/bin/env python3
"""Small JSON-RPC fixture that emulates the app-server events benchmarks use."""

from __future__ import annotations

import json
import sys


thread_number = 0
turn_number = 0
thread_turns: dict[str, int] = {}


def emit(payload: dict) -> None:
    print(json.dumps(payload, separators=(",", ":")), flush=True)


def response(request: dict, result: dict) -> None:
    emit({"jsonrpc": "2.0", "id": request["id"], "result": result})


for line in sys.stdin:
    if not line.strip():
        continue
    request = json.loads(line)
    method = request.get("method")
    if method == "initialize":
        response(
            request,
            {
                "codexHome": "/tmp/fake-codex",
                "platformFamily": "unix",
                "platformOs": "test",
                "userAgent": "fake-codex-app-server/1",
            },
        )
    elif method == "initialized":
        continue
    elif method == "thread/start":
        thread_number += 1
        thread_id = f"thread-{thread_number}"
        thread_turns[thread_id] = 0
        response(
            request,
            {
                "thread": {"id": thread_id},
                "model": request.get("params", {}).get("model") or "fake-model",
                "modelProvider": "fake-provider",
            },
        )
    elif method == "turn/start":
        turn_number += 1
        params = request["params"]
        thread_id = params["threadId"]
        thread_turns[thread_id] += 1
        repeat = thread_turns[thread_id]
        turn_id = f"turn-{turn_number}"
        prompt = " ".join(
            item.get("text", "") for item in params.get("input", []) if item.get("type") == "text"
        )
        response(request, {"turn": {"id": turn_id, "items": [], "status": "inProgress"}})
        tool_request_id = f"tool-request-{turn_number}"
        emit(
            {
                "jsonrpc": "2.0",
                "id": tool_request_id,
                "method": "item/tool/call",
                "params": {
                    "threadId": thread_id,
                    "turnId": turn_id,
                    "callId": f"tool-call-{turn_number}",
                    "tool": "wiki_fixture_read",
                    "arguments": {"path": "_index.md"},
                },
            }
        )
        tool_response = json.loads(sys.stdin.readline())
        if tool_response.get("id") != tool_request_id:
            raise SystemExit("unexpected dynamic tool response")
        if "reliability" in prompt:
            text = "The two complementary metrics are pass@k and pass^k."
        elif "Promptfoo" in prompt:
            text = "- Promptfoo is YAML-driven.\n- DeepEval is Python-native."
        else:
            text = "Bitcointalk Archive: Profile available archive formats before ingestion."
        emit(
            {
                "jsonrpc": "2.0",
                "method": "item/agentMessage/delta",
                "params": {
                    "threadId": thread_id,
                    "turnId": turn_id,
                    "itemId": f"message-{turn_number}",
                    "delta": text,
                },
            }
        )
        input_tokens = 1200 if repeat == 1 else 1250
        cached_tokens = 100 if repeat == 1 else 900
        emit(
            {
                "jsonrpc": "2.0",
                "method": "thread/tokenUsage/updated",
                "params": {
                    "threadId": thread_id,
                    "turnId": turn_id,
                    "tokenUsage": {
                        "total": {
                            "totalTokens": 0,
                            "inputTokens": 0,
                            "cachedInputTokens": 0,
                            "outputTokens": 0,
                            "reasoningOutputTokens": 0,
                        },
                        "last": {
                            "totalTokens": input_tokens + 80,
                            "inputTokens": input_tokens,
                            "cachedInputTokens": cached_tokens,
                            "outputTokens": 80,
                            "reasoningOutputTokens": 20,
                        },
                    },
                },
            }
        )
        emit(
            {
                "jsonrpc": "2.0",
                "method": "item/completed",
                "params": {
                    "threadId": thread_id,
                    "turnId": turn_id,
                    "completedAtMs": 1,
                    "item": {
                        "id": f"message-{turn_number}",
                        "type": "agentMessage",
                        "text": text,
                    },
                },
            }
        )
        emit(
            {
                "jsonrpc": "2.0",
                "method": "turn/completed",
                "params": {
                    "threadId": thread_id,
                    "turn": {"id": turn_id, "items": [], "status": "completed"},
                },
            }
        )
    elif "id" in request:
        emit(
            {
                "jsonrpc": "2.0",
                "id": request["id"],
                "error": {"code": -32601, "message": f"unknown method {method}"},
            }
        )
