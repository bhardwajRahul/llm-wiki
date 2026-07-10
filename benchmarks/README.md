# Token-Efficiency Benchmarks

This suite separates cheap, deterministic context budgets from cost-bearing
model measurements. It is designed to answer two different questions:

1. Did checked-in prompt or skill material get larger?
2. Did a candidate change reduce real Codex tokens without reducing answer
   quality or changing the fixture?

## Layer 1: deterministic budgets

Run on every commit and in CI:

```bash
./scripts/benchmark-token-efficiency static --check
```

The command measures bytes or characters for the portable protocol, Claude and
Codex skills, Codex activation description, agent metadata, and lazy reference
library. Baselines and hard ceilings live in
`tests/budgets/token-budgets.json`.

These are context-size proxies, not tokenizer estimates. Real model token
counts come from Layer 2.

## Layer 2: Codex app-server

This command makes real model calls and consumes account quota:

```bash
mkdir -p benchmarks/results
./scripts/benchmark-token-efficiency live \
  --model gpt-5.6-sol \
  --repeats 2 \
  --output benchmarks/results/current.json
```

The runner:

- starts Codex app-server over JSON-RPC;
- uses an isolated temporary `HOME` and `CODEX_HOME`, copying only `auth.json`
  when file-based auth is available;
- explicitly loads the Codex wiki skill from the checkout under test;
- copies the synthetic golden wiki into an ephemeral project;
- disables Codex code mode and injects one deterministic, read-only
  `wiki_fixture_read` dynamic tool;
- requires every cold turn to read fixture evidence;
- records app-server `last` token usage, including input, cached input, output,
  reasoning output, and total tokens;
- records uncached input as `input_tokens - cached_input_tokens`, TTFT, total
  latency, compactions, tool calls, and deterministic quality checks;
- hashes the fixture before and after each run and fails if anything changed.

The controlled read tool prevents local shell configuration, MCP servers,
code-mode helper packaging, and filesystem permissions from becoming hidden
variables in a wiki-quality benchmark.

`--repeats 2` runs the same case twice in one thread. The first turn is the
cold quality/context measurement. The second turn measures warm-thread and
provider-cache behavior; it may reuse evidence already present in the thread.

## Paired AB/BA comparison

Use two clean worktrees and the same model, machine, account, and test window:

```bash
./scripts/benchmark-token-efficiency pair \
  --baseline-root /path/to/llm-wiki-baseline \
  --candidate-root /path/to/llm-wiki-candidate \
  --model gpt-5.6-sol \
  --repeats 2 \
  --output-dir benchmarks/results/paired
```

The sequence is baseline, candidate, candidate, baseline. This reduces simple
ordering bias from transient latency and cache conditions. The aggregate
comparison fails unless:

- both reports are independently valid;
- the observed model and turn count match;
- the candidate completes every turn;
- deterministic answer quality is preserved;
- the fixture remains unchanged; and
- uncached input-token regression is at most 2% by default.

Change the final gate only when the experiment has a documented reason:

```bash
--max-input-regression-pct 5
```

To compare existing reports without rerunning models:

```bash
./scripts/benchmark-token-efficiency compare \
  baseline.json candidate.json --check
```

## Cases and results

- Cases: `benchmarks/cases/wiki-query.jsonl`
- Static budgets: `tests/budgets/token-budgets.json`
- Deterministic protocol test: `tests/test-token-benchmarks.sh`
- Local result directory: `benchmarks/results/` (gitignored)

Cases use exact required and forbidden strings rather than another LLM grader.
Add cases when a routing or workflow optimization could change behavior.

## Interpreting cache numbers

`cached_input_tokens` is the cache-read count surfaced by Codex app-server.
The protocol does not expose cache-write tokens or provider billing in this
report. Use provider billing exports separately when dollar-cost attribution is
required. Do not compare latency or cache ratios across different models,
machines, accounts, or substantially different test windows.
