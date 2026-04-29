# Claude Code Config Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Package all Claude Code global config (rules, agents, commands, skills, scripts) into a GitHub repo with modular install script.

**Architecture:** Flat repo with `core/` (always-installed) and `lang/` (optional per-language packages). install.sh copies files to `~/.claude/`, skipping existing files and merging hooks.json. uninstall.sh reverses via manifest file.

**Tech Stack:** Bash (install/uninstall scripts), Node.js (hook scripts), GitHub (distribution)

---

## File Structure

```
claude-code-config/
├── install.sh
├── uninstall.sh
├── README.md
├── .gitignore
├── settings.example.json
├── core/
│   ├── rules/
│   │   ├── README.md
│   │   └── common/                    # 10 files
│   ├── agents/                        # 15 core agents
│   ├── commands/                      # 48 generic commands
│   ├── skills/                        # 19 core skills
│   ├── scripts/
│   │   ├── hooks/                     # 25 hook scripts (excl. insaits)
│   │   ├── lib/
│   │   │   └── utils.js
│   │   └── setup-package-manager.js
│   └── hooks.json
├── lang/
│   ├── typescript/
│   │   ├── rules/                     # 5 files
│   │   └── skills/                    # compose-multiplatform-patterns
│   ├── python/
│   │   ├── rules/                     # 5 files
│   │   ├── skills/                    # python-patterns, python-testing, django-*
│   │   └── agents/                    # python-reviewer.md
│   ├── golang/
│   │   ├── rules/                     # 5 files
│   │   ├── skills/                    # golang-patterns, golang-testing
│   │   └── agents/                    # go-build-resolver.md, go-reviewer.md
│   ├── cpp/
│   │   ├── rules/                     # 5 files
│   │   ├── skills/                    # cpp-coding-standards, cpp-testing
│   │   └── agents/                    # cpp-build-resolver.md, cpp-reviewer.md
│   ├── kotlin/
│   │   ├── rules/                     # 5 files
│   │   ├── skills/                    # android-clean-architecture, kotlin-*
│   │   └── agents/                    # kotlin-build-resolver.md, kotlin-reviewer.md
│   ├── rust/
│   │   ├── skills/                    # rust-patterns, rust-testing
│   │   └── agents/                    # rust-build-resolver.md, rust-reviewer.md
│   ├── php/
│   │   ├── rules/                     # 5 files
│   │   └── skills/                    # laravel-patterns, laravel-tdd, laravel-verification
│   ├── perl/
│   │   ├── rules/                     # 5 files
│   │   └── skills/                    # perl-patterns, perl-testing
│   ├── java/
│   │   ├── skills/                    # java-coding-standards, springboot-*
│   │   └── agents/                    # java-build-resolver.md, java-reviewer.md
│   └── swift/
│       └── rules/                     # 5 files
└── plugins/
    └── README.md
```

---

### Task 1: Initialize repo and create .gitignore

**Files:**
- Create: `~/claude-code-config/.gitignore`

- [ ] **Step 1: Create .gitignore**

```gitignore
node_modules/
.DS_Store
*.bak
.installed-manifest
```

- [ ] **Step 2: Initialize git repo**

```bash
cd ~/claude-code-config && git init
```

- [ ] **Step 3: Commit**

```bash
cd ~/claude-code-config && git add .gitignore && git commit -m "chore: initialize repo with .gitignore"
```

---

### Task 2: Copy core rules

**Files:**
- Copy: `~/.claude/rules/README.md` → `core/rules/README.md`
- Copy: `~/.claude/rules/common/*.md` (10 files) → `core/rules/common/`

- [ ] **Step 1: Create target directory and copy files**

```bash
mkdir -p ~/claude-code-config/core/rules/common
cp ~/.claude/rules/README.md ~/claude-code-config/core/rules/README.md
cp ~/.claude/rules/common/*.md ~/claude-code-config/core/rules/common/
```

- [ ] **Step 2: Verify file count**

