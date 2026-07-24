---
description: 把当前分支与最新的 main/master 合并，减少上线冲突。自动检测主分支、fetch、merge，冲突时安全中止
allowed-tools: Bash
argument-hint: [--rebase] [--no-fetch] [--push]
# examples:
#   - /update-from-main
#   - /update-from-main --rebase
#   - /update-from-main --push
---

# /update-from-main

把当前分支与最新的主分支（main 或 master）合并，确保上线前减少冲突。

参数：$ARGUMENTS

## 参数说明

- `--rebase`：用 `git rebase` 代替 `git merge`（历史更线性，但会改写已推送的 commit）
- `--no-fetch`：跳过 `git fetch`，使用本地已有的主分支引用
- `--push`：合并完成后自动 push 当前分支（默认不 push，由用户手动决定）

---

## 阶段 1：前置检查

### 1.1 检查当前分支

```bash
git branch --show-current
```

记录为 `SOURCE_BRANCH`。

**禁止情形**：
- 当前在 `main` / `master` 上 -> 报错退出：

```
错误：当前处于 main 分支，不应在此执行合并。请先切到 feature/fix 分支。
```

- detached HEAD 状态 -> 报错退出：

```
错误：当前处于 detached HEAD，无法合并。
```

### 1.2 检查工作区是否干净

```bash
git status --porcelain
```

如果有未提交的修改：

```
错误：工作区不干净，请先 commit 或 stash 以下文件：
  - <文件1>
  - <文件2>
```

**不自动 stash**，强制用户先处理。理由：避免把临时改动裹进 merge commit。

### 1.3 自动检测主分支

优先 `main`，其次 `master`：

```bash
# 先看远程是否有 main
git ls-remote --heads origin main
# 没有再看 master
git ls-remote --heads origin master
```

记录为 `MAIN_BRANCH`。两者都没有则报错：

```
错误：远程既无 main 也无 master，无法判断主分支。
```

---

## 阶段 2：拉取最新主分支

### 2.1 Fetch（除非 `--no-fetch`）

```bash
git fetch origin <MAIN_BRANCH>
```

更新本地的 `origin/<MAIN_BRANCH>` 引用。

fetch 失败则报错退出：

```
错误：fetch origin/<MAIN_BRANCH> 失败，请检查网络或仓库权限。
```

### 2.2 展示合并预览

```bash
# 当前分支领先主分支的 commit
git log --oneline origin/<MAIN_BRANCH>..<SOURCE_BRANCH>

# 主分支领先当前分支的 commit
git log --oneline <SOURCE_BRANCH>..origin/<MAIN_BRANCH>
```

向用户展示：

```
当前分支：<SOURCE_BRANCH>
主分支：<MAIN_BRANCH>

主分支新增 <N> 个 commit，需要合并：
  <hash1> <message1>
  <hash2> <message2>
  ...

合并方式：<merge|rebase>

确认？[Y/n]
```

如果主分支没有任何新 commit（领先数为 0），直接退出：

```
✓ 当前分支已是 <MAIN_BRANCH> 最新，无需合并。
```

用户输入 `Y`、`y` 或直接回车则继续；输入 `n` 则取消。

---

## 阶段 3：执行合并

### 3.1 默认 merge 模式

```bash
git merge origin/<MAIN_BRANCH> --no-edit
```

`--no-edit` 使用默认 merge commit message，避免弹出编辑器。

### 3.2 `--rebase` 模式

```bash
git rebase origin/<MAIN_BRANCH>
```

**rebase 警告**：如果当前分支已经推送到远程，rebase 会改写历史，后续 push 需要 `--force-with-lease`。展示警告：

```
⚠️  rebase 会改写已推送的 commit。如果当前分支已推送到远程并有人协作，
   后续 push 需要使用 `git push --force-with-lease`，可能影响其他协作者。

   确认使用 rebase？[Y/n]
```

---

## 阶段 4：冲突处理

### 4.1 检测冲突

merge / rebase 后立即检查：

```bash
git status --porcelain | grep -E '^(UU|AA|DD|AU|UD|UA|DU)'
```

如果有冲突文件，**立即中止**操作并恢复到合并前状态：

**merge 冲突**：
```bash
git merge --abort
```

**rebase 冲突**：
```bash
git rebase --abort
```

### 4.2 展示冲突并退出

```
❌ 合并冲突，已中止并恢复到合并前状态。

冲突文件：
  - <文件1>
  - <文件2>
  ...

建议处理步骤：
1. 手动执行 `git merge origin/<MAIN_BRANCH>` 重新触发合并
2. 逐个解决冲突文件
3. `git add <已解决文件>` 后 `git commit`
4. 或使用 IDE 的合并工具辅助解决

（update-from-main 不会自动解决冲突，避免误判业务逻辑）
```

---

## 阶段 5：完成与推送

### 5.1 合并成功输出

```
✓ 已将 <MAIN_BRANCH> 合并到 <SOURCE_BRANCH>

新增 commit：
  <hash1> <message1>
  <hash2> <message2>
  ...

合并 commit：<merge_hash> Merge origin/<MAIN_BRANCH> into <SOURCE_BRANCH>

下一步：
  - 检查改动：git diff HEAD~<N>
  - 运行测试：npm test / pnpm test
  - 推送：git push  （或使用 --push 自动推送）
```

### 5.2 `--push` 自动推送

```bash
git push origin <SOURCE_BRANCH>
```

- 普通 merge：直接 push
- rebase 模式：使用 `--force-with-lease`（更安全的 force push）

```bash
git push --force-with-lease origin <SOURCE_BRANCH>
```

push 失败则提示用户手动处理：

```
⚠️  push 失败（远程可能有新提交）。请手动执行：
   git pull --rebase origin <SOURCE_BRANCH>
   git push origin <SOURCE_BRANCH>
```

---

## 注意事项

1. **不会自动 commit 未提交修改**：工作区必须干净，避免把临时改动裹进 merge commit
2. **不会自动解决冲突**：冲突时直接 abort，让用户手动处理，避免误判业务逻辑
3. **默认不 push**：合并完成后由用户决定何时推送
4. **rebase 慎用**：已推送的分支 rebase 后需要 force push，可能影响协作者
5. **支持 main/master 自动检测**：优先 main，找不到再找 master
