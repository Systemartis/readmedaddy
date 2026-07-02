#!/usr/bin/env sh
# Install readmedaddy for every agent that reads Agent Skills, then verify,
# then register the readme-drift auto-update hook (Claude Code, user-global).
#
#   ./install.sh            install for Claude Code + opencode + GitHub Copilot,
#                           then register the Stop hook
#   DEST=/path ./install.sh install to ONE custom skills dir only (any agent)
#   ./install.sh --no-hook  install the skill only; skip hook registration
#
# Default destinations (the skill is the same folder of Markdown everywhere):
#   ~/.claude/skills/readmedaddy           Claude Code (opencode reads this too)
#   ~/.config/opencode/skills/readmedaddy  opencode (explicit global path)
#   ~/.copilot/skills/readmedaddy          GitHub Copilot CLI / coding agent
# Agents without a skills loader (Cursor, Codex, Gemini CLI, Zed, ...) hook in
# via one AGENTS.md line — see the README's install section.
#
# Review before running (good supply-chain hygiene): it copies this repo's
# skills/readmedaddy/ into the destinations above, confirms SKILL.md landed
# with the right frontmatter name, and merges a Stop hook into your Claude
# Code settings.json. It makes no network calls and touches nothing outside
# the destinations and that settings file. Re-running is safe (idempotent).
set -eu

INSTALL_HOOK=1
for arg in "$@"; do
  case "$arg" in
    --no-hook) INSTALL_HOOK=0 ;;
    *) echo "error: unknown argument '$arg'" >&2; exit 1 ;;
  esac
done

REPO=$(cd "$(dirname "$0")" && pwd)
SRC=$REPO/skills/readmedaddy

if [ ! -f "$SRC/SKILL.md" ]; then
  echo "error: $SRC/SKILL.md not found — run from the repo root." >&2
  exit 1
fi

# Copy the skill into $1/readmedaddy, restore the hook's exec bit, and verify
# SKILL.md landed with frontmatter name = readmedaddy.
install_to() {
  it_dest=$1/readmedaddy
  echo "Installing readmedaddy -> $it_dest"
  mkdir -p "$it_dest"
  # Prefer rsync; fall back to cp. Exclude nothing — the skill is small.
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$SRC"/ "$it_dest"/
  else
    rm -rf "$it_dest"
    mkdir -p "$it_dest"
    cp -R "$SRC"/ "$it_dest"/
  fi

  if [ ! -f "$it_dest/SKILL.md" ]; then
    echo "  FAIL  $it_dest/SKILL.md is missing after copy." >&2
    exit 1
  fi

  # Read the frontmatter `name:` value (first match inside the leading --- block).
  it_name=$(awk '
    NR==1 && $0 != "---" { exit }
    NR==1 { in_fm=1; next }
    in_fm && $0 == "---" { exit }
    in_fm && $1 == "name:" { print $2; exit }
  ' "$it_dest/SKILL.md")
  # Strip any surrounding quotes a YAML author might have added.
  it_name=${it_name%\"}
  it_name=${it_name#\"}
  it_name=${it_name%\'}
  it_name=${it_name#\'}

  if [ "$it_name" != "readmedaddy" ]; then
    echo "  FAIL  frontmatter name is '$it_name' (expected 'readmedaddy')." >&2
    exit 1
  fi

  if [ -f "$it_dest/hooks/readme-drift.sh" ]; then
    chmod +x "$it_dest/hooks/readme-drift.sh"
  fi
  echo "  ok    verified: SKILL.md present, frontmatter name = readmedaddy."
}

if [ -n "${DEST:-}" ]; then
  install_to "$DEST"
  PRIMARY="$DEST/readmedaddy"
else
  install_to "$HOME/.claude/skills"
  install_to "$HOME/.config/opencode/skills"
  install_to "$HOME/.copilot/skills"
  PRIMARY="$HOME/.claude/skills/readmedaddy"
fi

echo "Installed. The skill triggers on its description, or invoke it by name: readmedaddy."
echo "  Claude Code: /skills lists it.  opencode: picked up automatically."
echo "  Copilot CLI: /skills list.  Other agents: see README — one AGENTS.md line."

HOOK="$PRIMARY/hooks/readme-drift.sh"
if [ "$INSTALL_HOOK" -eq 1 ]; then
  if [ ! -f "$HOOK" ]; then
    echo "  WARN  $HOOK is missing; skipping hook registration." >&2
  else
    echo "Registering the readme-drift Stop hook (Claude Code, user-global)..."
    python3 "$REPO/scripts/install-hook.py" --command "$HOOK"
    echo ""
    echo "Done. The readme-drift hook is active globally across your projects."
    echo "It watches for code changes that leave your README behind and, at the"
    echo "end of a session, prompts you to refresh it through the readmedaddy"
    echo "skill. It never edits files on its own."
    echo ""
    echo "Other agents and CI use the same detector standalone (no agent needed):"
    echo "  $HOOK --check                       # working tree"
    echo "  $HOOK --check --range origin/main...HEAD   # commit range (CI)"
    echo ""
    echo "Tune it:"
    echo "  - Notify instead of block:  export README_DADDY_HOOK=notify"
    echo "  - Disable globally:         export README_DADDY_HOOK=off"
    echo "  - Per-project settings:     add .readmedaddy.json with"
    echo "                              {\"hook\":{\"enabled\":false}} or \"mode\":\"notify\""
    echo "  - Uninstall the hook:       python3 \"$REPO/scripts/install-hook.py\" --uninstall"
  fi
else
  echo "Skipped hook registration (--no-hook). Register it later with:"
  echo "  python3 \"$REPO/scripts/install-hook.py\" --command \"$HOOK\""
fi
