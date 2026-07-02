# claude-marketplace

Central registry of Claude Code skills, MCP servers, and plugins. End users never clone this repo — everything is delivered via `gh api` calls. Project repos commit a `.claude/settings.json` hook that auto-installs skills from the catalog.

## Structure

```
claude-marketplace/
├── catalog.json          — machine-readable registry of all items
├── install.sh            — CLI installer (symlink or copy mode)
├── skills/               — Claude Code slash commands (one .md file per command)
├── mcp-servers/          — MCP server configs (future)
└── plugins/              — hooks, settings presets, CLAUDE.md templates (future)
```

## Key conventions

- **Skill filenames** are kebab-case and match the slash command exactly (`find-nexus-version.md` → `/find-nexus-version`).
- **catalog.json** must be updated whenever a skill, MCP server, or plugin is added or removed.
- **remote-install.sh** is the delivery mechanism — fetched and executed via `gh api`, never requires a local clone.
- Skills are installed to `~/.claude/skills/` (user-level, available globally) unless `CLAUDE_SKILLS_DIR` is set.

## Extending the marketplace

### New skill
1. Add `skills/<name>.md`
2. Add entry to `catalog.json` under `"skills"`

### New MCP server
1. Add `mcp-servers/<name>/` with `README.md` and `config.json`
2. Add entry to `catalog.json` under `"mcp-servers"`

### New plugin
1. Add `plugins/<name>/` with `README.md` and any hook scripts or settings snippets
2. Add entry to `catalog.json` under `"plugins"`

## Testing a skill locally

```bash
./install.sh <skill-name>
# restart Claude CLI, then invoke /<skill-name>
```
