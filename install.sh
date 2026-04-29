#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
MANIFEST_FILE="$CLAUDE_DIR/.installed-manifest"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

installed=0
skipped=0
skipped_files=()

# --- Parse arguments ---
modules=()
if [ $# -eq 0 ]; then
  modules=("core")
elif [ "$1" = "all" ]; then
  modules=("core")
  for lang_dir in "$SCRIPT_DIR/lang"/*/; do
    [ -d "$lang_dir" ] && modules+=("$(basename "$lang_dir")")
  done
else
  modules=("$@")
  # Always include core
  if [[ ! " ${modules[*]} " =~ " core " ]]; then
    echo -e "${YELLOW}Warning: 'core' module not specified, adding it automatically.${NC}"
    modules=("core" "${modules[@]}")
  fi
fi

echo "Installing modules: ${modules[*]}"
echo ""

# --- Ensure ~/.claude/ exists ---
mkdir -p "$CLAUDE_DIR"

# --- Initialize manifest ---
echo "# Installed by claude-code-config on $(date -Iseconds 2>/dev/null || date)" > "$MANIFEST_FILE"

# --- Copy function ---
copy_module() {
  local module_dir="$1"
  local module_name="$2"

  if [ ! -d "$module_dir" ]; then
    echo -e "${RED}Module not found: $module_name ($module_dir)${NC}"
    return 1
  fi

  # Copy each subdirectory (rules, agents, commands, skills, scripts)
  for subdir in rules agents commands skills scripts; do
    local src="$module_dir/$subdir"
    [ ! -d "$src" ] && continue

    # Find all files in src
    while IFS= read -r -d '' file; do
      local relpath="${file#$src/}"
      local dest="$CLAUDE_DIR/$subdir/$relpath"

      if [ -f "$dest" ]; then
        echo -e "${YELLOW}SKIP${NC}: ~/${dest#$HOME/} (already exists)"
        skipped=$((skipped + 1))
        skipped_files+=("~/${dest#$HOME/}")
      else
        mkdir -p "$(dirname "$dest")"
        cp "$file" "$dest"
        echo "$subdir/$relpath" >> "$MANIFEST_FILE"
        installed=$((installed + 1))
      fi
    done < <(find "$src" -type f -print0)
  done
}

# --- Install modules ---
for module in "${modules[@]}"; do
  if [ "$module" = "core" ]; then
    copy_module "$SCRIPT_DIR/core" "core"
  else
    copy_module "$SCRIPT_DIR/lang/$module" "$module"
  fi
done

# --- Merge hooks.json ---
merge_hooks() {
  local project_hooks="$SCRIPT_DIR/core/hooks.json"
  local user_hooks="$CLAUDE_DIR/hooks/hooks.json"

  if [ ! -f "$project_hooks" ]; then
    return
  fi

  # Parse project hooks
  project_json=$(cat "$project_hooks")

  if [ ! -f "$user_hooks" ]; then
    # No user hooks yet — just copy
    mkdir -p "$(dirname "$user_hooks")"
    echo "$project_json" > "$user_hooks"
    echo "hooks.json" >> "$MANIFEST_FILE"
    installed=$((installed + 1))
    return
  fi

  # Merge using python with inline paths
  python3 -c "
import json, sys

with open('$user_hooks') as f:
    user = json.load(f)
with open('$project_hooks') as f:
    project = json.load(f)

if 'hooks' not in user:
    user['hooks'] = {}

added = 0
for hook_type, project_entries in project.get('hooks', {}).items():
    if hook_type not in user['hooks']:
        user['hooks'][hook_type] = []
    existing = set()
    for entry in user['hooks'][hook_type]:
        existing.add((entry.get('matcher',''), entry.get('description','')))
    for entry in project_entries:
        key = (entry.get('matcher',''), entry.get('description',''))
        if key not in existing:
            user['hooks'][hook_type].append(entry)
            added += 1

with open('$user_hooks', 'w') as f:
    json.dump(user, f, indent=2)
    f.write('\n')

print(added)
" 2>/dev/null

  if [ $? -eq 0 ]; then
    total=$(python3 -c "
import json
with open('$user_hooks') as f:
    d = json.load(f)
print(sum(len(v) for v in d.get('hooks',{}).values()))
" 2>/dev/null || echo "?")
    echo -e "${GREEN}Hooks merged${NC}: $total total hooks in ~/.claude/hooks/hooks.json"
  else
    echo -e "${YELLOW}WARNING${NC}: Could not merge hooks.json automatically."
    echo "  Please merge $SCRIPT_DIR/core/hooks.json into $user_hooks manually."
  fi
}

merge_hooks

# --- Print summary ---
echo ""
echo "=== Claude Code Config Installed ==="
echo ""
echo "Modules: ${modules[*]}"
echo "Files installed: $installed"
echo "Files skipped: $skipped"
if [ ${#skipped_files[@]} -gt 0 ]; then
  echo ""
  echo "Skipped files:"
  for f in "${skipped_files[@]}"; do
    echo "  SKIP: $f (already exists)"
  done
fi
echo ""
echo "Next steps:"
echo "  1. Review ~/.claude/hooks/hooks.json for merged hooks"
echo "  2. See plugins/README.md for recommended plugins"
echo "  3. Restart Claude Code to apply changes"
