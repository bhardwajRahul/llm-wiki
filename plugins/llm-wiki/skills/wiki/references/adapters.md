# Private Adapter Protocol

## Purpose

Private adapters let llm-wiki invoke locally installed research tools without
publishing their source code, credentials, corpora, or generated bulk data.
The public llm-wiki project defines the `llm-wiki-adapter/v1` control-plane
contract; adapter implementations remain in their own local or private repos.

An adapter repository is always a **tool-only, content-free code plane**. It
may contain executable code, manifests, schemas, documentation, tests, and
synthetic fixtures generated in temporary test directories. It must never
contain real source content, source-specific case configuration, corpora,
captures, documents, recordings, transcripts, indexes, credentials, generated
results, evidence packets, or source-specific identifiers. Private visibility
is defense in depth, not permission to mix code and content.

This is separate from `ingest-collection --adapter`. Collection adapters are
agent instructions for known upstream formats. Private adapters are explicitly
registered executables with a machine-local trust and path policy.

## Registry

Registrations live at:

```text
~/.config/llm-wiki/adapters.json
```

The registry is machine-local, mode `0600`, and never belongs in `wikis.json`,
the hub, a topic wiki, session context, or a public repository. It stores local
paths, argv arrays, declared capabilities, allowed environment-variable names,
and read/write roots. It never stores environment-variable values.

Registration is explicit and local. llm-wiki does not clone, install, update,
publish, or mirror adapter repositories.

## Repository naming

Private adapter repositories use the prefix convention:

```text
llm-wiki-adapter-<domain>-<capability>
```

The manifest id is the stable lowercase kebab-case portion after the prefix:

```text
<domain>-<capability>
```

For example, repository `llm-wiki-adapter-x-community-intelligence` declares
manifest id `x-community-intelligence`. Do not put `private`, an owner name, or
a version in either name. Reserve `intelligence` for substantive analysis;
use narrower terms such as `sync`, `indexing`, `validation`, or
`transcription` when they describe the tool more accurately. Content
repositories remain separately named, for example `bitcoin-wiki`.

## Locate the bundled CLI

Use the bundled `bin/llm-wiki` from the installed plugin root. Claude exposes
`$CLAUDE_PLUGIN_ROOT`; Codex supplies the installed skill path, whose plugin
root is two directories above `skills/wiki/SKILL.md`; OpenCode uses its loaded
plugin path. In a source checkout, use `scripts/llm-wiki`.

Do not assume a globally installed `llm-wiki` executable. In examples below,
`LLM_WIKI` means the resolved bundled or source-checkout executable.

## Adapter manifest

Every adapter root contains `.llm-wiki-adapter.json`:

```json
{
  "protocol": "llm-wiki-adapter/v1",
  "id": "example-analysis",
  "version": "1.0.0",
  "distribution": "private",
  "entrypoint": [".venv/bin/python", "-m", "example.adapter"],
  "capabilities": ["corpus-validation", "analysis"],
  "network": "none",
  "writes_wiki": false,
  "operations": {
    "analyze": {
      "read_arguments": ["case"],
      "requires_output_dir": true
    }
  },
  "output_classes": ["wiki-safe", "private", "bulk"]
}
```

The entrypoint must implement:

```text
<entrypoint> describe
<entrypoint> execute --request <json-path> --response <json-path>
```

`describe` prints one JSON object matching the manifest identity, version, and
capabilities. `execute` writes exactly one response document. Diagnostic output
may go to stderr, but llm-wiki does not persist or echo it by default.

## Request and response

Request:

```json
{
  "protocol": "llm-wiki-adapter/v1",
  "adapter_id": "example-analysis",
  "operation": "analyze",
  "arguments": {"case": "/absolute/private/case.json"},
  "output_dir": "/absolute/private/results/run-1",
  "options": {}
}
```

Response:

```json
{
  "protocol": "llm-wiki-adapter/v1",
  "adapter_id": "example-analysis",
  "adapter_version": "1.0.0",
  "operation": "analyze",
  "status": "ok",
  "run_id": "stable-run-id",
  "summary": {},
  "artifacts": [
    {
      "path": "evidence-packet.json",
      "sha256": "64-lowercase-hex-characters",
      "class": "wiki-safe",
      "media_type": "application/json",
      "role": "evidence-packet"
    }
  ]
}
```

Path arguments declared by the operation must be absolute, must exist, and
must stay inside registered read roots. `output_dir` and every returned
artifact must stay inside registered write roots. Artifact files and SHA-256
values are verified after execution.

## Commands

```bash
$LLM_WIKI adapter add /private/adapter \
  --read-root /private/input \
  --write-root /private/results
$LLM_WIKI adapter list
$LLM_WIKI adapter show example-analysis
$LLM_WIKI adapter doctor example-analysis
$LLM_WIKI adapter run example-analysis --request /private/request.json --json
$LLM_WIKI adapter remove example-analysis --yes
```

`add` trusts an existing checkout but does not fetch it. `doctor` verifies the
manifest hash, executable, and `describe` handshake. Manifest drift blocks
execution until the user explicitly re-registers with `add --replace`.

## Wiki promotion boundary

Adapters never receive a wiki write path and must declare `writes_wiki: false`.
Execution only produces external artifacts and a verified receipt. It never
imports content into `raw/`, `wiki/`, `output/`, inventory, or datasets.
The executable may read authorized external inputs and write authorized
external runtime results, but it does not own, embed, publish, or automatically
surface that content. Inputs and outputs belong to the separately controlled
data plane.
This is a protocol and workflow boundary, not an operating-system sandbox:
explicitly registered adapter code runs with the permissions of its parent
process, so register only code you trust.

After a successful run:

1. inspect only artifacts labeled `wiki-safe`;
2. treat that label as an import candidate, not proof of correctness;
3. review content, provenance, identifiers, and privacy before writing;
4. keep `private` and `bulk` artifacts outside the wiki;
5. create a compact immutable raw note or repository/run note when useful;
6. compile bounded conclusions through the normal workflow; and
7. append the resulting wiki write to topic and hub logs.

Never auto-promote adapter output. Never infer that private repository access
authorizes redistribution, protected-content access, sensitive inference, or
publication of corpus-derived individual data.

## Security properties and limits

- Execution uses an argv array with `shell=False` and a timeout.
- Only a small base environment plus explicitly allowlisted variable names is
  passed; secret values are not stored in the registry.
- Manifest drift, path escape, missing artifacts, and hash mismatch fail closed.
- Adapter code, installation, dependencies, authentication, and updates remain
  the adapter owner's responsibility.
- The outer operating-system sandbox remains the actual enforcement boundary;
  registry scopes are an additional validation layer, not a sandbox escape.
- Network use must be declared as `none`, `optional`, or `required` and still
  requires the runtime's normal network permissions.