```bash
find ~/claude-code-config/core/rules/ -name "*.md" -type f | wc -l
```

Expected: 11 (1 README + 10 common rules)

- [ ] **Step 3: Commit**

```bash
cd ~/claude-code-config && git add core/rules/ && git commit -m "feat: add core rules (common)"
```

---

### Task 3: Copy core agents

**Files:**
- Copy 15 agents from `~/.claude/agents/` → `core/agents/` (excluding openclaw-ops.md; language-specific agents go to lang/)

Core agents list: architect, build-error-resolver, chief-of-staff, code-reviewer, database-reviewer, doc-updater, docs-lookup, e2e-runner, harness-optimizer, loop-operator, planner, product-manager, refactor-cleaner, security-reviewer, tdd-guide

- [ ] **Step 1: Create target directory and copy files**

```bash
mkdir -p ~/claude-code-config/core/agents
for agent in architect build-error-resolver chief-of-staff code-reviewer database-reviewer doc-updater docs-lookup e2e-runner harness-optimizer loop-operator planner product-manager refactor-cleaner security-reviewer tdd-guide; do
  cp ~/.claude/agents/${agent}.md ~/claude-code-config/core/agents/
done
```

- [ ] **Step 2: Verify file count**

```bash
ls ~/claude-code-config/core/agents/*.md | wc -l
```

Expected: 15

- [ ] **Step 3: Commit**

```bash
cd ~/claude-code-config && git add core/agents/ && git commit -m "feat: add core agents"
```

---

### Task 4: Copy core commands

**Files:**
- Copy 48 generic commands from `~/.claude/commands/` → `core/commands/` (excluding 15 ECC-specific commands)

Excluded: claw, checkpoint, evolve, instinct-export, instinct-import, instinct-status, learn, learn-eval, loop-start, loop-status, model-route, projects, promote, prompt-optimize, setup-pm

Language-specific commands (cpp-*, go-*, kotlin-*, rust-*, python-review, gradle-build) go to core since they are invoked by agents and useful standalone.

- [ ] **Step 1: Create target directory and copy files**

```bash
mkdir -p ~/claude-code-config/core/commands
for cmd in ~/.claude/commands/*.md; do
  name=$(basename "$cmd")
  # Skip ECC-specific commands
  case "$name" in
    claw.md|checkpoint.md|evolve.md|instinct-export.md|instinct-import.md|instinct-status.md|learn.md|learn-eval.md|loop-start.md|loop-status.md|model-route.md|projects.md|promote.md|prompt-optimize.md|setup-pm.md)
      echo "SKIP: $name (ECC-specific)"
      ;;
    *)
      cp "$cmd" ~/claude-code-config/core/commands/
      ;;
  esac
done
```

- [ ] **Step 2: Verify file count**

```bash
ls ~/claude-code-config/core/commands/*.md | wc -l
```

Expected: 48

- [ ] **Step 3: Commit**

```bash
cd ~/claude-code-config && git add core/commands/ && git commit -m "feat: add core commands"
```

---

### Task 5: Copy core skills

**Files:**
- Copy 19 core skill directories from `~/.claude/skills/` → `core/skills/` (excluding personal/ECC/lang-specific)

Core skills: agent-studio, ai-regression-testing, api-design, api-integration-testing (without OPENCLAW_INTEGRATION.md), backend-patterns, coding-standards, e2e-testing, eval-harness, excalidraw-diagram (SKILL.md + README.md only, skip .git and references/), frontend-patterns, frontend-slides, iterative-retrieval, mcp-server-patterns, plankton-code-quality, project-guidelines-example, skill-stocktake, strategic-compact, tdd-workflow, verification-loop

Excluded: configure-ecc, continuous-learning, continuous-learning-v2, learned, openclaw-ops

- [ ] **Step 1: Create target directory and copy skill directories**

