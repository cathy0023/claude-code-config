---
description: 拉取 GitLab MR 评论 → 质疑鉴定 P0 真伪 → 修复 → 提交。不盲目接受 reviewer 意见
argument-hint: <MR-URL>
allowed-tools: Bash(curl:*), Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Read, Write, Edit, Grep, Glob
---

# /review-fix - MR 评论驱动的 P0 修复闭环

从 GitLab MR 拉取 reviewer 评论，对每个 P0 问题先质疑再验证，确认真问题后才修复并提交。核心原则：**不盲目信任 reviewer**。

参数：$ARGUMENTS

## 前置条件检查

1. 检查是否提供了 MR URL（$ARGUMENTS 非空），如果为空则提示用户：
   ```
   请提供 GitLab MR 链接，例如：
   /review-fix https://gitlab.com/group/project/-/merge_requests/123
   ```
2. 检查 `GITLAB_TOKEN` 环境变量是否已设置：
   ```bash
   if [ -z "$GITLAB_TOKEN" ]; then echo "NOT_SET"; else echo "OK"; fi
   ```
   - 如果 `NOT_SET`，降级方案：提示用户手动粘贴 MR 评论内容，跳过 API 调用，直接进入 Step 2 鉴定

---

## Step 1: 解析 MR 链接 & 拉取评论

### 1.1 从 URL 提取信息

从 MR URL 中解析：
- **GitLab Host**: 例如 `gitlab.com`（自建 GitLab 则提取对应 host）
- **Project Path**: 例如 `group/subgroup/project`
- **MR IID**: 例如 `123`

URL 格式示例：
- `https://gitlab.com/group/project/-/merge_requests/123`
- `https://gitlab.example.com/group/subgroup/project/-/merge_requests/456`

### 1.2 对 project path 进行 URL encode

将 `/` 替换为 `%2F`：`group/subgroup/project` → `group%2Fsubgroup%2Fproject`

### 1.3 调用 GitLab API 获取 notes

```bash
curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "https://<GITLAB_HOST>/api/v4/projects/<ENCODED_PROJECT_ID>/merge_requests/<IID>/notes?sort=asc&per_page=100"
```

如果评论超过 100 条（检查响应数组长度），使用分页参数 `page=2` 继续拉取。

### 1.4 解析并展示评论

从 JSON 响应中提取每条 note 的关键字段：
- `id` - note ID
- `author.name` - 评论者
- `body` - 评论内容
- `created_at` - 创建时间
- `resolvable` - 是否可解决
- `resolved` - 是否已解决

筛选出 **未解决的、含有 P0 标记的评论**，按时间顺序展示给用户。

如果 API 调用失败（非 2xx），检查 token 权限并报告错误。

---

## Step 2: P0 问题鉴定（三问鉴定）

对筛选出的每个 P0 评论，执行「三问鉴定」。**这是本命令的核心差异化价值**。

### 三问鉴定标准

对每个 P0 标记的问题，逐一回答：

| 问题 | 含义 | 判定方法 |
|------|------|---------|
| **问1: 事实核查** | 这个 P0 指出的问题是真实存在的吗？ | 读相关代码文件，验证 reviewer 指出的代码行是否存在、行为是否符合 reviewer 描述 |
| **问2: 判断准确性** | reviewer 的判断是否准确？有没有可能看错了？ | 检查 reviewer 是否只看 diff 上下文导致误判（如 diff 只显示几行），是否有代码风格偏好被当成功能问题 |
| **问3: 政治判断** | 即使技术上没问题，会阻塞 MR 合入吗？ | P0 是否只是为了提高关注度、是否是团队规范强制的、reviewer 是否有 merge 权限 |

### 分类输出

对每个 P0 评论，给出分类结论：

```
### P0 #N: [reviewer 评论简述]

**原始评论**: [引用评论内容]
**涉及文件**: [文件路径:行号]

**三问鉴定**:
- 问1（事实）: [YES/NO] + 证据
- 问2（准确）: [YES/NO] + 分析
- 问3（阻塞）: [YES/NO] + 理由

**结论**: ✅确认真问题 / ⚠️需要澄清 / ❌假阳性误判
```

分类标准：
- **✅确认真问题**: 问1=YES，且问2≠明显错误。需要修复。
- **⚠️需要澄清**: 问1=YES 或 UNCLEAR，但问2=UNCLEAR。需要回复 reviewer 讨论。
- **❌假阳性误判**: 问1=NO（问题不存在），或问2=明显错误且问3=NO。不需要修改代码。

### 常见假阳性场景（提醒注意）

1. Reviewer 看错了上下文（diff 只显示几行）
2. Reviewer 的 P0 其实是代码风格偏好而非功能缺陷
3. Reviewer 标记 P0 只是为了提高关注度而非真有 severity
4. 问题在后续 commit 中已修复但 reviewer 未刷新
5. Reviewer 对代码意图的理解有偏差

---

## Step 3: 制定修复方案

对分类为 **✅确认真问题** 的 P0，制定修复方案：

```
### 修复方案

| 优先级 | P0 编号 | 问题简述 | 影响范围 | 修改文件 |
|--------|---------|---------|----------|----------|
| P0-#N  | ...     | ...     | ...      | ...      |
```

- 按优先级排序
- 每个问题标注影响范围和修改文件列表
- 列出潜在的副作用/影响

如果存在 **⚠️需要澄清** 的条目，先暂停并建议：
```
以下问题需要先与 reviewer 澄清后再修复：
- P0 #N: [简述]
  → 建议回复：[草拟的回复内容]

是否跳过澄清项继续修复确认真问题？[YES/NO]
```

---

## Step 4: 逐个修复确认真问题

对每个 ✅确认真问题，执行修复循环：

### 4.1 单个 P0 修复流程

1. **读代码** — Read 相关文件，理解上下文
2. **做最小改动** — Edit 修改，只改必要的行
3. **验证** — 运行相关测试或检查（如果有 test 命令或 lint 工具）
4. **报告** — 简短输出修复内容

### 4.2 修复原则

- 只修复 reviewer 标记的问题，不做额外「改进」
- 最小改动原则：能改一行不改三行
- 如果修复会引入新问题，停止并报告
- 每修完一个 P0 后输出进度

### 4.3 验证

修复后运行项目相关的检查：
```bash
# 检查项目可用的验证命令
# TypeScript: npx tsc --noEmit
# 通用：运行单测或 lint
```

---

## Step 5: 提交

### 5.1 查看变更

```bash
git status
git diff --stat
```

### 5.2 生成 commit message

格式：
```
fix: address P0 review issues from MR !<MR-IID>

- P0 #N: <问题简述>
- P0 #N: <问题简述>
```

### 5.3 提交（不自动 push）

```bash
git add <修改的文件>
git commit -m "<commit message>"
```

### 5.4 最终输出

```
=== /review-fix 完成报告 ===

MR: <MR-URL>
处理 P0 评论数: X
  ✅确认真问题: Y 个 → 已修复
  ⚠️需要澄清: Z 个 → 见建议回复
  ❌假阳性误判: W 个 → 无需处理

已修复:
- [commit hash] <commit message>

⚠️ 未自动 push。确认无误后请手动执行：
  git push origin <current-branch>
```

---

## 相关命令

| 命令 | 关系 |
|------|------|
| `/review` | 本地全面代码审查，/review-fix 只针对 reviewer 标记的 P0 |
| `/code-review` | 本地代码质量审查 |
| `/build-fix` | P0 修复后如果 build 失败，可衔接 /build-fix |
| `/ship-ready` | /review-fix 可作为 ship-ready 的前置步骤 |
