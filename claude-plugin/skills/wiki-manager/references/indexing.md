# Indexing Protocol

## Purpose

Index files (`_index.md`) are Claude's navigation system. Instead of scanning hundreds of files, Claude reads a single index to find what it needs. This is the key efficiency mechanism.

## The 3-Hop Strategy

When answering a query or finding content:

1. **Hop 1**: Read master `_index.md` → get overview, identify which section is relevant
2. **Hop 2**: Read `wiki/{category}/_index.md` → scan summaries and tags for matches
3. **Hop 3**: Read only the matched article files

This means Claude typically reads 2-3 small index files + 3-8 full articles, rather than scanning dozens of files.

## When to Update Indexes

Indexes MUST be updated whenever:
- A file is added to the directory
- A file is removed from the directory
- A file's frontmatter (title, summary, tags) changes
- Statistics change (after compilation, after lint)

## Index Update Procedure

### Adding a file

1. Read the current `_index.md`
2. Add a new row to the Contents table: `| [filename.md](filename.md) | Summary | tags | YYYY-MM-DD |`
3. If the file's tags introduce a new category, add it to the Categories section
4. Add entry to Recent Changes: `- YYYY-MM-DD: Added filename.md (brief note)`
5. Update "Last updated" date

### Removing a file

1. Read the current `_index.md`
2. Remove the row from Contents table
3. Remove from Categories if it was the only file with that category
4. Add removal entry to Recent Changes
5. Update "Last updated" date

### Master Index Statistics

The root `_index.md` statistics must be recalculated on:
- Any ingestion (source count changes)
- Any compilation (article count may change)
- Any lint run (lint date updates)
- Any output generation (output count changes)

Use actual file counts for accuracy, not manual tracking:
- Sources: count .md files in `raw/` subdirectories (excluding `_index.md`)
- Articles: count .md files in `wiki/` subdirectories (excluding `_index.md`)
- Outputs: count .md files in `output/` (excluding `_index.md`)

## Cross-Wiki Index Peek

When peeking at sibling wikis for overlap:
1. Read `HUB/wikis.json` to get the list of all wikis
2. For each sibling wiki, read ONLY its `_index.md` (not full articles)
3. Check if any summaries or tags match the current query
4. If overlap found, note it in the response — never read full articles from sibling wikis unless explicitly asked
