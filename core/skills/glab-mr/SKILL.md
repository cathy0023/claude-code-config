---
name: glab-mr
description: >
  GitLab Merge Request 创建器。自动从 RFC 或 commit 历史生成 MR 标题和描述，
  调用 glab CLI 创建 MR。
  触发词：glab-mr、创建 MR、create merge request、提 MR。
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
---

# glab-mr: GitLab MR 创建器

封装 GitLab MR 创建流程，自动生成标题和描述。

## 前置条件

1. `glab` CLI 已安装。未安装时提示用户：
   ```bash
   brew install glab
   glab auth login
   ```

2. 当前分支有未合并到目标分支的 commits

3. 工作区干净（无未提交变更）

## 输入

- **目标分支**（默认 `develop`）
- **RFC 文件路径**（可选，用于生成 MR 描述）
- **额外标签**（可选，如 `--label "feature"`）

如未提供 RFC 路径，从 `git log` 提取 commit 信息生成描述。

## 处理流程

### Step 1: 收集信息

**MR 标题**来源（按优先级）：
1. 最近的 feat/fix/refactor 类 commit message
2. 如果有关联 RFC → 从 RFC title 生成
3. 如果只有一个 commit → 直接用 commit message

**MR 描述**来源（按优先级）：
1. 如果有关联 RFC → 提取 Goals + Acceptance Criteria
2. 从 `git log --oneline origin/{target}..HEAD` 的完整 commit 列表生成
3. 包含 Test Plan 段落（列出关键测试点）

### Step 2: 生成 MR 描述模板

```markdown
## Summary

<!-- 从 RFC Goals 或 commit 概括 -->

## Changes

<!-- git log --oneline 列表 -->

## Test Plan

- [ ] 关键测试点 1
- [ ] 关键测试点 2
- [ ] CI 通过
```

### Step 3: 创建 MR

```bash
glab mr create \
  --title "{title}" \
  --description "{description}" \
  --target-branch {target} \
  --remove-source-branch
```

如果 glab 提示需要选择项目（多个 remote），自动选择 origin。

### Step 4: 输出结果

成功：
```json
{
  "event": "mr_created",
  "url": "https://gitlab.com/...",
  "target_branch": "develop",
  "source_branch": "feat/xxx"
}
```

失败：
```json
{
  "event": "blocked",
  "stage": "glab_mr",
  "reason": "glab auth required",
  "details": "Run: glab auth login"
}
```

## Gate

- **通过**：MR 创建成功，返回 URL
- **阻塞**：glab 未安装、未认证、push 失败、MR 创建失败

## 错误处理

| 错误 | 处理 |
|------|------|
| `glab: command not found` | 提示安装命令 |
| `authentication required` | 提示 `glab auth login` |
| `no commits to merge` | 提示先 commit 和 push |
| `branch already merged` | 告知分支已合并，无需 MR |
| `conflict detected` | 提示需要 rebase/merge 目标分支 |
