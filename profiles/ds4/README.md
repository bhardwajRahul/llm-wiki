# DS4 Query Profile

`wiki-query/SKILL.md` is a compact, read-only profile for local DS4 models.
It covers the common query and inventory-lookup paths without loading the full
research, ingestion, compilation, and maintenance instructions.

With Pi, load the profile and its small query adapter, then expose only
read-only tools:

```bash
pi \
  --extension profiles/ds4/pi-query-tools.ts \
  --append-system-prompt profiles/ds4/wiki-query/SKILL.md \
  --tools read,grep,find,ls
```

Keep the existing full `wiki-manager` skill for write-capable research and
maintenance. Do not give a local query profile write tools merely for
convenience; switch profiles when the requested workflow changes.

The DS4 benchmark runner uses the same file and tool surface:

```bash
./scripts/benchmark-token-efficiency ds4-live \
  --pi-command "pi" \
  --output benchmarks/results/ds4-lite.json
```

The benchmark loads `pi-query-tools.ts` automatically. Do not combine this
read-only profile with a general DS4 adapter that injects editing, shell, or
scaffolding instructions. `--extension` is reserved for transport adapters
that do not change the query contract.
