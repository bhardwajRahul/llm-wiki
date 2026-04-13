# llm-wiki Development Guide

## Testing

Run tests before declaring any change to plugin code done.

### Structural tests (always run — no LLM, instant)

```bash
./tests/test-plugin-validate.sh   # plugin manifest + command frontmatter
./tests/test-structure.sh          # wiki fixture validation (84 assertions)
```

If you changed the golden wiki fixture, regenerate defect fixtures first:

```bash
./tests/generate-defect-fixtures.sh
```

### Behavioral evals (run when changing command logic)

```bash
npx promptfoo@latest eval -c tests/promptfooconfig.yaml
```

Requires `ANTHROPIC_API_KEY`. Costs ~$2-5 per run.

### When to update tests

- **Added a new lint rule**: add a defect fixture in `generate-defect-fixtures.sh` and a negative test case in `test-structure.sh`.
- **Changed frontmatter schema** (new required field, renamed enum): update the golden wiki fixture files to match, update `test-structure.sh` field/enum lists, regenerate defect fixtures.
- **Added a new command**: add a frontmatter check to `test-plugin-validate.sh` if it's not picked up by the wildcard. Add a behavioral eval in `promptfooconfig.yaml` for routing.
- **Changed the fuzzy router**: add or update test cases in `promptfooconfig.yaml` covering the new routing behavior plus negative controls.
- **Added a new reference file**: the `test-plugin-validate.sh` reference list must match — add the new filename.
- **Changed directory structure** (new `raw/` or `wiki/` subdirectory): update `test-structure.sh` C1 directory list and C11 placement checks. Update the golden wiki fixture if needed.

### Test file locations

- `tests/fixtures/golden-wiki/` — known-correct wiki (3 sources, 2 articles, all indexes)
- `tests/fixtures/defects/` — generated broken wikis (one per lint rule)
- `tests/promptfooconfig.yaml` — Promptfoo behavioral eval config
- `tests/evals/assertions/*.js` — custom JS assertions for file-system checks
- `tests/ci/plugin-tests.yml` — GitHub Actions workflow (copy to `.github/workflows/` to activate)

## Project Structure

```
claude-plugin/
  commands/*.md      — 12 subcommand definitions
  skills/wiki-manager/
    SKILL.md          — skill manifest + fuzzy router
    references/*.md   — 9 reference docs (hub-resolution, linting, etc.)
  .claude-plugin/
    plugin.json       — plugin manifest
AGENTS.md             — portable single-file protocol for non-Claude agents
tests/                — test suite (see above)
```

## Release Process

See `.claude/release-checklist.md` for the full ship process. Run both test scripts before bumping version.
