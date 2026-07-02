# Claude Marketplace

Central registry of Claude Code skills, MCP server configs, and plugins for the team.

## For developers (zero setup)

If your project repo already has `.claude/marketplace.json` and `.claude/settings.json` committed, you get skills automatically — just clone your project and open Claude Code. Skills install on first tool use, once per day.

**Prerequisites:** `gh` CLI installed and authenticated (`gh auth login`). That's it — no cloning this repo, no manual commands.

## For project owners (one-time per project)

Create `.claude/settings.json` in your project root with this content:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": ".*",
        "hooks": [
          {
            "type": "command",
            "command": "MARKER=/tmp/.claude-mkt-$(date +%Y%m%d)-$(basename $PWD); [ -f \"$MARKER\" ] || (REMOTE_SHA=$(gh api repos/nitindhawan-vegapay/claude-marketplace/contents/catalog.json --jq '.sha' 2>/dev/null); LOCAL_SHA=$(cat ~/.claude/.marketplace-sha 2>/dev/null || echo ''); [ \"$REMOTE_SHA\" = \"$LOCAL_SHA\" ] || (gh api repos/nitindhawan-vegapay/claude-marketplace/contents/remote-install.sh --jq '.content' | base64 -d 2>/dev/null | bash -s -- skills >/dev/null 2>&1 && echo \"$REMOTE_SHA\" > ~/.claude/.marketplace-sha); touch \"$MARKER\"); exit 0"
          }
        ]
      }
    ]
  }
}
```

Commit it. Done. Your team gets all marketplace skills auto-installed when they open Claude Code. No cloning, no extensions, no setup commands.

## Other commands

```bash
gh marketplace list                         # see everything available
gh marketplace install find-nexus-version   # install a specific skill
gh marketplace install skills               # install all skills
gh marketplace sync                         # manually re-sync from manifest
```

## What's in here

| Category | Directory | Description |
|---|---|---|
| Skills | [`skills/`](skills/) | Slash commands for Claude CLI |
| MCP Servers | [`mcp-servers/`](mcp-servers/) | Model Context Protocol server configs |
| Plugins | [`plugins/`](plugins/) | Hooks, settings presets, CLAUDE.md templates |
| Templates | [`templates/`](templates/) | Starter files for `gh marketplace init` |

## Available skills

| Command | Description | Requires |
|---|---|---|
| `/find-nexus-version` | Find which branch/commit/run pushed a vegapay-commons version to Nexus | `git`, `gh` |
| `/analyze-merge-branches` | Read-only analysis of bank branches before a merge — flags, line numbers, programId resolvability, merge-compatibility verdict | `git` |

## Contributing

### Adding a skill

1. Create `skills/<command-name>.md` — filename becomes the slash command.
2. Add an entry to [`catalog.json`](catalog.json).
3. Open a PR.

### Adding an MCP server or plugin

See [`mcp-servers/README.md`](mcp-servers/README.md) and [`plugins/README.md`](plugins/README.md).
