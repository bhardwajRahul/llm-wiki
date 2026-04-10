# Linting Rules

## Severity Levels

- **Critical**: Broken functionality — missing indexes, broken links, corrupted frontmatter
- **Warning**: Inconsistency — mismatched counts, stale dates, non-bidirectional links
- **Suggestion**: Improvement opportunity — new connections, missing tags, content gaps

## Check Catalog

### C1: Structure (Critical)

- [ ] Master `_index.md` exists
- [ ] `config.md` exists
- [ ] Every subdirectory under `raw/` and `wiki/` has `_index.md`
- [ ] `output/` has `_index.md`
- [ ] Every `.md` file (excluding `_index.md` and `config.md`) has valid YAML frontmatter delimited by `---`

### C2: Frontmatter (Critical/Warning)

- [ ] Every raw source has: title, source, type, ingested, tags, summary
- [ ] Every wiki article has: title, category, sources, created, updated, tags, summary
- [ ] No empty title or summary fields
- [ ] `category` is one of: concept, topic, reference
- [ ] `type` is one of: articles, papers, repos, notes, data
- [ ] `tags` is a list, not empty

### C3: Index Consistency (Warning)

- [ ] Every .md file in a directory appears in that directory's `_index.md` Contents table
- [ ] No `_index.md` references a non-existent file (dead entries)
- [ ] Statistics in master `_index.md` match actual file counts
- [ ] "Last compiled" and "Last lint" dates are present and valid

### C4: Link Integrity (Warning)

- [ ] All markdown links `[text](path)` in wiki articles resolve to existing files
- [ ] All "See Also" links are bidirectional (if A→B, then B→A)
- [ ] All "Sources" links in wiki articles point to existing raw files

### C4b: Source Provenance (Warning)

- [ ] All `sources:` entries in wiki article frontmatter point to existing raw files (no dangling references to deleted/retracted sources)
- [ ] No `<!--RETRACTED-SOURCE-->` markers remain in article body (these should be resolved via `--recompile` or manual review)
- [ ] No raw source file is referenced by zero wiki articles (orphan source — suggest compilation or removal)

### C5: Tag Hygiene (Warning)

- [ ] No near-duplicate tags (e.g., `ml` and `machine-learning`, `nlp` and `natural-language-processing`)
- [ ] Tags in article frontmatter match tags listed in `_index.md` entries
- [ ] Suggest canonical tag when duplicates found

### C6: Coverage (Suggestion)

- [ ] Every raw source is referenced by at least one wiki article's `sources` field
- [ ] No wiki article has an empty `sources` field
- [ ] Articles with overlapping tags that don't link to each other via "See Also" — suggest connection
- [ ] Orphan articles: no incoming "See Also" links from other articles

### C7: Deep Checks (Suggestion, --deep only)

- [ ] Use WebSearch to verify key factual claims in wiki articles
- [ ] Identify articles that could be enhanced with newer information
- [ ] Suggest new articles that would connect existing ones
- [ ] Check for stale sources (ingested > 6 months ago with no recent compilation)

### C8: Project Hygiene (Critical/Warning)

Validates projects that already exist under `output/projects/`. See `references/projects.md` for the full architecture.

- [ ] **C8a** Every `output/projects/<slug>/_project.md` has required frontmatter: `type: project-manifest`, `goal` (non-empty), `status` ∈ {active, archived, retracted}, `created`, `updated` (**Critical** if missing or invalid)
- [ ] **C8b** Every `_project.md` has both `<!-- DERIVED -->` and `<!-- /DERIVED -->` delimiter comments in its Members section (**Critical** — without these, regeneration is disabled)
- [ ] **C8c** Every markdown file inside `output/projects/<slug>/` (excluding `_project.md`) has `project: <slug>` in its frontmatter (**Warning**). Binary files (`.png`, `.jpg`, `.pdf`, `.csv`, `.json`, `.zip`, `.svg`) are exempt.
- [ ] **C8d** Members section is fresh — scan the folder recursively (max 3 levels per spec), compare against the list between the DERIVED delimiters; stale if counts differ or any file is missing/extra (**Warning**)
- [ ] **C8e** `project:` frontmatter value inside a file matches its containing folder slug (**Warning** — flag, but do not auto-fix; it usually indicates a file was moved incorrectly)
- [ ] **C8f** Slug conforms to spec: lowercase, hyphen-separated, ≤40 chars, no dates (**Warning**)
- [ ] **C8g** `.wiki-session.json` (if present) references an existing project slug; stale focus is a no-op, not an error

### C9: Project Candidates (Suggestion)

Surfaces loose `output/` content that should be grouped into projects. **Never auto-fixed** — grouping decisions require human judgment.

