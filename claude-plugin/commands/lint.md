---
description: "Run health checks on the wiki. Find broken links, missing indexes, stale content, inconsistencies, and suggest improvements."
argument-hint: "[--fix] [--deep] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), WebSearch
---

## Your task

First, resolve **HUB** by following the protocol in `references/hub-resolution.md` (check `~/wiki/` first, then config, expand leading `~` only, quote paths with spaces). Then check if a wiki exists by trying to read `HUB/_index.md` (global hub) and `.wiki/_index.md` (local).

Read the linting rules at `skills/wiki-manager/references/linting.md`. Then run health checks on the wiki.

### Resolve wiki location

1. `--local` → `.wiki/`
2. `--wiki <name>` → look up in `HUB/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → HUB

If wiki does not exist, stop: "No wiki found. Run `/wiki init` first."

### Parse $ARGUMENTS

- **--fix**: Automatically fix issues found (default: report only)
- **--deep**: Also use WebSearch to fact-check claims and find missing information

### Run Checks

Execute checks from `references/linting.md` in order:

#### 1. C1: Structure (Critical)
Verify all required directories and `_index.md` files exist.

#### 2. C2: Frontmatter (Critical/Warning)
Read each `.md` file's frontmatter. Check required fields exist and have valid values.

#### 3. C3: Index Consistency (Warning)
Compare actual directory contents against `_index.md` entries. Verify statistics match.

#### 4. C4: Link Integrity (Warning)
For each wiki article, extract all markdown links. Verify each resolves to an existing file. Check bidirectional "See Also" links.

#### 5. C5: Tag Hygiene (Warning)
Collect all tags across all files. Find near-duplicates. Check consistency between files and indexes.

#### 6. C6: Coverage (Suggestion)
Check that every raw source is referenced by at least one wiki article. Find orphan articles with no incoming links.

#### 7. C7: Deep Checks (only if --deep)
Use WebSearch to spot-check key claims. Identify stale content. Suggest new connections and articles.

#### 8. C8: Project Hygiene (Critical/Warning)
For each `output/projects/<slug>/_project.md`:
- Validate frontmatter (`type: project-manifest`, `goal`, `status`, `created`, `updated`)
- Verify `<!-- DERIVED -->` / `<!-- /DERIVED -->` delimiters present in the Members section
- Scan the project folder recursively (max 3 levels) and diff against the rendered Members list
- Check every markdown file inside the project folder has `project: <slug>` frontmatter
- Check that the `project:` value matches the containing folder slug
- Validate slug format (lowercase, hyphen-separated, ≤40 chars, no dates)

See `references/projects.md` § "Derived index regeneration" and `references/linting.md` § C8.

#### 9. C9: Project Candidates (Suggestion)
Scan `output/` (excluding `projects/`) for migration candidates:
- **Critical**: loose binaries (`.png`, `.jpg`, `.pdf`, `.csv`, `.svg`, `.zip`) in `output/` root — architecture violation
- **Critical**: any non-`projects/` subdirectory inside `output/` containing files — architecture violation
- **Suggestion**: markdown outputs with sibling binaries sharing a basename prefix (e.g., `article-foo.md` + `article-foo-hero.jpg`)
- **Suggestion**: ≥3 markdown outputs sharing a common prefix — strip dates, version tags (`-v\d+`, `-final`, `-release`), and type prefixes (`article-`, `output-`, `report-`) before comparing
- **Suggestion (fallback)**: ≥3 loose markdown outputs and no `output/projects/` folder exists — report as unmigrated wiki with a default single-project seed using the wiki slug. This catches topical clusters that don't share a leading prefix.

For each candidate cluster, compute a proposed slug per the heuristic in `references/linting.md` § C9 and output a ready-to-paste `/wiki:project new` + `/wiki:project add` block.

### If --fix

For each fixable issue, apply the auto-fix from the rules table in `references/linting.md`. Report what was fixed.

IMPORTANT: Only auto-fix issues with clear, unambiguous fixes — missing index entries, broken stats, stale `_project.md` Members sections, missing `project:` frontmatter on files already inside project folders, stale `output/_index.md` when `projects/` exists, etc. Do NOT auto-fix content quality issues. Do NOT move files into projects — C9 candidates are human-authored via `/wiki:project new` + `/wiki:project add`. Do NOT rewrite articles.

### Report

Present the lint report in the format specified in `references/linting.md`, including the **Projects** and **Project Candidates** sections. Update master `_index.md` with "Last lint" date. Append to `log.md`: `## [YYYY-MM-DD] lint | N checks, N critical, N warnings, N suggestions, N candidates, N auto-fixed`
