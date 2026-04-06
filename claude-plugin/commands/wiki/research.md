---
description: "Deep multi-agent research on a topic. Launches parallel agents to search the web across multiple angles, ingests sources, and compiles them into wiki articles. Can create a new topic wiki automatically."
argument-hint: "<topic> [--new-topic] [--sources <N>] [--deep] [--retardmax] [--min-time <duration>] [--wiki <name>] [--local]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash(ls:*), Bash(wc:*), Bash(date:*), Bash(mkdir:*), WebFetch, WebSearch, Agent
---

## Your task

Conduct deep research on the topic in $ARGUMENTS. This is an automated pipeline: search → ingest → compile.

### Parse $ARGUMENTS

- **topic**: The research topic — everything that is not a flag
- **--new-topic**: Create a new topic wiki from the topic name and start researching into it. Works from any directory. Derives the wiki slug from the topic (e.g., "quantum error correction" → `quantum-error-correction`).
- **--sources <N>**: Target sources PER ROUND (default: 5, max: 20)
- **--deep**: 8 parallel agents with broader search angles
- **--retardmax**: 10 agents, skip planning, ingest aggressively
- **--min-time <duration>**: Minimum research time. Keep running research rounds until this duration is reached. Formats: `30m`, `1h`, `2h`, `4h`. Default: single round (no minimum).
- **--wiki <name>**: Target a specific existing topic wiki
- **--local**: Use project-local `.wiki/`

### Resolve wiki location

**If `--new-topic` is set:**
1. Derive a slug from the topic: lowercase, hyphens, no special chars, max 40 chars
2. If `~/wiki/` hub doesn't exist, create it (wikis.json + _index.md + log.md + topics/)
3. Create the new topic wiki at `~/wiki/topics/<slug>/` following the full init protocol (directory structure, .obsidian/, empty _index.md files, config.md, log.md)
4. Register in `~/wiki/wikis.json` and update hub `_index.md`
5. Target this new wiki for all research that follows

**If `--new-topic` is NOT set:**
1. `--local` → `.wiki/`
2. `--wiki <name>` → look up in `~/wiki/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → ask which topic wiki to target

If no wiki is resolved, stop: "No wiki found. Use `--new-topic` to create one, or run `/wiki init <topic>` first."

### Minimum Time Research (`--min-time`)

When `--min-time` is set, research runs in ROUNDS until the time budget is spent:

```
Round 1: Run full research protocol (Phase 1-5)
         → Produces gaps and suggested follow-ups
         → Check elapsed time

Round 2: Pick the top 3 gaps from Round 1
         → Run research on each gap as a subtopic
         → Compile into wiki, discover new gaps
         → Check elapsed time

Round 3: Pick the top 3 gaps from Round 2
         → Run research on each gap
         → Continue until --min-time is reached

Final:   Run /wiki:lint --fix to clean up
         → Generate a summary of everything researched
         → Report total: rounds, sources, articles, time spent