```bash
mkdir -p ~/claude-code-config/core/skills

# Skills that are just SKILL.md (single file)
for skill in ai-regression-testing api-design backend-patterns coding-standards e2e-testing eval-harness frontend-patterns iterative-retrieval mcp-server-patterns plankton-code-quality project-guidelines-example tdd-workflow verification-loop; do
  mkdir -p ~/claude-code-config/core/skills/$skill
  cp ~/.claude/skills/$skill/SKILL.md ~/claude-code-config/core/skills/$skill/
done

# Skills with extra files
# agent-studio (3 files)
cp -r ~/.claude/skills/agent-studio ~/claude-code-config/core/skills/

# api-integration-testing (skip OPENCLAW_INTEGRATION.md)
mkdir -p ~/claude-code-config/core/skills/api-integration-testing
cp ~/.claude/skills/api-integration-testing/SKILL.md ~/claude-code-config/core/skills/api-integration-testing/
cp ~/.claude/skills/api-integration-testing/README.md ~/claude-code-config/core/skills/api-integration-testing/ 2>/dev/null; true

# excalidraw-diagram (SKILL.md + README.md only, 105MB total — skip .git and references/)
mkdir -p ~/claude-code-config/core/skills/excalidraw-diagram
cp ~/.claude/skills/excalidraw-diagram/SKILL.md ~/claude-code-config/core/skills/excalidraw-diagram/
cp ~/.claude/skills/excalidraw-diagram/README.md ~/claude-code-config/core/skills/excalidraw-diagram/

# frontend-slides (2 files)
cp -r ~/.claude/skills/frontend-slides ~/claude-code-config/core/skills/

# skill-stocktake (4 files)
cp -r ~/.claude/skills/skill-stocktake ~/claude-code-config/core/skills/

# strategic-compact (2 files)
cp -r ~/.claude/skills/strategic-compact ~/claude-code-config/core/skills/
```

- [ ] **Step 2: Verify skill count**

```bash
ls -d ~/claude-code-config/core/skills/*/ | wc -l
```

Expected: 19

- [ ] **Step 3: Verify no large files sneaked in**

```bash
du -sh ~/claude-code-config/core/skills/excalidraw-diagram/
```

Expected: < 50KB (just 2 .md files)

- [ ] **Step 4: Commit**

```bash
cd ~/claude-code-config && git add core/skills/ && git commit -m "feat: add core skills"
```

---

### Task 6: Copy core scripts

**Files:**
- Copy 25 hook scripts from `~/.claude/scripts/hooks/` → `core/scripts/hooks/` (excluding insaits-security-monitor.py, insaits-security-wrapper.js)
- Copy `~/.claude/scripts/lib/utils.js` → `core/scripts/lib/`
- Copy `~/.claude/scripts/setup-package-manager.js` → `core/scripts/`

- [ ] **Step 1: Create target directories and copy files**

```bash
mkdir -p ~/claude-code-config/core/scripts/hooks
mkdir -p ~/claude-code-config/core/scripts/lib

for script in ~/.claude/scripts/hooks/*; do
  name=$(basename "$script")
  # Exclude insaits-security files
  case "$name" in
    insaits-security-monitor.py|insaits-security-wrapper.js)
      echo "SKIP: $name (insaits-specific)"
      ;;
    *)
      cp "$script" ~/claude-code-config/core/scripts/hooks/
      ;;
  esac
done

cp ~/.claude/scripts/lib/utils.js ~/claude-code-config/core/scripts/lib/
cp ~/.claude/scripts/setup-package-manager.js ~/claude-code-config/core/scripts/
```

- [ ] **Step 2: Verify file counts**

```bash
echo "Hooks: $(ls ~/claude-code-config/core/scripts/hooks/ | wc -l)"
echo "Lib: $(ls ~/claude-code-config/core/scripts/lib/ | wc -l)"
echo "Root scripts: $(ls ~/claude-code-config/core/scripts/*.js 2>/dev/null | wc -l)"
```

Expected: Hooks 25, Lib 1, Root scripts 1

- [ ] **Step 3: Commit**

