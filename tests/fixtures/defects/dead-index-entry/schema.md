---
title: "Test Wiki Schema"
schema_state: advisory
created: 2026-01-10
updated: 2026-01-10
summary: "Topic-local vocabulary, relationship, and migration conventions for this llm-wiki topic."
---

# Test Wiki Schema

> This file is human-owned. The librarian may propose changes, but it should not rewrite this schema without explicit user approval.

## State

- `schema_state`: `advisory`
- `advisory` means report mismatches as suggestions only.
- `strict` means warn on violations; strict mode still must not auto-rewrite content.

## Entity Types

| Type | Meaning |
|------|---------|
| `concept` | Bounded idea or mechanism compiled under `wiki/concepts/`. |
| `topic` | Broad theme or playbook compiled under `wiki/topics/`. |
| `reference` | Curated list, map, standard, or lookup page under `wiki/references/`. |
| `source` | Raw evidence under `raw/`; factual claims should trace back here. |
| `artifact` | Generated output, project file, inventory record, or dataset manifest. |

## Relationship Verbs

- `cites`: article or output cites a raw source.
- `supports`: source or article supports a claim, plan, or decision.
- `contradicts`: source or article conflicts with another claim.
- `supersedes`: newer article/output replaces an older one.
- `depends-on`: artifact or workflow relies on another artifact.
- `implements`: code, output, or project implements a plan.
- `relates-to`: weak relationship used when a stronger verb is not yet justified.

## Source Conventions

- Keep raw sources immutable under `raw/`.
- Compile durable synthesis under `wiki/` with explicit `sources:` frontmatter.
- Keep generated deliverables under `output/`.
- Use inventory for durable tracking state, not factual evidence.
- Use dataset manifests for large, mutable, binary, remote, or query-oriented data.

## Migration Notes

- Existing articles do not need immediate rewrites to adopt this schema.
- Librarian schema scans should propose changes in `output/schema-proposal-*.md`.
- Promote only the small conventions that fit this topic; delete unused starter rows.
- Switch `schema_state` to `strict` only after advisory reports are low-noise.
