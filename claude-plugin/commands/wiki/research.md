---
description: "Deep multi-agent research on a topic. Searches the web, ingests multiple sources, and compiles them into wiki articles — automated research pipeline."
argument-hint: "<topic> [--sources <N>] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), WebFetch, WebSearch, Agent
---

## Your task

First, check if a wiki exists by trying to read `~/wiki/_index.md` (global) and `.wiki/_index.md` (local).

Conduct deep research on the topic in $ARGUMENTS. This is an automated pipeline: search → ingest → compile.

### Resolve wiki location

1. `--local` → `.wiki/`
2. `--wiki <name>` → look up in `~/wiki/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → `~/wiki/`

If wiki does not exist, stop: "No wiki found. Run `/wiki init` first."

### Parse $ARGUMENTS

- **topic**: The research topic — everything that is not a flag
- **--sources <N>**: Target number of sources to find and ingest (default: 5)

### Research Protocol

#### Phase 1: Existing Knowledge Check

1. Read `wiki/_index.md` and `raw/_index.md` to understand what the wiki already knows about this topic
2. Use Grep to search for the topic and related terms across existing articles
3. Identify gaps — what specific aspects are NOT covered yet?

#### Phase 2: Web Research (parallel when possible)

Launch up to 3 parallel search agents to maximize coverage:

1. **Agent 1 — Academic/technical**: WebSearch for peer-reviewed papers, technical articles, and authoritative sources on the topic. Prioritize recent publications.

2. **Agent 2 — Practical/applied**: WebSearch for practical guides, case studies, real-world applications, and expert commentary on the topic.

3. **Agent 3 — News/recent developments**: WebSearch for recent news, breakthroughs, clinical trials, or developments related to the topic.

Each agent should:
- Search for 3-5 relevant URLs
- For each URL, use WebFetch to extract the full content
- Return: title, URL, extracted content, and a quality assessment (is this worth ingesting?)

#### Phase 3: Ingest

For each high-quality source found (up to --sources count):

1. Write the source to `raw/{type}/YYYY-MM-DD-slug.md` with proper frontmatter (title, source URL, type, tags, summary)
2. Auto-detect type: academic → papers, news → articles, code → repos, everything else → articles
3. Update `raw/{type}/_index.md` and `raw/_index.md`

#### Phase 4: Compile

1. Read all newly ingested sources
2. Follow the compilation protocol in `skills/wiki-manager/references/compilation.md`:
   - Extract key concepts, facts, relationships
   - Map to existing wiki articles
   - Create new articles or update existing ones
   - Use dual-link format for all cross-references
   - Set confidence levels based on source quality
   - Add bidirectional See Also links
3. Update all `_index.md` files
4. Update master `_index.md` with new stats

#### Phase 5: Report & Log

1. Append to `log.md`: `## [YYYY-MM-DD] research | "topic" → N sources ingested, M articles compiled`

2. Report:
   - **Topic researched**: the query
   - **Sources found**: N total, M ingested (list with URLs)
   - **Sources skipped**: list with reason (low quality, duplicate, paywall)
   - **Articles created**: list with paths and summaries
   - **Articles updated**: list with what was added
   - **New connections**: cross-references discovered
   - **Remaining gaps**: what still isn't covered, suggested follow-up searches
   - Suggest: `/wiki:lint` to verify consistency, or `/wiki:research "subtopic"` to go deeper on a specific gap