```bash
cd ~/claude-code-config && git add core/scripts/ && git commit -m "feat: add core scripts"
```

---

### Task 7: Create core hooks.json

**Files:**
- Create: `core/hooks.json`

This is a cleaned version of the user's `settings.json` hooks, with paths using `~/.claude/scripts/hooks/` (not `${CLAUDE_PLUGIN_ROOT}`), and excluding all ECC-plugin-specific hooks. Only the hooks that reference `~/.claude/scripts/` paths belong here.

- [ ] **Step 1: Create hooks.json with user-level hooks only**

```bash
cat > ~/claude-code-config/core/hooks.json << 'HOOKSEOF'
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "node ~/.claude/scripts/hooks/post-edit-format.js"
          }
        ],
        "description": "Auto-format after editing (Prettier/Biome)"
      },
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "node ~/.claude/scripts/hooks/post-edit-typecheck.js"
          }
        ],
        "description": "TypeScript check after editing .ts/.tsx files"
      },
      {
        "matcher": "Edit",
        "hooks": [
          {
            "type": "command",
            "command": "node ~/.claude/scripts/hooks/post-edit-console-warn.js"
          }
        ],
        "description": "Warn about console.log statements after edits"
      },
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "node ~/.claude/scripts/hooks/quality-gate.js",
            "async": true,
            "timeout": 30
          }
        ],
        "description": "Run quality gate checks after file edits"
      }
    ],
    "Stop": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "node ~/.claude/scripts/hooks/check-console-log.js"
          }
        ],
        "description": "Check for console.log in modified files after each response"
      }
    ]
  }
}
HOOKSEOF
```

- [ ] **Step 2: Verify JSON is valid**

```bash
python3 -c "import json; json.load(open('$HOME/claude-code-config/core/hooks.json'))" 2>/dev/null || python -c "import json; json.load(open('$HOME/claude-code-config/core/hooks.json'))"
echo "Exit: $?"
```

Expected: Exit: 0

- [ ] **Step 3: Commit**

```bash
cd ~/claude-code-config && git add core/hooks.json && git commit -m "feat: add core hooks.json"
```

---

### Task 8: Copy language modules (typescript, python, golang, cpp, kotlin, rust, php, perl, java, swift)

**Files:**
- Create 10 lang subdirectories, each with rules/, skills/, agents/ as applicable

This is a large copy task. Each language module is independent.

- [ ] **Step 1: Copy all language rules**

```bash
# TypeScript
mkdir -p ~/claude-code-config/lang/typescript/rules
cp ~/.claude/rules/typescript/*.md ~/claude-code-config/lang/typescript/rules/

# Python
mkdir -p ~/claude-code-config/lang/python/rules
cp ~/.claude/rules/python/*.md ~/claude-code-config/lang/python/rules/

# Go
mkdir -p ~/claude-code-config/lang/golang/rules
cp ~/.claude/rules/golang/*.md ~/claude-code-config/lang/golang/rules/

# C++
mkdir -p ~/claude-code-config/lang/cpp/rules
cp ~/.claude/rules/cpp/*.md ~/claude-code-config/lang/cpp/rules/

# Kotlin
mkdir -p ~/claude-code-config/lang/kotlin/rules
cp ~/.claude/rules/kotlin/*.md ~/claude-code-config/lang/kotlin/rules/

# PHP
mkdir -p ~/claude-code-config/lang/php/rules
cp ~/.claude/rules/php/*.md ~/claude-code-config/lang/php/rules/

# Perl
mkdir -p ~/claude-code-config/lang/perl/rules
cp ~/.claude/rules/perl/*.md ~/claude-code-config/lang/perl/rules/

# Swift
mkdir -p ~/claude-code-config/lang/swift/rules
cp ~/.claude/rules/swift/*.md ~/claude-code-config/lang/swift/rules/
```

- [ ] **Step 2: Copy language skills**

