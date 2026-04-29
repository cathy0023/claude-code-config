# Claude Code Config

Battle-tested Claude Code global configuration — rules, agents, commands, skills, and hooks. One-command install.

## What's Included

### Core (always installed)
- **15 agents**: architect, code-reviewer, security-reviewer, tdd-guide, planner, build-error-resolver, ...
- **48 commands**: /dev, /review, /verify, /tdd, /ship-ready, /plan, /e2e, ...
- **19 skills**: tdd-workflow, verification-loop, api-design, frontend-patterns, e2e-testing, ...
- **10 rules**: coding-style, security, testing, git-workflow, core-principles, ...
- **23 hook scripts**: post-edit-format, quality-gate, check-console-log, ...
- **hooks.json**: Auto-format, typecheck, quality-gate hooks (merged, not overwritten)

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

Existing files are skipped, so your customizations are preserved. To force-update a specific file, delete it manually first, then re-run install.

## Settings

See `settings.example.json` for recommended settings (permissions, env vars). Copy to `~/.claude/settings.json` and customize.

## Recommended Plugins

These are installed separately via Claude Code's plugin system:

- **[Superpowers](https://github.com/obra/superpowers-marketplace)** — Skill-based workflows (brainstorming, TDD, code review)
- **[PUA](https://github.com/tanweai/pua)** — High-agency problem-solving methodology
- **[Codex](https://github.com/openai/codex-plugin-cc)** — GPT-5.4 companion for second opinions

See `plugins/README.md` for installation instructions.

## Customization

- Edit any installed file in `~/.claude/` after installation — updates won't overwrite them
- Add your own rules/agents/commands alongside installed ones
- To add a new language pack, create `lang/<name>/` with `rules/`, `skills/`, `agents/` subdirs

## License

MIT