```

**Round strategy:**
- Each round picks the most important unfilled gaps from the previous round's report
- Subtopics get progressively more specific as rounds continue (broad → narrow → niche)
- If a round finds no new gaps, switch to `--deep` mode on existing articles to find connections and contradictions
- If still no gaps after deep mode, research is complete regardless of remaining time — report early completion
- Each round logs to `log.md` independently

**Time tracking:**
- Check wall clock at the start and after each round
- A round that would exceed the time budget by more than 50% should not start (e.g., if 45 min left and rounds average 40 min, run it; if 10 min left, don't)
- Report time spent in final summary

**Example:**
```
/wiki:research "CRISPR gene therapy" --new-topic --min-time 2h --deep
```
Creates `~/wiki/topics/crispr-gene-therapy/`, then runs ~3-5 research rounds over 2 hours, progressively drilling into subtopics the earlier rounds surfaced.

### Input Detection: Topic vs Question

Before starting research, detect whether the input is a **topic** or a **question**:

- **Topic**: a noun/phrase naming a subject area. Examples: "nutrition", "CRISPR", "viral content"
- **Question**: starts with what/why/how/when/where/who, contains a "?", or is phrased as a goal ("how to...", "what makes...", "why does..."). Examples: "What makes long form articles go viral?", "How to build a search engine", "Why do startups fail in year 2?"

**If topic** → proceed with standard research protocol below.

**If question** → enter Question Research Mode:

#### Question Research Mode

The question itself is the scope constraint — like a thesis constrains thesis research.

**Step 1: Decompose the question** into 3-5 focused sub-questions. Example:

Input: "What makes long form articles go viral and how to replicate it"
Decomposition:
- **What**: What patterns do viral long-form articles share? (structure, length, hooks, format)
- **Why**: What psychological/social mechanisms drive sharing? (emotion, identity, utility)
- **How**: What is the step-by-step process to write one? (research, outline, writing, distribution)
- **Who**: Who has done this successfully and what do they say? (case studies, practitioner interviews)
- **Data**: What does the data say? (studies on shareability, engagement metrics, platform algorithms)

Present the decomposition to the user. Then proceed.

**Step 2: One agent per sub-question.** Instead of generic angles (academic, technical, applied), each agent targets a specific sub-question. This keeps research focused and produces a complete answer.

| Agent | Sub-question | Search Strategy |
|-------|-------------|----------------|
| Agent 1 | What patterns? | Search for analyses of viral articles, content structure studies, BuzzSumo-style research |
| Agent 2 | Why psychologically? | Search for psychology of sharing, Jonah Berger's research, social currency, emotion triggers |
| Agent 3 | How to do it? | Search for practitioner playbooks, writing frameworks, distribution strategies |
| Agent 4 | Who does it well? | Search for case studies, specific viral articles and breakdowns of why they worked |
| Agent 5 | What does data say? | Search for studies on content virality, engagement data, platform algorithm research |

In `--deep` mode: add agents for adjacent sub-questions discovered during decomposition.
In `--retardmax` mode: add rabbit-hole agents + skip decomposition confirmation.

**Step 3: Compile with structure.** Articles are organized to answer the original question:
- Concept articles for each key finding
- A **topic article** that synthesizes the full answer to the original question — this is the "playbook"
- Reference articles for tools, examples, and further reading

**Step 4: Generate playbook.** After compilation, automatically create an output artifact:
- Save to `output/playbook-{slug}-{YYYY-MM-DD}.md`
- Structure: the original question, key findings per sub-question, actionable steps, examples, sources
- This is the deliverable — a practical, actionable answer filed back into the wiki

**Step 5: Derive theses.** From the findings, suggest 2-3 testable claims that could be investigated with `/wiki:thesis`. Example: "Articles with a personal narrative hook get 3x more shares than data-led hooks" — this is a specific claim that can be verified.

### Research Protocol (Single Round — Topic Mode)

#### Phase 1: Existing Knowledge Check

1. Read `wiki/_index.md` and `raw/_index.md` to understand what the wiki already knows
2. Use Grep to search for the topic and related terms across existing articles
3. Identify gaps — what specific aspects, subtopics, and questions are NOT covered?
4. Generate a list of 5-8 specific search angles based on the gaps

#### Phase 2: Web Research — Parallel Agent Swarm

Launch agents IN PARALLEL (single message, multiple Agent tool calls) to maximize coverage and speed.

**Standard mode (default):** 5 parallel agents

| Agent | Focus | Search Strategy |
|-------|-------|----------------|
| **Academic** | Peer-reviewed papers, meta-analyses, systematic reviews | Search Google Scholar, PubMed, arxiv. Prioritize recent (last 2 years). Look for landmark papers. |
| **Technical** | Technical deep-dives, specifications, documentation | Search for technical guides, whitepapers, official documentation, engineering blogs. |
| **Applied** | Case studies, real-world implementations, practical guides | Search for how-to guides, industry reports, practitioner perspectives, tutorials. |
| **News/Trends** | Recent developments, announcements, emerging research | Search for news from last 6 months, conference talks, announcements, trend analyses. |
| **Contrarian** | Criticisms, limitations, counterarguments, failed approaches | Search for critiques, rebuttals, known limitations, what doesn't work, common mistakes. |

**Deep mode (`--deep`):** 8 parallel agents — adds:

| Agent | Focus | Search Strategy |
|-------|-------|----------------|
| **Historical** | Origin, evolution, key milestones of the topic | Search for history, foundational papers, how the field evolved, key figures. |
| **Adjacent** | Related fields, interdisciplinary connections | Search for cross-domain applications, analogies from other fields, unexpected connections. |
| **Data/Stats** | Quantitative data, benchmarks, statistics, datasets | Search for surveys, benchmarks, statistical analyses, market data, datasets. |

**Retardmax mode (`--retardmax`):** 10 parallel agents — ALL of the above plus:

| Agent | Focus | Search Strategy |
|-------|-------|----------------|
| **Rabbit Hole 1** | Whatever the first search surfaces — follow the most interesting link | Start with the topic, click the most compelling result, then search for what THAT references. Go deep. |
| **Rabbit Hole 2** | Same strategy, different starting search terms | Use synonyms or adjacent framing of the topic. Follow the trail wherever it goes. |

**Each agent must:**
- Run 2-3 different WebSearch queries (vary terms, don't repeat)
- For each promising result, use WebFetch to extract the full content
- Evaluate quality: Is this authoritative? Peer-reviewed? Recent? Unique perspective?
- Return a ranked list: title, URL, extracted content, quality score (1-5), and why it's worth ingesting
- Target 3-5 high-quality sources per agent
- Skip: paywalled content, SEO spam, thin articles, duplicate information

Retardmax differences:
- **Skip Phase 1 entirely** — don't check what already exists, just go
- Each agent runs 4-5 searches instead of 2-3
- **Lower quality threshold** — ingest anything that's not obviously spam
- **--sources default bumps to 15** (override with explicit --sources)
- Compile fast — don't agonize over article structure
- Rabbit hole agents chase citations and references from pages they find

**Deduplication:** After all agents return, deduplicate by URL and by content similarity. If two agents found the same source, keep it once. If two sources cover identical ground, keep the higher quality one. In retardmax mode, be more lenient.

#### Phase 3: Ingest

For each high-quality source (up to --sources count, ranked by quality score):

1. Write to `raw/{type}/YYYY-MM-DD-slug.md` with proper frontmatter (title, source URL, type, tags, summary)
2. Auto-detect type: academic → papers, news → articles, code → repos, guides → articles, data → data
3. Update `raw/{type}/_index.md` and `raw/_index.md`
4. Update master `_index.md` source count

#### Phase 4: Compile

1. Read all newly ingested sources
2. Follow the compilation protocol in `skills/wiki-manager/references/compilation.md`:
   - Extract key concepts, facts, relationships
   - Map to existing wiki articles
   - Create new articles or update existing ones
   - Use dual-link format for all cross-references
   - Set confidence levels based on source quality and corroboration:
     - Multiple agents found corroborating sources → high
     - Single source or recent/unverified → medium
     - Contrarian agent only, or anecdotal → low
   - Add bidirectional See Also links
3. Update all `_index.md` files
4. Update master `_index.md` with new stats

#### Phase 5: Report & Log

1. Append to topic wiki `log.md`: `## [YYYY-MM-DD] research | "topic" → N sources ingested, M articles compiled`
2. Append to hub `~/wiki/log.md`: same entry

3. Report:
   - **Topic researched**: the query
   - **Round**: N of M (if --min-time)
   - **Agents launched**: N (list which angles)
   - **Sources found**: N total across all agents
   - **Sources ingested**: M (list with URLs and quality scores)
   - **Sources skipped**: list with reason (low quality, duplicate, paywall, thin)
   - **Articles created**: list with paths and summaries
   - **Articles updated**: list with what was added
   - **Confidence map**: which claims are high/medium/low confidence and why
   - **New connections**: cross-references discovered between new and existing articles
   - **Remaining gaps**: what's still not covered
   - **Suggested follow-ups**: specific subtopics for next round (or manual `/wiki:research` commands)
   - **Time spent**: this round / total elapsed (if --min-time)