```bash
# TypeScript
mkdir -p ~/claude-code-config/lang/typescript/skills/compose-multiplatform-patterns
cp ~/.claude/skills/compose-multiplatform-patterns/SKILL.md ~/claude-code-config/lang/typescript/skills/compose-multiplatform-patterns/

# Python
for skill in python-patterns python-testing django-patterns django-tdd django-verification; do
  mkdir -p ~/claude-code-config/lang/python/skills/$skill
  cp ~/.claude/skills/$skill/SKILL.md ~/claude-code-config/lang/python/skills/$skill/
done

# Go
for skill in golang-patterns golang-testing; do
  mkdir -p ~/claude-code-config/lang/golang/skills/$skill
  cp ~/.claude/skills/$skill/SKILL.md ~/claude-code-config/lang/golang/skills/$skill/
done

# C++
for skill in cpp-coding-standards cpp-testing; do
  mkdir -p ~/claude-code-config/lang/cpp/skills/$skill
  cp ~/.claude/skills/$skill/SKILL.md ~/claude-code-config/lang/cpp/skills/$skill/
done

# Kotlin
for skill in android-clean-architecture kotlin-coroutines-flows kotlin-exposed-patterns kotlin-ktor-patterns kotlin-patterns kotlin-testing; do
  mkdir -p ~/claude-code-config/lang/kotlin/skills/$skill
  cp ~/.claude/skills/$skill/SKILL.md ~/claude-code-config/lang/kotlin/skills/$skill/
done

# Rust
mkdir -p ~/claude-code-config/lang/rust/skills
for skill in rust-patterns rust-testing; do
  mkdir -p ~/claude-code-config/lang/rust/skills/$skill
  cp ~/.claude/skills/$skill/SKILL.md ~/claude-code-config/lang/rust/skills/$skill/
done

# PHP
for skill in laravel-patterns laravel-tdd laravel-verification; do
  mkdir -p ~/claude-code-config/lang/php/skills/$skill
  cp ~/.claude/skills/$skill/SKILL.md ~/claude-code-config/lang/php/skills/$skill/
done

# Perl
for skill in perl-patterns perl-testing; do
  mkdir -p ~/claude-code-config/lang/perl/skills/$skill
  cp ~/.claude/skills/$skill/SKILL.md ~/claude-code-config/lang/perl/skills/$skill/
done

# Java
for skill in java-coding-standards springboot-patterns springboot-tdd springboot-verification; do
  mkdir -p ~/claude-code-config/lang/java/skills/$skill
  cp ~/.claude/skills/$skill/SKILL.md ~/claude-code-config/lang/java/skills/$skill/
done
```

- [ ] **Step 3: Copy language agents**

```bash
# Python
mkdir -p ~/claude-code-config/lang/python/agents
cp ~/.claude/agents/python-reviewer.md ~/claude-code-config/lang/python/agents/

# Go
mkdir -p ~/claude-code-config/lang/golang/agents
cp ~/.claude/agents/go-build-resolver.md ~/claude-code-config/lang/golang/agents/
cp ~/.claude/agents/go-reviewer.md ~/claude-code-config/lang/golang/agents/

# C++
mkdir -p ~/claude-code-config/lang/cpp/agents
cp ~/.claude/agents/cpp-build-resolver.md ~/claude-code-config/lang/cpp/agents/
cp ~/.claude/agents/cpp-reviewer.md ~/claude-code-config/lang/cpp/agents/

# Kotlin
mkdir -p ~/claude-code-config/lang/kotlin/agents
cp ~/.claude/agents/kotlin-build-resolver.md ~/claude-code-config/lang/kotlin/agents/
cp ~/.claude/agents/kotlin-reviewer.md ~/claude-code-config/lang/kotlin/agents/

# Rust
mkdir -p ~/claude-code-config/lang/rust/agents
cp ~/.claude/agents/rust-build-resolver.md ~/claude-code-config/lang/rust/agents/
cp ~/.claude/agents/rust-reviewer.md ~/claude-code-config/lang/rust/agents/

# Java
mkdir -p ~/claude-code-config/lang/java/agents
cp ~/.claude/agents/java-build-resolver.md ~/claude-code-config/lang/java/agents/
cp ~/.claude/agents/java-reviewer.md ~/claude-code-config/lang/java/agents/
```

