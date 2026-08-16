---
description: "Register, inspect, validate, and run explicitly trusted local private adapters without putting their code or bulk data in the wiki."
argument-hint: "add <path>|list|show <id>|doctor <id>|run <id> --request <json>|remove <id> --yes"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(date:*), Bash(python3:*), Bash(scripts/llm-wiki:*), Bash(${CLAUDE_PLUGIN_ROOT}/bin/llm-wiki:*)
---

## Your task

Manage or invoke a private llm-wiki adapter through the deterministic bundled
CLI. Read `skills/wiki-manager/references/adapters.md` before acting.

Private-adapter management is wiki-neutral. Do not put executable registrations
or absolute machine paths in `wikis.json` or a topic wiki. Resolve a topic wiki
only when the user asks to promote a reviewed result after execution.

## Auto-routed Google Docs edits

When the router passes an edit verb plus a
`https://docs.google.com/document/d/...` URL, select registered adapter id
`google-docs-editing`; do not send the URL to ingestion. Run `list`, `show`, and
`doctor`, then check the exact target against the registered remote resources
before doing anything with OAuth. If registered, skip authorization. If not,
use the adapter's pinned Google Picker flow once and preserve all existing
roots, environment names, and remote resources when adding the new exact
resource.

Inspect and plan privately, create only exact replacements that faithfully
implement the user's bounded instruction, and keep the exact document active
in the paired normal Chrome window. The imperative is explicit approval for
that plan; compute and pass its hash to `--approve-remote-write` internally
instead of asking the user to paste a hash. Apply as tracked suggestions and
run the separate `verify` operation before reporting success. A URL without a
clear edit instruction requires clarification, not an invented write. Normal
edits require no extension click; pair only during one-time setup.

## Locate the CLI

For Claude Code, use:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/llm-wiki" adapter <subcommand>
```

In a source checkout, use `scripts/llm-wiki`. Other runtimes should use the
bundled `bin/llm-wiki` relative to the installed plugin root described in the
adapter reference. Do not assume the command is globally installed.

## Management operations

- `add <path>`: require an existing local checkout and explicit read/write
  roots. Add exact `--remote-resource` values only when the user authorized
  them. Never clone a repo or request credentials. Use `--replace` only when the
  user intends to trust a changed manifest.
- `list`: show compact id, version, capability, network, and local-root data.
- `show <id>`: show the machine-local registration; do not print environment
  variable values.
- `doctor <id>`: verify manifest hash, executable, and handshake before a run.
- `remove <id> --yes`: remove only the registration. Never delete adapter code,
  inputs, or outputs.

## Run operation

1. Inspect the request JSON without opening referenced corpora or secrets.
2. Confirm the adapter id, operation, declared paths, and requested output
   directory match the user's intent.
3. Run `doctor`; stop on any issue.
4. For `remote-write`, confirm the user explicitly approved the exact plan,
   expected revision, target resource, and idempotency key. Invoke with
   `--approve-remote-write <plan-sha256>` and a private `--response` path inside
   the registered write root. Never infer approval from a request file alone.
5. Invoke `adapter run <id> --request <absolute-path> --json`.
6. Report the run id, bounded summary, and artifact counts by class.
7. Do not import anything automatically.

If the user asks to update the wiki, inspect only `wiki-safe` artifacts. Review
them as candidates, keep `private` and `bulk` artifacts external, write the
smallest useful raw note/evidence packet, compile bounded conclusions, update
indexes, and append the normal topic and hub logs.

Private visibility is an access control, not permission to redistribute data or
perform protected-content collection, deanonymization, sensitive inference,
targeting, harassment, or other prohibited analysis.
