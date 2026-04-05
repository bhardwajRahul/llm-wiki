---
description: "LLM wiki knowledge base — initialize, show status, or list wikis. Subcommands: ingest, compile, query, lint, search, output, research."
argument-hint: "[init <topic-name> [--local]] [--wiki <name>]"
allowed-tools: Read, Write, Edit, Glob, Bash(ls:*), Bash(wc:*), Bash(mkdir:*), Bash(date:*)
---

## Your task

First, check if a wiki exists by trying to read `~/wiki/_index.md` (global) and `.wiki/_index.md` (local).

You are the llm-wiki knowledge base manager. Read the skill at `skills/wiki-manager/SKILL.md` and structure reference at `skills/wiki-manager/references/wiki-structure.md` for full conventions.

Resolve which wiki to use:
1. If `--local` flag → `.wiki/` in current directory
2. If `--wiki <name>` flag → look up in `~/wiki/wikis.json`
3. If current directory has `.wiki/` → use it
4. Otherwise → `~/wiki/`

---

### If $ARGUMENTS contains "init"

Initialize a new wiki. Parse arguments:
- `init <name>` → create topic sub-wiki at `~/wiki/topics/<name>/` **(this is the recommended default)**
- `init <name> --local` → create local wiki at `.wiki/` in current project
- `init` (no name) → create the global hub at `~/wiki/` (only needed once, most users won't need this)

**IMPORTANT: Always encourage topic sub-wikis.** If the user runs `init` without a name and `~/wiki/` already exists, ask: "What topic is this for? Each topic should get its own wiki. Try `/wiki init <topic-name>` instead." Only create a bare global hub if the user explicitly wants one.

**Steps:**

1. If creating a topic sub-wiki and `~/wiki/` doesn't exist yet, create the global hub first (directory structure + `wikis.json` + hub `_index.md` + hub `config.md`).

2. Create the full directory structure per `references/wiki-structure.md`:
   - `inbox/`, `inbox/.processed/`
   - `raw/`, `raw/articles/`, `raw/papers/`, `raw/repos/`, `raw/notes/`, `raw/data/`
   - `wiki/`, `wiki/concepts/`, `wiki/topics/`, `wiki/references/`
   - `output/`
   - For local wikis (`--local`): append `.wiki/` to the project's `.gitignore` (create it if it doesn't exist). This keeps wiki files untracked by default.

3. Create `.obsidian/` directory with minimal vault config (topic sub-wikis and local wikis only — NOT the global hub, to avoid nested vault confusion):
   - `.obsidian/app.json`:
     ```json
     {
       "showFrontmatter": true,
       "alwaysUpdateLinks": true,
       "newLinkFormat": "relative",
       "useMarkdownLinks": false
     }
     ```
   - `.obsidian/appearance.json`:
     ```json
     {
       "accentColor": ""
     }
     ```
   - `.obsidian/graph.json`:
     ```json
     {
       "collapse-filter": false,
       "search": "",
       "showTags": true,
       "showAttachments": false,
       "showOrphans": true,
       "collapse-color-groups": false,
       "collapse-display": false,
       "showArrow": true,
       "textFadeMultiplier": 0,
       "nodeSizeMultiplier": 1,
       "lineSizeMultiplier": 1
     }
     ```

4. Create empty `_index.md` in every directory following the format in `references/wiki-structure.md`. Use today's date. Set all counts to 0.

5. Create `log.md` with initial entry:
   ```
   # Wiki Activity Log

   ## [YYYY-MM-DD] init | Wiki initialized
   ```

6. Ask the user: "What is this wiki about?" Use their answer to create `config.md` with title, description, scope, and today's date.

7. Update `~/wiki/wikis.json`: add the new wiki entry. For local wikis, add to the `local_wikis` array. Update the hub `_index.md` topic wiki table.

8. Report what was created and list available commands:
   - `/wiki:research "topic" --sources 10` — auto-research to bootstrap the wiki
   - `/wiki:ingest <url|file|text>` — add source material
   - `/wiki:ingest --inbox` — process files dropped in inbox/
   - `/wiki:compile` — compile sources into wiki articles
   - `/wiki:query <question>` — ask questions against the wiki
   - `/wiki:search <query>` — find content
   - `/wiki:lint` — health check
   - `/wiki:output <type>` — generate artifacts

   Suggest running `/wiki:research` first to bootstrap the wiki with initial content.

---

### If no "init" argument and a wiki exists

Show wiki status:

1. Read the resolved wiki's `_index.md` for statistics and recent changes
2. Read `config.md` for title and description
3. Count actual files for accuracy:
   - Raw sources: count .md files in `raw/` subdirectories (excluding _index.md)
   - Wiki articles: count .md files in `wiki/` subdirectories (excluding _index.md)
   - Inbox items: count files in `inbox/` (excluding .processed/)
4. Show:
   - Wiki title and description
   - Location (path)
   - Source count / article count / output count
   - Inbox items pending (if any)
   - Last compiled / last lint dates
   - Last 5 recent changes
5. If `~/wiki/wikis.json` exists, list all known topic wikis with their descriptions and stats
6. List available subcommands

---

### If no wiki exists and no "init" argument

Tell the user:

> No wiki found. Create one with:
> - `/wiki init quantum-computing` — topic wiki at ~/wiki/topics/quantum-computing/
> - `/wiki init ml` — topic wiki at ~/wiki/topics/ml/
> - `/wiki init notes --local` — project-local wiki at .wiki/
>
> Each topic gets its own wiki with isolated indexes and articles. Queries automatically peek across topic wikis for relevant overlap.