- [ ] **Step 4: Verify language module counts**

```bash
echo "=== Language module summary ==="
for lang in typescript python golang cpp kotlin rust php perl java swift; do
  dir=~/claude-code-config/lang/$lang
  rules=$(find "$dir/rules" -name "*.md" -type f 2>/dev/null | wc -l)
  skills=$(find "$dir/skills" -name "SKILL.md" -type f 2>/dev/null | wc -l)
  agents=$(find "$dir/agents" -name "*.md" -type f 2>/dev/null | wc -l)
  echo "$lang: rules=$rules skills=$skills agents=$agents"
done
```

Expected:
- typescript: rules=5 skills=1 agents=0
- python: rules=5 skills=5 agents=1
- golang: rules=5 skills=2 agents=2
- cpp: rules=5 skills=2 agents=2
- kotlin: rules=5 skills=6 agents=2
- rust: rules=0 skills=2 agents=2
- php: rules=5 skills=3 agents=0
- perl: rules=5 skills=2 agents=0
- java: rules=0 skills=4 agents=2
- swift: rules=5 skills=0 agents=0

- [ ] **Step 5: Commit**

```bash
cd ~/claude-code-config && git add lang/ && git commit -m "feat: add language modules (ts/py/go/cpp/kt/rs/php/perl/java/swift)"
```

---

### Task 9: Create plugins/README.md

**Files:**
- Create: `plugins/README.md`

- [ ] **Step 1: Write plugins README**

```bash
cat > ~/claude-code-config/plugins/README.md << 'EOF'
# Recommended Plugins

These plugins are distributed via their own marketplaces and are not included in this repo. Install them separately for additional capabilities.

## Superpowers

Skill-based workflow system: brainstorming, TDD, code review, debugging, parallel agents.

```bash
# Install via Claude Code
/install-plugin superpowers
```

Source: https://github.com/obra/superpowers-marketplace

## PUA (Performance Under Accountability)

High-agency problem-solving methodology with 13 corporate "flavors". Forces exhaustive debugging and owner mindset.

```bash
# Install via Claude Code
/install-plugin pua
```

Source: https://github.com/tanweai/pua

## Codex (OpenAI)

GPT-5.4 powered companion for second opinions, rescue tasks, and cross-model verification.

```bash
# Install via Claude Code
/install-plugin codex
```

Source: https://github.com/openai/codex-plugin-cc

## Frontend Design

Production-grade frontend interface creation with high design quality.

```bash
# Install via Claude Code
/install-plugin frontend-design
```

Source: https://github.com/anthropics/claude-plugins-official
EOF
```

- [ ] **Step 2: Commit**

```bash
cd ~/claude-code-config && git add plugins/ && git commit -m "feat: add plugins README with install instructions"
```

---

### Task 10: Create settings.example.json

**Files:**
- Create: `settings.example.json`

- [ ] **Step 1: Write settings example**

```bash
cat > ~/claude-code-config/settings.example.json << 'EOF'
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",
  "env": {
    "DISABLE_TELEMETRY": "1",
    "API_TIMEOUT_MS": "3000000"
  },
  "includeCoAuthoredBy": false,
  "permissions": {
    "allow": [
      "Bash",
      "Edit",
      "Glob",
      "Grep",
      "Read",
      "Write",
      "WebFetch",
      "WebSearch",
      "Skill"
    ],
    "deny": []
  },
  "enabledPlugins": {}
}
EOF
```

- [ ] **Step 2: Commit**

```bash
cd ~/claude-code-config && git add settings.example.json && git commit -m "feat: add settings.example.json"
```

---

### Task 11: Write install.sh

