# llm-wiki Release Checklist

Standard process for testing and shipping a new version of the llm-wiki plugin.

## Pre-release: Version Bump

1. **Bump `plugin.json`** — both files must match:
   - `claude-plugin/.claude-plugin/plugin.json`
   - `plugins/llm-wiki/.codex-plugin/plugin.json`

## Test

3. **Invoke `/wiki status`** — verify the skill resolves and shows the hub status table
   - If `/wiki` doesn't resolve, check that `~/.claude/commands/wiki.md` shim exists (delegates to `wiki:wiki`)

4. **Test the changed feature** — whatever was added/fixed in this release:
   - Invoke the relevant `/wiki:*` subcommand
   - Confirm expected behavior, no errors

5. **Spot-check routing** (if routing changed):
   - `/wiki <url>` → should route to ingest
   - `/wiki what is X?` → should route to query
   - `/wiki research Y` → should route to research

## Ship

6. **Commit version bumps** — both files in one commit:
   ```bash
   git add .claude-plugin/marketplace.json claude-plugin/.claude-plugin/plugin.json
   git commit -m "Bump to v0.0.XX"
   ```

7. **Push to master**:
   ```bash
   git push origin <branch>:master
   ```
   - If in a worktree: `git push origin worktree-<name>:master`

8. **Create GitHub release**:
   ```bash
   GH_TOKEN="" gh release create v0.0.XX \
     --repo nvk/llm-wiki \
     --title "v0.0.XX — <Short Feature Name>" \
     --notes "$(cat <<'EOF'
   ## What's New

   - **Feature description** — one-liner explaining the change

   ### Details (optional)
   - Additional bullet points if needed
   EOF
   )"
   ```
   - `GH_TOKEN=""` is required to clear a bad env token and use `gh auth` credentials
   - Release title format: `v0.0.XX — <Feature Name>`

9. **Update plugin cache** (so local Claude Code picks up new version):
   ```bash
   # The marketplace repo auto-pulls on `claude plugin install`
   # But for dev: symlink or copy to cache
   mkdir -p ~/.claude/plugins/cache/llm-wiki/wiki/0.0.XX
   # Copy commands/ skills/ .claude-plugin/ from the repo's claude-plugin/ dir
   ```
   - Or just run `claude plugin install llm-wiki` if marketplace is updated

10. **Verify install** — start a fresh Claude Code session and run `/wiki status`

## Post-ship: README

- Update the changelog section in `README.md` for notable releases (skip patch-level fixes)
- Keep only the last 5-6 entries — drop the oldest when adding a new one
- Follow the existing single-paragraph format
- Commit separately: `"Update README with vX.Y.Z changelog"`

## Post-ship: Website

- Update `llm-wiki-web/index.html`:
  - Release card fallback version + description (the live API fetch also picks it up, but the fallback should match)
  - Plugin card fallback version
  - Commands table if new flags/commands were added
  - Feature cards if a major capability changed
- Update `llm-wiki-web/llms.txt` if commands or flags changed
- Commit and push to `llm-wiki-web` repo separately

## Notes

- Plugin name in marketplace: `wiki@llm-wiki`
- Plugin cache path: `~/.claude/plugins/cache/llm-wiki/wiki/<version>/`
- Marketplace repo: `~/.claude/plugins/marketplaces/llm-wiki/`
- Hub wiki path: `~/Library/Mobile Documents/com~apple~CloudDocs/wiki/`
- The `/wiki` bare command needs `~/.claude/commands/wiki.md` shim (user-level, not in repo)
