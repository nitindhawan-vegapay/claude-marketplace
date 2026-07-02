# MCP Servers

This directory will hold configuration and documentation for Model Context Protocol (MCP) servers that teams can register in their Claude Code setup.

## What is an MCP server?

MCP servers extend Claude Code with new tools — database access, internal APIs, custom search, etc. You register them in your `.claude/settings.json` (project-level) or `~/.claude/settings.json` (user-level):

```json
{
  "mcpServers": {
    "my-server": {
      "command": "npx",
      "args": ["-y", "@my-org/mcp-my-server"]
    }
  }
}
```

## Planned structure

```
mcp-servers/
├── README.md          ← you are here
└── configs/           ← one JSON file per server (copy-paste ready config blocks)
```

## Contributing an MCP server

1. Create a subdirectory under `mcp-servers/` with your server name.
2. Add a `README.md` explaining what the server exposes and how to install it.
3. Add a `config.json` with a ready-to-paste `mcpServers` config block.
4. Register it in the root `catalog.json` under `mcp-servers`.
