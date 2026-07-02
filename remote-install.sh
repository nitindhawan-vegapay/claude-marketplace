#!/usr/bin/env bash
# Claude Marketplace — remote installer (no git clone required)
#
# Prerequisites: gh CLI, authenticated with access to this repo
#
# ── Option 1: sync from project manifest (recommended) ───────────────────────
#
#   Add .claude/marketplace.json to your project repo, then run:
#
#   bash <(gh api repos/nitindhawan-vegapay/claude-marketplace/contents/remote-install.sh \
#     --jq '.content' | base64 -d) sync
#
# ── Option 2: install directly ───────────────────────────────────────────────
#
#   ... | base64 -d) list                  — list available items
#   ... | base64 -d) skills               — install all skills
#   ... | base64 -d) <skill-name>         — install one skill by name

set -euo pipefail

MARKETPLACE_REPO="nitindhawan-vegapay/claude-marketplace"
BRANCH="main"
SKILLS_DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
MANIFEST_FILE="${CLAUDE_MANIFEST:-$(pwd)/.claude/marketplace.json}"

# ── helpers ──────────────────────────────────────────────────────────────────

green()  { printf '\033[0;32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[0;33m%s\033[0m\n' "$*"; }
red()    { printf '\033[0;31m%s\033[0m\n' "$*"; }
bold()   { printf '\033[1m%s\033[0m\n' "$*"; }

check_gh() {
  if ! command -v gh &>/dev/null; then
    red "Error: gh CLI is not installed."
    echo "Install it: brew install gh  (macOS) or see https://cli.github.com"
    exit 1
  fi
  if ! gh auth status &>/dev/null; then
    red "Error: gh CLI is not authenticated. Run: gh auth login"
    exit 1
  fi
}

fetch_file() {
  local repo="$1" path="$2"
  gh api "repos/$repo/contents/$path?ref=$BRANCH" --jq '.content' | base64 -d
}

fetch_catalog() {
  fetch_file "$MARKETPLACE_REPO" "catalog.json"
}

# parse a JSON array of strings using only shell builtins + sed (no jq required)
parse_json_array() {
  # Input: raw JSON string value of a key, e.g. ["foo","bar"]
  # Output: one item per line
  echo "$1" | grep -o '"[^"]*"' | sed 's/"//g'
}

list_available() {
  echo ""
  bold "Available in $MARKETPLACE_REPO:"
  echo ""
  local catalog
  catalog="$(fetch_catalog)"

  echo "  Skills:"
  echo "$catalog" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data.get('skills', []):
    print(f\"    /{s['name']:<28} {s.get('description','')[:60]}\")
" 2>/dev/null || echo "$catalog" | grep -A1 '"skills"' | grep '"name"' | sed 's/.*"name": *"//;s/".*//' | while read -r n; do printf "    /%s\n" "$n"; done

  echo ""
}

install_skill() {
  local name="$1" repo="${2:-$MARKETPLACE_REPO}"
  local dest="$SKILLS_DEST/${name}.md"

  mkdir -p "$SKILLS_DEST"

  if [[ -e "$dest" ]]; then
    yellow "  Overwriting: $dest"
  fi

  fetch_file "$repo" "skills/${name}.md" > "$dest"
  green "  Installed skill: /$name"
}

install_all_skills() {
  local count=0
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    install_skill "$name"
    ((count++))
  done < <(fetch_catalog | grep -o '"name": *"[^"]*"' | sed 's/"name": *"//;s/"//')

  echo ""
  bold "Installed $count skill(s) to $SKILLS_DEST"
}

sync_from_manifest() {
  if [[ ! -f "$MANIFEST_FILE" ]]; then
    red "No manifest found at: $MANIFEST_FILE"
    echo ""
    echo "Create .claude/marketplace.json in your project:"
    cat <<'EOF'
{
  "marketplace": "nitindhawan-vegapay/claude-marketplace",
  "skills": [
    "find-nexus-version"
  ]
}
EOF
    exit 1
  fi

  bold "Reading manifest: $MANIFEST_FILE"
  echo ""

  local manifest repo
  manifest="$(cat "$MANIFEST_FILE")"
  repo="$(echo "$manifest" | grep '"marketplace"' | sed 's/.*"marketplace": *"//;s/".*//')"
  repo="${repo:-$MARKETPLACE_REPO}"

  # Install skills
  local skills_json
  skills_json="$(echo "$manifest" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data.get('skills', []):
    print(s)
" 2>/dev/null || echo "$manifest" | grep -A20 '"skills"' | grep '"' | grep -v 'skills\|mcp\|plugin' | sed 's/.*"//;s/".*//' | grep -v '^$')"

  local skill_count=0
  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    install_skill "$name" "$repo"
    ((skill_count++))
  done <<< "$skills_json"

  echo ""
  bold "Sync complete: $skill_count skill(s) installed to $SKILLS_DEST"
  echo "Restart your Claude CLI session to pick up new commands."
}

# ── main ─────────────────────────────────────────────────────────────────────

check_gh

case "${1:-}" in
  "" | list)
    list_available
    echo "Commands:"
    echo "  sync            Read .claude/marketplace.json and install everything declared"
    echo "  skills          Install all skills from the marketplace"
    echo "  <skill-name>    Install a specific skill"
    echo ""
    ;;
  sync)
    sync_from_manifest
    ;;
  skills)
    install_all_skills
    echo "Restart your Claude CLI session to pick up new commands."
    ;;
  *)
    install_skill "$1"
    echo "Restart your Claude CLI session to pick up the new command."
    ;;
esac
