# Token-Efficiency Benchmarks

This suite separates cheap, deterministic context budgets from cost-bearing
model measurements. It is designed to answer two different questions:

1. Did checked-in prompt or skill material get larger?
2. Did a candidate change reduce real Codex or Claude tokens without reducing answer
   quality or changing the fixture?

## Layer 1: deterministic budgets

Run on every commit and in CI:

```bash
./scripts/benchmark-token-efficiency static --check
```

The command measures bytes or characters for the portable protocol, Claude and
Codex skills and activation descriptions, Claude plugin manifest and commands,
Codex agent metadata, and the lazy reference library. Baselines and hard ceilings live in
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

## Layer 3: Claude Code

Claude Code exposes cache creation, cache reads, cost, TTFT, API duration, and
tool-use events in its stream-json result:

```bash
./scripts/benchmark-token-efficiency claude-live \
  --model claude-sonnet-4-6 \
  --repeats 2 \
  --output benchmarks/results/claude-current.json
```

The Claude runner loads the checkout with `--plugin-dir`, allows only `Read`
and `Skill`, disables user settings and MCP servers, and requires successful
reads from the synthetic `.wiki`. Each repeat is a fresh Claude Code process so
cache behavior reflects reusable prompt prefixes rather than conversation
history. Claude input accounting is:

```text
total input = input_tokens + cache_creation_input_tokens + cache_read_input_tokens
uncached input = input_tokens + cache_creation_input_tokens
```

The report also records `total_cost_usd`. Local subscription runs are useful
for token and behavior comparisons; CI should use a dedicated
`ANTHROPIC_API_KEY` when billed cost must be reproducible.

## Codex paired AB/BA comparison

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

## Claude paired AB/BA comparison

```bash
./scripts/benchmark-token-efficiency claude-pair \
  --baseline-root /path/to/llm-wiki-baseline \
  --candidate-root /path/to/llm-wiki-candidate \
  --model claude-sonnet-4-6 \
  --output-dir benchmarks/results/claude-paired
```

Claude comparisons add a 5% cost-regression ceiling by default. Override it
only for a documented experiment:

```bash
--max-cost-regression-pct 10
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

For Codex, `cached_input_tokens` is the cache-read count surfaced by app-server;
the protocol does not expose cache writes or billing. For Claude, cache creation
and cache reads are separate and the CLI reports estimated USD cost. Do not
compare latency, cost, or cache ratios across different models, machines,
accounts, or substantially different test windows.
