# Skills

Each `.md` file here is a Claude Code skill — a slash command available in your Claude CLI session.

## How skills work

The filename (without `.md`) becomes the slash command. For example, `find-nexus-version.md` becomes `/find-nexus-version`.

When you invoke the command, Claude reads the skill file and follows its instructions. You can pass arguments:

```
/find-nexus-version 7.9.1
```

Arguments are available inside the skill as `$ARGUMENTS`.

## Available skills

| Command | Description |
|---|---|
| `/find-nexus-version` | Find which branch/commit/run pushed a version to Nexus |

## Adding a skill

1. Create a `.md` file in this directory. The filename becomes the command name (use kebab-case).
2. Structure your skill file with these sections:
   - **Description** — one-line summary at the top
   - **Input** — what `$ARGUMENTS` should contain
   - **Permissions** — what the skill is/isn't allowed to do
   - **Workflow** — numbered steps Claude will follow
3. Update `catalog.json` at the repo root with your skill's metadata.
4. Test locally: install the skill via `../install.sh <skill-name>`, then invoke it in a Claude session.

## Skill file template

```markdown
# Skill Title

One-line description of what this skill does.

## Input

The user will provide: **$ARGUMENTS**

Describe what format the argument should be in.

## Permissions

- List what this skill is allowed/not allowed to do.

## Workflow

### Step 1: ...

### Step 2: ...

## Output

Describe what the skill produces.
```
