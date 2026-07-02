#!/usr/bin/env sh
# Install readmedaddy into your Claude Code skills directory, then verify,
# then register the readme-drift auto-update hook (user-global).
#
#   ./install.sh            install to ~/.claude/skills/readmedaddy + hook
#   DEST=/path ./install.sh install to a custom skills dir
#   ./install.sh --no-hook  install the skill only; skip hook registration
#
# Review before running (good supply-chain hygiene): it copies this repo's
# skills/readmedaddy/ into your skills dir, confirms SKILL.md landed with the
# right frontmatter name, and merges a Stop hook into your Claude Code
# settings.json. It makes no network calls and touches nothing outside the
# destination and your settings file. Re-running is safe (idempotent).
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
DEST=${DEST:-"$HOME/.claude/skills"}/readmedaddy

if [ ! -f "$SRC/SKILL.md" ]; then
  echo "error: $SRC/SKILL.md not found — run from the repo root." >&2
  exit 1
fi

echo "Installing readmedaddy -> $DEST"
mkdir -p "$DEST"
# Prefer rsync; fall back to cp. Exclude nothing — the skill is small.
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete "$SRC"/ "$DEST"/
else
  rm -rf "$DEST"
  mkdir -p "$DEST"
  cp -R "$SRC"/ "$DEST"/
fi

# Verify: SKILL.md must have landed and declare `name: readmedaddy`.
echo "Verifying install..."
if [ ! -f "$DEST/SKILL.md" ]; then
  echo "  FAIL  $DEST/SKILL.md is missing after copy." >&2
  exit 1
fi

# Read the frontmatter `name:` value (first match inside the leading --- block).
name=$(awk '
  NR==1 && $0 != "---" { exit }
  NR==1 { in_fm=1; next }
  in_fm && $0 == "---" { exit }
  in_fm && $1 == "name:" { print $2; exit }
' "$DEST/SKILL.md")
# Strip any surrounding quotes a YAML author might have added.
name=${name%\"}
name=${name#\"}
name=${name%\'}
name=${name#\'}

if [ "$name" != "readmedaddy" ]; then
  echo "  FAIL  frontmatter name is '$name' (expected 'readmedaddy')." >&2
  exit 1
fi

echo "Verified: SKILL.md present, frontmatter name = readmedaddy."

# The hook script ships inside the skill; rsync/cp -R above carried it over.
# Make sure its executable bit survived the copy regardless of source mode.
HOOK="$DEST/hooks/readme-drift.sh"
if [ -f "$HOOK" ]; then
  chmod +x "$HOOK"
fi

echo "Installed. In Claude Code the skill triggers on its description, or invoke it by name: readmedaddy."

if [ "$INSTALL_HOOK" -eq 1 ]; then
  if [ ! -f "$HOOK" ]; then
    echo "  WARN  $HOOK is missing; skipping hook registration." >&2
  else
    echo "Registering the readme-drift Stop hook (user-global)..."
    python3 "$REPO/scripts/install-hook.py" --command "$HOOK"
    echo ""
    echo "Done. The readme-drift hook is active globally across your projects."
    echo "It watches for code changes that leave your README behind and, at the"
    echo "end of a session, prompts you to refresh it through the readmedaddy"
    echo "skill. It never edits files on its own."
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
