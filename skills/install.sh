#!/usr/bin/env bash
# Install Brale Playbook skills into a Cursor or Claude skills directory.
#
# Usage:
#   ./skills/install.sh                     # installs to ~/.cursor/skills/
#   ./skills/install.sh ~/.cursor/skills    # explicit path
#   ./skills/install.sh --claude            # installs to ~/.claude/skills/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS=("brale-architecture-router" "brale-cloudflare-patterns" "brale-app-scaffold" "brale-security-review")

# Determine target directory
TARGET="$HOME/.cursor/skills"
if [[ "${1:-}" == "--claude" ]]; then
  TARGET="$HOME/.claude/skills"
elif [[ -n "${1:-}" ]]; then
  TARGET="$1"
fi

echo "Installing Brale Playbook skills to $TARGET"

for skill in "${SKILLS[@]}"; do
  src="$SCRIPT_DIR/$skill"
  dest="$TARGET/$skill"

  if [[ ! -d "$src" ]]; then
    echo "  ⚠ Skipping $skill (source not found)"
    continue
  fi

  mkdir -p "$dest"
  cp "$src/SKILL.md" "$dest/SKILL.md"
  echo "  ✓ $skill"
done

echo ""
echo "Done. Restart Cursor or Claude to pick up the new skills."