**Files:**
- Create: `install.sh`

This is the most complex task. The script must:
1. Parse arguments (module names or "all")
2. Copy files from modules to `~/.claude/`
3. Skip existing files
4. Merge hooks.json
5. Write manifest for uninstall
6. Print summary

- [ ] **Step 1: Write install.sh**

```bash
cat > ~/claude-code-config/install.sh << 'INSTALLEOF'
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

  # Merge using python (available on most systems)
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
    # Build set of existing (matcher, description) pairs
    existing = set()
    for entry in user['hooks'][hook_type]:
        existing.add((entry.get('matcher',''), entry.get('description','')))
    # Add non-duplicate entries
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
    echo -e "${GREEN}Hooks merged${NC}: $(python3 -c "
import json
with open('$user_hooks') as f:
    d = json.load(f)
print(sum(len(v) for v in d.get('hooks',{}).values()))
") total hooks in ~/.claude/hooks/hooks.json"
  else
    # Fallback: just append a note
    echo -e "${YELLOW}WARNING${NC}: Could not merge hooks.json automatically. Please merge $SCRIPT_DIR/core/hooks.json into $user_hooks manually."
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
INSTALLEOF
chmod +x ~/claude-code-config/install.sh
```

- [ ] **Step 2: Verify script syntax**

```bash
bash -n ~/claude-code-config/install.sh && echo "Syntax OK"
```

Expected: Syntax OK

- [ ] **Step 3: Commit**

```bash
cd ~/claude-code-config && git add install.sh && git commit -m "feat: add install.sh with modular installation"
```

---

### Task 12: Write uninstall.sh

**Files:**
- Create: `uninstall.sh`

- [ ] **Step 1: Write uninstall.sh**

```bash
cat > ~/claude-code-config/uninstall.sh << 'UNINSTALLEOF'
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
UNINSTALLEOF
chmod +x ~/claude-code-config/uninstall.sh
```

- [ ] **Step 2: Verify script syntax**

```bash
bash -n ~/claude-code-config/uninstall.sh && echo "Syntax OK"
```

Expected: Syntax OK

- [ ] **Step 3: Commit**

```bash
cd ~/claude-code-config && git add uninstall.sh && git commit -m "feat: add uninstall.sh"
```

---

### Task 13: Write README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write README**

```bash
cat > ~/claude-code-config/README.md << 'READMEEOF'
# Claude Code Config

Battle-tested Claude Code global configuration — rules, agents, commands, skills, and hooks. One-command install.

## What's Included

### Core (always installed)
- **15 agents**: architect, code-reviewer, security-reviewer, tdd-guide, planner, ...
- **48 commands**: /dev, /review, /verify, /tdd, /ship-ready, /plan, ...
- **19 skills**: tdd-workflow, verification-loop, api-design, frontend-patterns, ...
- **10 rules**: coding-style, security, testing, git-workflow, core-principles, ...
- **25 hook scripts**: post-edit-format, quality-gate, check-console-log, ...

### Language Packs (optional)
| Pack | Rules | Skills | Agents |
|------|-------|--------|--------|
| typescript | 5 | 1 | — |
| python | 5 | 5 | 1 |
| golang | 5 | 2 | 2 |
| cpp | 5 | 2 | 2 |
| kotlin | 5 | 6 | 2 |
| rust | — | 2 | 2 |
| java | — | 4 | 2 |
| php | 5 | 3 | — |
| perl | 5 | 2 | — |
| swift | 5 | — | — |

## Quick Start

```bash
git clone https://github.com/cathy0023/claude-code-config.git
cd claude-code-config

# Install core only
./install.sh

# Install core + specific languages
./install.sh core python golang

