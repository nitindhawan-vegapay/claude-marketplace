# Plugins

This directory is reserved for Claude Code plugins — shared hooks, settings presets, and workflow configurations that can be dropped into a project.

## Planned structure

```
plugins/
├── README.md          ← you are here
└── <plugin-name>/
    ├── README.md      ← what it does, how to install
    ├── settings.json  ← settings snippet to merge
    └── hooks/         ← hook scripts (if any)
```

## What plugins will cover

- **Hooks** — shell scripts that run before/after Claude tool calls (e.g., auto-format on file save, auto-run tests after edits)
- **Settings presets** — curated `settings.json` snippets for common workflows (e.g., strict read-only mode, CI-safe permissions)
- **CLAUDE.md templates** — project-level context files for common tech stacks

## Contributing a plugin

1. Create a subdirectory under `plugins/` with your plugin name.
2. Add a `README.md` with installation instructions.
3. Include any hook scripts or settings snippets.
4. Register it in the root `catalog.json` under `plugins`.