- [ ] **C9a** Binary assets (`.png`, `.jpg`, `.pdf`, `.csv`, `.svg`, `.zip`) loose directly in `output/` root (not inside `projects/`) — these cannot stay loose per the projects architecture. Propose the likely owning project based on filename prefix. (**Critical** — architecture violation)
- [ ] **C9b** Any loose markdown output in `output/` that shares a basename prefix with a sibling binary (e.g., `article-foo.md` + `article-foo-hero.jpg`) — suggest projectifying the pair. (**Suggestion**)
- [ ] **C9c** ≥3 loose markdown outputs sharing a common slug prefix (e.g., `article-quantum-v1.md`, `article-quantum-v2.md`, `article-quantum-v3.md`) — suggest grouping under a single project. (**Suggestion**)
- [ ] **C9d** Any subdirectory inside `output/` that is NOT `projects/` and contains files — architecture violation, all subdirectories should be under `output/projects/`. (**Critical**)
- [ ] **C9e** **Fallback**: wiki has ≥3 loose markdown outputs in `output/` AND no `output/projects/` folder exists. Even if C9a–c produced no candidate clusters, prefix-based grouping is often too strict to catch topical clusters (e.g., `comparison-foo.md`, `comparison-bar.md`, `test-summary-A.md`, `test-summary-B.md` all belong to one project but share no leading prefix). Report the wiki as **unmigrated** and suggest a default single-project grouping using the wiki's own name as the slug seed. (**Suggestion**)

**Candidate report format** (for C9b / C9c / C9e):

```
### Project Candidates (N)

Suggested: bitcoin-quantum-fud (proposed slug)
  Reason: 5 files share prefix "article-bitcoin-quantum-fud-"
  Files:
    - article-bitcoin-quantum-fud-2026-04-05.md
    - article-bitcoin-quantum-fud-v2-2026-04-06.md
    - article-bitcoin-quantum-fud-v3-2026-04-06.md
    ...
  Create with:
    /wiki:project new bitcoin-quantum-fud "TODO: fill in goal"
    /wiki:project add bitcoin-quantum-fud article-bitcoin-quantum-fud-2026-04-05.md
    ...
```

**Slug derivation heuristic**:
- **C9c**: longest common prefix of ≥3 files, stripped of trailing hyphens, dates (`YYYY-MM-DD`), version tags (`-v\d+`, `-final`, `-release`), and the `article-` / `output-` / `report-` prefixes. If the result is <4 chars or ambiguous, report without a proposed slug and let the user name it.
- **C9e**: use the topic wiki's own slug (from `wikis.json` or the folder name) as the seed. Drop the `-wiki` suffix if present. Example: `hardware-wallet-security` → slug `hardware-wallet-security` or a shortened variant like `hw-wallet-security`. Always present the slug as a suggestion and let the user override — C9e is the lowest-confidence rule.

## Auto-Fix Rules (when --fix is set)

| Issue | Auto-Fix Action |
|-------|----------------|
| Missing `_index.md` | Generate from directory contents (read frontmatter of each file) |
| File not in index | Add row using file's frontmatter data |
| Dead index entry | Remove the row |
| Statistics mismatch | Recalculate from actual file counts |
| Missing bidirectional link | Add "See Also" entry to the article missing the backlink |
| Empty frontmatter field | Infer: title from `# heading`, summary from first paragraph |
| Near-duplicate tags | Replace all instances with the canonical form |
| Dangling source reference | Remove the entry from `sources:` frontmatter |
| Unresolved retraction marker | Warn: "Retracted claim not yet reviewed — run `/wiki:retract --recompile` or edit manually" |
| **C8b** Missing DERIVED delimiters in `_project.md` | **Warn only** — insert delimiters would risk clobbering hand-written content; report and skip |
| **C8c** Missing `project:` frontmatter in file inside `projects/<slug>/` | Add `project: <slug>` as the first key after the opening `---` (preserves other frontmatter). If the file has no frontmatter at all, prepend a minimal block: `project`, `title` (inferred from `#` heading), `type: output` |
| **C8d** Stale `_project.md` Members section | Regenerate between `<!-- DERIVED -->` delimiters per the folder scan rules in `references/projects.md` § "Derived index regeneration". Update the `updated:` frontmatter field to today. |
| **C8e** Mismatched `project:` frontmatter vs folder | **Warn only** — indicates the file was moved without updating metadata; human must confirm whether the file or the frontmatter is wrong |
| Stale `output/_index.md` when `projects/` exists | Regenerate as a projects-aware listing: table of projects from `_project.md` frontmatter (title, goal, status, updated) + any remaining loose outputs beneath |
| **C9** candidates | **Never auto-fix** — moves are human-authored via `/wiki:project new` + `/wiki:project add` |

## Report Format

```markdown
## Wiki Lint Report — YYYY-MM-DD

### Summary
- Checks run: N
- Issues found: N (N critical, N warnings, N suggestions)
- Auto-fixed: N (if --fix was used)

### Critical Issues
1. [description] — [file path]

### Warnings
1. [description] — [file path]

### Suggestions
1. [suggestion] — [reasoning]

### Coverage
- Sources with no wiki articles: [list]
- Wiki articles with broken links: [list]
- Missing bidirectional links: [list]
- Potential new connections: [list]

### Projects
- Active: N | Archived: N | Retracted: N
- Stale manifests (C8d): [list of slugs]
- Frontmatter drift (C8c/C8e): [list]

### Project Candidates
- [grouped suggestions per C9, formatted as the candidate report block above]
```
