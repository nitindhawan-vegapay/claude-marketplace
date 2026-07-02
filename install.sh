#!/usr/bin/env bash
# claude-marketplace installer
# Usage:
#   ./install.sh              — list available items
#   ./install.sh skills       — install all skills
#   ./install.sh <name>       — install a specific skill by name
#   ./install.sh --copy       — copy files instead of symlinking (prefix any command)

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SRC="$REPO_DIR/skills"
SKILLS_DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
USE_COPY=false

# Parse flags
args=()
for arg in "$@"; do
  if [[ "$arg" == "--copy" ]]; then
    USE_COPY=true
  else
    args+=("$arg")
  fi
done
set -- "${args[@]+"${args[@]}"}"

# ── helpers ──────────────────────────────────────────────────────────────────

green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

list_skills() {
  echo ""
  bold "Available skills:"
  for f in "$SKILLS_SRC"/*.md; do
    [[ "$f" == */README.md ]] && continue
    name="$(basename "$f" .md)"
    desc="$(grep -m1 '^[^#]' "$f" 2>/dev/null | head -c 80 || echo "(no description)")"
    printf "  %-30s %s\n" "/$name" "$desc"
  done
  echo ""
}

install_skill() {
  local name="$1"
  local src="$SKILLS_SRC/${name}.md"
  local dest="$SKILLS_DEST/${name}.md"

  if [[ ! -f "$src" ]]; then
    red "Skill not found: $name"
    echo "Run ./install.sh to see available skills."
    exit 1
  fi

  mkdir -p "$SKILLS_DEST"

  if [[ -e "$dest" || -L "$dest" ]]; then
    yellow "Overwriting existing: $dest"
    rm -f "$dest"
  fi

  if $USE_COPY; then
    cp "$src" "$dest"
    green "Installed (copy): /$name → $dest"
  else
    ln -s "$src" "$dest"
    green "Installed (symlink): /$name → $dest"
    echo "  (updates automatically when you git pull)"
  fi
}

install_all_skills() {
  local count=0
  for f in "$SKILLS_SRC"/*.md; do
    [[ "$f" == */README.md ]] && continue
    name="$(basename "$f" .md)"
    install_skill "$name"
    ((count++))
  done
  echo ""
  bold "Installed $count skill(s) to $SKILLS_DEST"
  echo "Restart your Claude CLI session to pick up new commands."
}

# ── main ─────────────────────────────────────────────────────────────────────

case "${1:-}" in
  "")
    echo ""
    bold "claude-marketplace"
    echo "Central registry of Claude Code skills, MCP servers, and plugins."
    echo ""
    list_skills
    echo "Usage:"
    echo "  ./install.sh skills        Install all skills"
    echo "  ./install.sh <name>        Install a specific skill"
    echo "  ./install.sh --copy ...    Copy files instead of symlinking"
    echo ""
    echo "Skills are installed to: $SKILLS_DEST"
    ;;
  skills)
    install_all_skills
    ;;
  *)
    install_skill "$1"
    echo "Restart your Claude CLI session to pick up the new command."
    ;;
esac
