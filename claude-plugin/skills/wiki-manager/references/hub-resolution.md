# Hub Path Resolution

Every wiki operation must resolve the hub path before doing anything else. Follow this protocol exactly.

## Resolution Steps

1. **Check default location first**: Use the Read tool on `~/wiki/_index.md` (expand `~` to `$HOME`).
2. **If `~/wiki/_index.md` exists** → the default hub is initialized. Set **HUB** = `~/wiki/` and skip to "After Resolution". No config read needed.
3. **If `~/wiki/_index.md` does not exist** → read `~/.config/llm-wiki/config.json`.
4. **If config exists** and contains a `hub_path` field → use that value. Expand the leading tilde (see below), then set **HUB**.
5. **If config does not exist** or has no `hub_path` → default to `~/wiki/` (for initialization).
6. Store the result as **HUB** for the rest of the operation.

### Why this order

`~/wiki/` is simple — no spaces, no tilde ambiguity. The config-based path (often iCloud: `~/Library/Mobile Documents/com~apple~CloudDocs/wiki`) has spaces and literal tildes in directory names that agents frequently mishandle. By checking `~/wiki/` first, we avoid the fragile path entirely when it's not needed.

### Tilde Expansion — Correct Method

When expanding a path from config, replace ONLY the leading `~` with the user's home directory. **Do NOT expand tildes anywhere else in the path** — characters like `~` in directory names (e.g., `com~apple~CloudDocs`) are literal and must be left unchanged.

If you need to expand the path in Bash, use this pattern:

```bash
hub_path="~/Library/Mobile Documents/com~apple~CloudDocs/wiki"  # from config
expanded="${hub_path/#\~/$HOME}"
# Result: /Users/jane/Library/Mobile Documents/com~apple~CloudDocs/wiki
#                                  ↑ these tildes are UNTOUCHED
```

**Never** use `eval` or unquoted expansion — these break on paths with spaces.

### Paths with Spaces

The resolved path may contain spaces (e.g., `Mobile Documents` in iCloud paths). When using the path in Bash commands, **always double-quote it**:

```bash
ls "$HUB/topics/"           # correct
mkdir -p "$HUB/topics/new"  # correct
ls $HUB/topics/             # WRONG — breaks on spaces
```

The Read, Write, Edit, Glob, and Grep tools handle spaces natively — no special quoting needed for those.

### Worked Example (iCloud)

Config file (`~/.config/llm-wiki/config.json`):
```json
{ "hub_path": "~/Library/Mobile Documents/com~apple~CloudDocs/wiki" }
```

Resolution on a machine with home directory `/Users/jane`:

| Step | Value |
|------|-------|
| Check `~/wiki/_index.md` | Does not exist → proceed to config |
| Raw from config | `~/Library/Mobile Documents/com~apple~CloudDocs/wiki` |
| After leading `~` expansion | `/Users/jane/Library/Mobile Documents/com~apple~CloudDocs/wiki` |
| `com~apple~CloudDocs` | Unchanged — this is a literal directory name, not a tilde to expand |

**HUB** = `/Users/jane/Library/Mobile Documents/com~apple~CloudDocs/wiki`

### Default (no config, no ~/wiki/)

If `~/wiki/_index.md` does not exist and `~/.config/llm-wiki/config.json` does not exist, **HUB** = `~/wiki/` (expanded to `$HOME/wiki/`). This is used for initialization.

## After Resolution

Once HUB is resolved, determine which wiki to target:

1. `--local` flag → `.wiki/` in current directory
2. `--wiki <name>` flag → look up in `HUB/wikis.json`
3. Current directory has `.wiki/` → use it
4. Otherwise → HUB (the hub itself)