# Install everything
./install.sh all
```

Restart Claude Code after installation.

## How It Works

- Files are copied to `~/.claude/` (rules, agents, commands, skills, scripts)
- Existing files are **never overwritten** — skipped with a warning
- `hooks.json` is **merged** (new hooks appended, duplicates skipped)
- An install manifest is saved at `~/.claude/.installed-manifest` for clean uninstall

## Uninstall

```bash
./uninstall.sh
```

Removes only files installed by this tool. Your own files are untouched.

## Update

```bash
cd claude-code-config
git pull
./install.sh core python  # re-run with your modules
```

## Settings

See `settings.example.json` for recommended settings (permissions, env vars). Copy to `~/.claude/settings.json` and customize.

## Recommended Plugins

These are installed separately via Claude Code's plugin system:

- **[Superpowers](https://github.com/obra/superpowers-marketplace)** — Skill-based workflows (brainstorming, TDD, code review)
- **[PUA](https://github.com/tanweai/pua)** — High-agency problem-solving methodology
- **[Codex](https://github.com/openai/codex-plugin-cc)** — GPT-5.4 companion for second opinions

## Customization

- Edit any installed file in `~/.claude/` after installation — updates won't overwrite them
- Add your own rules/agents/commands alongside installed ones
- To add a new language pack, create `lang/<name>/` with `rules/`, `skills/`, `agents/` subdirs

## License

MIT
READMEEOF
```

- [ ] **Step 2: Commit**

```bash
cd ~/claude-code-config && git add README.md && git commit -m "feat: add README"
```

---

### Task 14: Verify and publish

**Files:**
- Verify all files exist and counts match spec
- Push to GitHub

- [ ] **Step 1: Run full inventory check**

```bash
echo "=== Final Inventory ==="
echo "Core rules: $(find ~/claude-code-config/core/rules/ -name '*.md' -type f | wc -l)"
echo "Core agents: $(find ~/claude-code-config/core/agents/ -name '*.md' -type f | wc -l)"
echo "Core commands: $(find ~/claude-code-config/core/commands/ -name '*.md' -type f | wc -l)"
echo "Core skills: $(ls -d ~/claude-code-config/core/skills/*/ | wc -l)"
echo "Core scripts: $(find ~/claude-code-config/core/scripts/ -type f | wc -l)"
echo "Core hooks.json: $(test -f ~/claude-code-config/core/hooks.json && echo YES || echo NO)"
echo "Language packs: $(ls -d ~/claude-code-config/lang/*/ | wc -l)"
echo ""
echo "=== No secrets? ==="
grep -rn "sk-\|api_key\|password\|token\|secret" ~/claude-code-config/ --include="*.json" --include="*.md" --include="*.sh" || echo "CLEAN: No secrets found"
```

Expected:
- Core rules: 11 (1 README + 10)
- Core agents: 15
- Core commands: 48
- Core skills: 19
- Core scripts: 27
- Core hooks.json: YES
- Language packs: 10
- No secrets found

- [ ] **Step 2: Test install.sh dry run (syntax only)**

```bash
bash -n ~/claude-code-config/install.sh && echo "install.sh: syntax OK"
bash -n ~/claude-code-config/uninstall.sh && echo "uninstall.sh: syntax OK"
```

- [ ] **Step 3: Add remote and push**

```bash
cd ~/claude-code-config
git remote add origin https://github.com/cathy0023/claude-code-config.git
git branch -M main
git push -u origin main
```

- [ ] **Step 4: Final commit if any remaining changes**

```bash
cd ~/claude-code-config && git status
```

Expected: clean working tree

---

## Self-Review

1. **Spec coverage**: Every section of the spec maps to a task. Exclusion list is implemented in Task 4 (commands), Task 5 (skills), Task 6 (scripts), Task 8 (lang agents excludes openclaw-ops). Hooks merge logic in Task 11. Manifest/uninstall in Task 12. Settings example in Task 10. Plugins README in Task 9.

2. **Placeholder scan**: No TBD, TODO, or vague steps. All file lists are concrete. All commands are exact.

3. **Type consistency**: Module names ("core", "typescript", "python", etc.) are consistent across all tasks. File paths use the same `~/claude-code-config/` prefix throughout.
