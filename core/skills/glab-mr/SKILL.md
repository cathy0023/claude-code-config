---
name: glab-mr
description: >
  GitLab Merge Request 创建器（适配自建 GitLab git.mgvai.cn）。
  自动检测 source/target 分支、查重、生成 conventional commits 标题和结构化描述，
  调用 glab CLI 创建或更新 MR。
  触发词：glab-mr、创建 MR、create merge request、提 MR、glab mr。
allowed-tools:
  - Read
  - Bash
  - Grep
  - Glob
  - Write
  - Edit
---

# glab-mr: GitLab MR 创建器

封装 GitLab MR 创建/更新流程。**只使用 `glab` CLI**（不是 `gh`），适配自建 GitLab `git.mgvai.cn`。

## 核心原则

1. **永远用 `glab`，不用 `gh`** — `gh` 是 GitHub CLI，生成 github.com 链接；GitLab 仓必须用 `glab`
2. **永远显式指定 `--source-branch`** — 不指定会触发交互式选择，非交互模式下卡死
3. **长描述用 `"$(cat file)"`** — `--description "多行字符串"` 会丢失换行；写临时文件再 cat 进来
4. **先查重再创建** — `glab mr list --source-branch X` 检查是否已有 MR；有则更新，无则新建
5. **默认 target 是 `main`** — 不是 `develop`，除非用户明确指定
6. **默认不删 source branch** — 不加 `--remove-source-branch`，合并后由用户决定

## 前置条件

1. `glab` CLI 已安装（`brew install glab`）
2. `glab auth login` 已认证到 `git.mgvai.cn`（验证：`glab auth status`）
3. 当前在 feature/fix 分支（不在 main/master/detached HEAD）
4. 工作区干净（`git status --porcelain` 无输出）
5. 当前分支已 push 到远程（`git rev-parse HEAD` == `git rev-parse origin/<branch>`）

## 输入

- **目标分支**（可选，默认 `main`；支持 `test`、`develop` 等）
- **MR 标题**（可选，默认从 commit 历史生成 conventional commits 格式）
- **MR 描述**（可选，默认从 diff stat + commit messages 生成）
- **--update-existing**（可选，如果 MR 已存在则更新 title/description 而不是报错）
- **--squash**（可选，合并时 squash commits）
- **--remove-source-branch**（可选，合并后删除 source branch）

## 处理流程

### Step 1: 前置检查

```bash
# 1. 检查 glab 已安装
which glab || { echo "ERROR: glab not installed. Run: brew install glab"; exit 1; }

# 2. 检查已认证
glab auth status | grep "Logged in" || { echo "ERROR: Run: glab auth login"; exit 1; }

# 3. 检查当前分支（不能是 main/master/detached）
SOURCE_BRANCH=$(git branch --show-current)
[[ "$SOURCE_BRANCH" == "main" || "$SOURCE_BRANCH" == "master" ]] && {
  echo "ERROR: current branch is $SOURCE_BRANCH, switch to feature/fix branch first"
  exit 1
}

# 4. 检查工作区干净
git status --porcelain | grep -q . && {
  echo "ERROR: working tree dirty, commit or stash first"
  exit 1
}

# 5. 检查已 push 到远程
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/$SOURCE_BRANCH 2>/dev/null)
[[ "$LOCAL" != "$REMOTE" ]] && {
  echo "ERROR: local HEAD != origin/$SOURCE_BRANCH, push first"
  exit 1
}
```

### Step 2: 确定 target 分支

- 用户指定 -> 用用户指定
- 未指定 -> 默认 `main`
- 验证 target 存在：`git ls-remote --heads origin <target>`

### Step 3: 查重（避免重复创建 MR）

```bash
glab mr list --source-branch $SOURCE_BRANCH
```

- 输出 `No Merge Requests` -> 进入 Step 4 创建新 MR
- 输出有 MR -> 进入 Step 5 更新已存在 MR（或询问用户是否更新）

### Step 4: 创建新 MR

#### 4.1 生成标题

从 commit 历史推断 conventional commits 格式标题：

```bash
# 取最近一个 feat/fix/refactor commit 的 message 作为标题
git log --oneline --no-merges origin/<target>..HEAD | head -5
```

标题规则：
- 优先用最近的 `feat`/`fix`/`refactor` commit 第一行
- 如果只有一个 commit -> 直接用该 commit message
- 如果有关联 RFC -> `fix(scope): <RFC 标题> (RFC-NNN)`

#### 4.2 生成描述

从 diff stat + commit 列表生成结构化描述，写入临时文件：

```bash
# diff stat
git diff --stat origin/<target>...HEAD

# 完整 commit 列表
git log --oneline --no-merges origin/<target>..HEAD

# 实际 diff（用于提取关键改动）
git diff origin/<target>...HEAD
```

描述模板（写入 `/tmp/mr_desc_<branch>.md`）：

