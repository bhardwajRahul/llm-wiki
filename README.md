# llm-wiki

A Claude Code plugin for building LLM-compiled knowledge bases. Ingest sources, compile interconnected markdown articles, query, lint, and generate outputs — all from Claude Code. No Obsidian needed.

Inspired by [Karpathy's LLM wiki concept](https://x.com/karpathy/status/2040470801506541998).

## Install

```
/install-plugin github:<username>/llm-wiki
```

## Quick Start

```
/wiki init                           # Create your knowledge base at ~/wiki/
/wiki:ingest https://example.com     # Ingest a web article
/wiki:ingest --inbox                 # Process files dropped in ~/wiki/inbox/
/wiki:compile                        # Compile sources into wiki articles
/wiki:query "How does X work?"       # Ask questions against the wiki
```

## Commands

| Command | Description |
|---------|-------------|
| `/wiki` | Show wiki status, stats, and list of wikis |
| `/wiki init` | Create a global wiki at `~/wiki/` |
| `/wiki init --local` | Create a project-local wiki at `.wiki/` |
| `/wiki init ml --topic` | Create a sub-wiki at `~/wiki/topics/ml/` |
| `/wiki:ingest <source>` | Ingest a URL, file path, or quoted text |
| `/wiki:ingest --inbox` | Process all files in `~/wiki/inbox/` |
| `/wiki:compile` | Compile new sources into wiki articles |
| `/wiki:compile --full` | Recompile everything from scratch |
| `/wiki:query <question>` | Q&A against the wiki with citations |
| `/wiki:search <terms>` | Find content by keyword or tag |
| `/wiki:lint` | Run health checks on the wiki |
| `/wiki:lint --fix` | Auto-fix structural issues |
| `/wiki:lint --deep` | Web-verify facts and suggest improvements |
| `/wiki:output summary` | Generate a summary of a topic |
| `/wiki:output report --topic X` | Generate a detailed report |
| `/wiki:output slides --topic X` | Generate a slide deck |
| `/wiki:output study-guide` | Generate a study guide |
| `/wiki:output glossary` | Generate a glossary of terms |

All commands accept `--wiki <name>` to target a specific wiki and `--local` to target the project wiki.

## How It Works

### Architecture

```
~/wiki/
├── inbox/          # Drop zone — dump files here, run /wiki:ingest --inbox
├── raw/            # Immutable source material (articles, papers, repos, notes, data)
├── wiki/           # Compiled articles (concepts, topics, references)
├── output/         # Generated artifacts (summaries, reports, slides, etc.)
└── topics/         # Sub-wikis by topic
```

### The Flow

1. **Ingest** sources into `raw/` — URLs, files, text, tweets (via Grok MCP), or bulk via inbox
2. **Compile** raw sources into synthesized wiki articles with cross-references
3. **Query** the wiki — explicit via `/wiki:query` or ambient (just ask, the skill auto-activates)
4. **Lint** for consistency — broken links, missing indexes, orphan articles
5. **Output** artifacts — summaries, reports, slides — filed back into the wiki

### Key Design

- **Global by default** at `~/wiki/`, with `--local` for project-specific wikis
- **`_index.md` navigation** — every directory has an index. Claude reads indexes first, never scans blindly
- **Articles are synthesized**, not copied — they explain, contextualize, cross-reference
- **Raw is immutable** — once ingested, sources are never modified
- **Multi-wiki aware** — queries check sibling wiki indexes for overlap
- **Standard markdown** — no `[[wiki-links]]`, just regular markdown links
- **Zero dependencies** — runs entirely on Claude Code built-in tools

## Ambient Intelligence

The wiki-manager skill auto-activates when you ask knowledge questions in any project. If the wiki has relevant content, it surfaces it with citations. No `/wiki:query` needed for casual questions.

## License

MIT
