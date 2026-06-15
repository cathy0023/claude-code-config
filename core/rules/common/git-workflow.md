# Git Workflow

## Commit Message Format
```
<type>: <description>

<optional body>
```

Types: feat, fix, refactor, docs, test, chore, perf, ci

Note: Attribution disabled globally via ~/.claude/settings.json.

## Branch Merge Rules (CRITICAL)

**NEVER merge the following branches into a feature/bugfix/hotfix branch:**
- `test` / `testing`
- `staging`
- `develop` (unless it IS the base branch)
- `main` / `master`

**Allowed operations to sync with upstream:**
- `git rebase main` — sync latest main into your branch
- `git pull --rebase origin <current-branch>` — sync remote of same branch

**If you need code from another branch:** cherry-pick the specific commit, never merge the whole branch.

Before running ANY `git merge` command, confirm:
1. What branch is being merged FROM?
2. What branch is being merged INTO?
3. Is this a PR merge (into main/master) or a local sync?

If merging FROM test/staging/develop INTO a feature branch → **STOP and ask the user**.

## Pull Request Workflow

When creating PRs:
1. Analyze full commit history (not just latest commit)
2. Use `git diff [base-branch]...HEAD` to see all changes
3. Draft comprehensive PR summary
4. Include test plan with TODOs
5. Push with `-u` flag if new branch

> For the full development process (planning, TDD, code review) before git operations,
> see [development-workflow.md](./development-workflow.md).
