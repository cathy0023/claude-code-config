#!/usr/bin/env bash
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
MANIFEST_FILE="$CLAUDE_DIR/.installed-manifest"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

if [ ! -f "$MANIFEST_FILE" ]; then
  echo "No manifest found at $MANIFEST_FILE. Nothing to uninstall."
  exit 0
fi

removed=0
not_found=0

echo "Uninstalling claude-code-config..."
echo ""

while IFS= read -r line; do
  # Skip comment lines
  [[ "$line" =~ ^# ]] && continue
  [ -z "$line" ] && continue

  file="$CLAUDE_DIR/$line"
  if [ -f "$file" ]; then
    rm "$file"
    removed=$((removed + 1))
    # Try to remove empty parent directories (up to ~/.claude/)
    dir=$(dirname "$file")
    while [ "$dir" != "$CLAUDE_DIR" ] && [ -d "$dir" ] && [ -z "$(ls -A "$dir" 2>/dev/null)" ]; do
      rmdir "$dir"
      dir=$(dirname "$dir")
    done
  else
    not_found=$((not_found + 1))
  fi
done < "$MANIFEST_FILE"

# Remove manifest
rm -f "$MANIFEST_FILE"

echo ""
echo "=== Claude Code Config Uninstalled ==="
echo ""
echo "Files removed: $removed"
echo "Files not found (already removed): $not_found"
echo ""
echo -e "${YELLOW}Note: hooks.json was merged during install. Manual cleanup may be needed.${NC}"