```markdown
## 背景

<!-- 一句话说明为什么做这个 MR -->

## 改动范围

N 个文件，N 行改动：

| 文件 | 改动 | 影响 |
|---|---|---|
| `path/to/file.go:行号` | 简述 | 影响什么 |

### Commit 列表

- `<hash>` <message>
- `<hash>` <message>

## 测试

- [x] `go build ./...` / `pnpm test` / 等等
- [x] CI pipeline 通过
- [ ] 其他验证项

## 关联

- RFC: `docs/rfcs/...`（如有）
- 姊妹 MR: <url>（如有跨仓联动）
```

#### 4.3 执行 glab mr create

```bash
glab mr create \
  --source-branch $SOURCE_BRANCH \
  --target-branch $TARGET_BRANCH \
  --title "$TITLE" \
  --description "$(cat /tmp/mr_desc_$SOURCE_BRANCH.md)" \
  --yes
```

**关键参数说明**：
- `--source-branch`：**必须显式指定**，否则 glab 会交互式询问，非交互模式卡死
- `--target-branch`：默认 `main`
- `--description "$(cat file)"`：用 cat 读取文件内容，保留多行换行（直接传字符串会丢失 markdown 格式）
- `--yes`：跳过所有确认提示

**不要用的参数**：
- `--description-file`：glab 没有这个 flag（会报 `Unknown flag`）
- `--remove-source-branch`：除非用户明确要求，默认不删 source branch
- `--squash`：除非用户明确要求，默认不 squash

#### 4.4 提取 MR URL

从 glab 输出中提取 MR URL：

```
ok created !3712 https://git.mgvai.cn/service/mgvcore/-/merge_requests/3712
```

URL 格式：`https://<host>/<project-path>/-/merge_requests/<number>`

### Step 5: 更新已存在 MR

如果 Step 3 发现已存在 MR：

```bash
# 查看现有 MR
glab mr view <number>

# 更新 title 和 description
glab mr update <number> \
  --title "$NEW_TITLE" \
  --description "$(cat /tmp/mr_desc_$SOURCE_BRANCH.md)"
```

注意：`glab mr update` 不需要 `--source-branch`，只需 MR number。

### Step 6: 输出结果

成功创建：
```
✓ MR 已创建
  URL: https://git.mgvai.cn/<project>/-/merge_requests/<n>
  Source: <source-branch> -> Target: <target-branch>
  Title: <title>
```

成功更新：
```
✓ MR !<n> 已更新
  URL: https://git.mgvai.cn/<project>/-/merge_requests/<n>
  更新内容: title + description
```

失败：
```
✗ MR 创建/更新失败
  原因: <具体错误>
  建议: <修复步骤>
```

## 常见错误与修复

| 错误 | 原因 | 修复 |
|------|------|------|
| `Unknown flag: --description-file` | glab 没有这个 flag | 用 `--description "$(cat file)"` |
| `glab: command not found` | glab 未安装 | `brew install glab` |
| `authentication required` | 未认证 | `glab auth login`（选 `git.mgvai.cn`） |
| `no commits to merge` | source 已合入 target | 不需要创建 MR |
| `branch already merged` | 分支已合并 | 不需要创建 MR |
| `source branch not found` | 本地分支名和远程不一致 | 先 `git push -u origin <branch>` |
| 创建了 github.com 链接 | 误用了 `gh` CLI | 改用 `glab`（本 skill 只用 glab） |
| 交互式提示卡住 | 缺 `--yes` 或 `--source-branch` | 两个都必须显式指定 |

## 跨仓姊妹 MR 场景

当改动跨两个仓库（如 ai-sop-api + mgvcore）时：

1. 先在 A 仓创建 MR，拿到 URL_A
2. 再在 B 仓创建 MR，描述里引用 URL_A：
   ```markdown
   ## 关联
   - 姊妹 MR（A 仓）: <URL_A>
   ```
3. 回到 A 仓更新 MR 描述，补上 B 仓 MR URL：
   ```bash
   glab mr update <A_number> --description "$(cat /tmp/mr_desc_with_b_url.md)"
   ```

## 使用方式

```
/glab-mr                              # 当前分支 -> main，自动生成标题和描述
/glab-mr --target test                # 当前分支 -> test
/glab-mr --title "fix: xxx"           # 指定标题
/glab-mr --update-existing            # 已存在则更新
```

## 注意事项

1. **只支持 GitLab**（`glab` CLI）。GitHub 仓请用 `gh pr create`
2. **默认 target 是 `main`**，不是 `develop`（除非用户指定）
3. **不自动 push** — 如果本地有未 push 的 commit，会报错要求先 push
4. **不自动删 source branch** — 合并后由用户决定
5. **不自动 squash** — 由用户在 GitLab UI 上合并时决定
6. **描述用临时文件** — 写入 `/tmp/mr_desc_<branch>.md`，用 `"$(cat file)"` 传入，保留 markdown 格式
