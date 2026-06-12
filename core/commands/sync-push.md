---
description: 提交当前分支代码并推送到远程，然后合并到目标分支（默认test）并推送
allowed-tools: Bash
argument-hint: [目标分支名] [--commit-only]
# examples:
#   - /sync-push
#   - /sync-push dev
#   - /sync-push staging
#   - /sync-push test --commit-only
---

# /sync-push

一条龙流程：提交当前代码 → 推送到当前分支远程 → 合并到目标分支 → 推送目标分支 → 切回原分支。

参数：$ARGUMENTS

## 参数说明

- **目标分支名**：可选，默认 `test`。支持 `dev`、`staging` 等任意分支名
- `--commit-only`：只执行阶段 1（提交推送当前分支），不执行合并

---

## 阶段 1：提交当前分支代码

### 1.1 检查当前分支

```bash
git branch --show-current
```

记录为 `SOURCE_BRANCH`。如果处于 detached HEAD 或 main/master 分支，报错退出：

```
错误：当前处于 <分支名>，不应在主分支上直接执行此操作。
```

### 1.2 检查是否有变更

```bash
git status --porcelain
```

如果没有变更且没有已暂存的文件：
- 如果用户传了 `--commit-only`，提示「没有变更需要提交」并退出
- 否则跳到阶段 2（只做合并）

### 1.3 展示变更概览

```bash
git status
git diff --stat
git diff --staged --stat
```

向用户展示变更文件列表。

### 1.4 暂存变更

- 如果没有已暂存的文件：自动暂存所有修改和新增文件
- 如果已有暂存文件：仅使用已暂存的文件
- 排除不应提交的文件（`.env`、`node_modules`、`dist`、`.DS_Store` 等）

### 1.5 生成并确认提交信息

分析变更内容，生成 conventional commits 格式的提交信息：

- `feat:` 新功能
- `fix:` 错误修复
- `refactor:` 代码重构
- `style:` 样式调整
- `docs:` 文档更新
- `perf:` 性能优化
- `test:` 测试相关
- `chore:` 构建/配置变动

**向用户展示提交信息，等待确认。** 用户可修改或直接确认。

### 1.6 执行提交并推送

```bash
git commit -m "<提交信息>"
git push -u origin <SOURCE_BRANCH>
```

如果推送失败（远程有新提交），先 `git pull --rebase` 再推送。rebase 冲突则中止并提示手动解决。

**→ 阶段 1 完成：当前分支已提交并推送**

### 1.7 --commit-only 分支

如果用户传了 `--commit-only`，到此结束，输出结果后退出。

---

## 阶段 2：合并到目标分支

### 2.1 解析目标分支

- 从参数中提取目标分支名（排除 `--commit-only`）
- 无参数则默认使用 `test`
- 展示确认信息：

```
将把 <SOURCE_BRANCH> 合并到 <TARGET_BRANCH> 并推送。
确认？[Y/n]
```

用户输入 `Y`、`y` 或直接回车则继续；输入 `n` 则取消。

### 2.2 检查目标分支是否存在

```bash
git branch -a | grep -E "(^|\s)<TARGET_BRANCH>$|remotes/origin/<TARGET_BRANCH>"
```

本地和远程都不存在则报错退出：

```
错误：目标分支 <TARGET_BRANCH> 不存在（本地和远程均未找到）。
```

### 2.3 切换到目标分支

```bash
git switch <TARGET_BRANCH>
```

如果本地不存在但远程有：

```bash
git switch -c <TARGET_BRANCH> origin/<TARGET_BRANCH>
```

### 2.4 拉取最新代码

```bash
git pull origin <TARGET_BRANCH>
```

如果 pull 失败（冲突或网络问题），切回原分支并报错：

```bash
git switch <SOURCE_BRANCH>
```

```
错误：拉取 <TARGET_BRANCH> 最新代码失败，已切回 <SOURCE_BRANCH>。
```

### 2.5 执行合并

```bash
git merge <SOURCE_BRANCH>
```

### 2.6 冲突处理

如果合并产生冲突：

1. 立即中止合并：

```bash
git merge --abort
```

2. 切回原分支：

```bash
git switch <SOURCE_BRANCH>
```

3. 展示冲突文件列表：

```bash
# 在合并前用 --no-commit 试一下，获取冲突信息后立即 abort
git switch <TARGET_BRANCH>
git merge --no-commit <SOURCE_BRANCH>
git diff --name-only --diff-filter=U
git merge --abort
git switch <SOURCE_BRANCH>
```

4. 向用户展示冲突文件，询问如何处理：

```
合并冲突，以下文件存在冲突：
  - <文件1>
  - <文件2>

请选择处理方式：
1. 手动解决后重新执行 /sync-push
2. 用当前分支的版本覆盖（ours）
3. 用目标分支的版本覆盖（theirs）
4. 取消，后续手动处理
```

根据用户选择执行对应操作后重新合并，或直接退出。

### 2.7 推送目标分支

```bash
git push origin <TARGET_BRANCH>
```

推送失败则按阶段 1.6 同样逻辑处理（pull --rebase 后重试）。

### 2.8 切回原分支

```bash
git switch <SOURCE_BRANCH>
```

---

## 最终输出

```
✓ 当前分支 <SOURCE_BRANCH> 已提交并推送
  Commit: <hash> <message>

✓ 已合并到 <TARGET_BRANCH> 并推送

✓ 已切回 <SOURCE_BRANCH>
```

如果 `--commit-only`：

```
✓ 当前分支 <SOURCE_BRANCH> 已提交并推送
  Commit: <hash> <message>
（未执行合并，使用了 --commit-only）
```
