---
name: rfc-driven-dev
description: >
  RFC 驱动开发全流程编排器。从原始文档出发，经过调研→RFC生成→评审→审批→Plan→实现→Review→修复→归档→交付，
  11 阶段完整流水线。适用于处理 docs/rfcs/inbox 或 docs/rfcs/draft 中的 RFC 文档。
  触发词：rfc-driven-dev、RFC 驱动开发、处理 RFC、开始 RFC 流程、RFC 全流程。
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - Agent
  - TaskCreate
  - TaskUpdate
  - AskUserQuestion
  - EnterWorktree
---

# RFC-Driven-Dev: 日常开发全流程编排器

将原始需求文档 → 调研 → 隔离环境 → RFC → 审批 → Plan → 实现 → Review → 修复 → 归档 → 交付，一站式串联。

## 核心哲学

1. **调研先行**：不了解全貌不做决定，并行调研项目现状 + 行业最佳实践
2. **Gate 机制**：每个阶段都有明确的准入/准出条件，失败不继续
3. **JSON 事件输出**：阻塞时产出结构化 blocked 事件，而非模糊报错
4. **最多 N 次迭代**：评审和修复都有硬上限，防止无限循环

## 配置参数

以下参数通过项目根目录的 `docs/rfcs/README.md` 的 Series Configuration 表自动读取，
或通过 `CLAUDE.md` / `GEMINI.md` 中的 `rfc-driven-dev` 配置段覆盖。

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `package_manager` | `npm` | 包管理器（npm / pnpm / yarn / bun） |
| `review_score_threshold` | `8` | 评审通过分数阈值（1-10） |
| `max_review_rounds` | `3` | 最大评审迭代轮数 |
| `max_fix_rounds` | `2` | 单 Task 最大修复次数 |
| `target_branch` | `develop` | MR 目标分支 |

在 `CLAUDE.md` 中配置示例：

```markdown
## rfc-driven-dev config
- package_manager: npm
- review_score_threshold: 8
- target_branch: main
```

---

## 输入

用户提供：
- **文档路径**：可以是 `docs/rfcs/inbox/` 下的原始文档，或 `docs/rfcs/draft/` 下已有的 RFC
- 或直接说"处理 RFC COACH-005"（自动定位文件）

---

## 全局 blocked 协议

任何阶段失败都输出：

```json
{"event":"blocked","stage":"<stage_name>","reason":"<具体原因>","details":"<额外信息>"}
```

并在当前阶段停止，不进入下一阶段。

---

## Stage 1: RESEARCH（调研）

### 1.1 读取文档

用 Read 工具读取用户提供的文档，提取关键信息：主题、领域、涉及的技术栈。

### 1.2 并行调研

使用 Agent 工具同时派发以下调研任务（至少 2 个 agent 并行）：

**Agent 1 — 项目现状调研：**
```
你是项目现状调研专家。请调研当前项目中与以下主题相关的现状：
主题：[从文档提取]
- 相关代码目录结构
- 已有实现和配置
- 存在的问题和瓶颈
- 相关 RFC 和 ADR
请给出结构化报告，不要执行任何代码修改。
```

**Agent 2 — 行业调研：**
```
你是行业调研专家。请调研以下主题的行业最佳实践：
主题：[从文档提取]
- Top 3 项目/公司的做法
- 最新技术选型（2026）
- 工具/框架对比（表格形式）
- 社区共识和趋势
请给出结构化报告，不要执行任何代码修改。
```

### 1.3 汇总与判定

读取两份调研报告，给出一段 200 字以内的"全貌理解"摘要。如果文档中涉及的技术栈在当前项目中不存在或有重大冲突，产出 blocked 事件。

### Gate

- ✅ 通过：两份报告都有实质性内容 + 全貌理解摘要已产出
- ❌ 阻塞：文档无法读取、主题无法识别、技术栈严重冲突

---

## Stage 2: WORKTREE（创建隔离工作树）

### 2.1 确定分支参数

根据 Stage 1 调研的主题，生成以下参数：

| 参数 | 来源 | 示例 |
|------|------|------|
| `{PROJECT}` | git 仓库根目录名 | `coach-react` |
| `{BRANCH_TYPE}` | 根据工作性质自动选择（见下表） | `feat`、`fix`、`refactor`、`perf`、`docs` |
| `{BRANCH_SHORTNAME}` | 从 RFC 主题生成简短英文标识 | `audio-pipeline`、`auth-refactor` |

**分支命名规范**：`(feat|fix|refactor|docs|test|perf|ci|chore|hotfix|release|main)/*`

分支类型映射：

| 工作性质 | BRANCH_TYPE |
|---------|------------|
| 新功能 | `feat` |
| Bug 修复 | `fix` |
| 紧急修复（线上故障） | `hotfix` |
| 重构 | `refactor` |
| 性能优化 | `perf` |
| 文档变更 | `docs` |
| 测试相关 | `test` |
| CI/CD 配置 | `ci` |
| 杂项（构建、依赖等） | `chore` |
| 发布分支 | `release` |
| 主干 | `main` |

### 2.2 创建 Worktree

```bash
git worktree add ../{PROJECT}-{BRANCH_SHORTNAME} -b {BRANCH_TYPE}/{BRANCH_SHORTNAME} {TARGET_BRANCH}
```

例如（新功能）：
```bash
git worktree add ../coach-react-audio-pipeline -b feat/audio-pipeline develop
```

例如（紧急修复）：
```bash
git worktree add ../coach-react-auth-fix -b hotfix/login-crash develop
```

### 2.3 通过 EnterWorktree 切换会话工作目录

创建成功后，调用 `EnterWorktree` 工具，传入 `path` 参数指向刚创建的 worktree：

```
path: "../{PROJECT}-{BRANCH_SHORTNAME}"
```

`EnterWorktree` 会将**会话的工作目录**切换到 worktree（后续 Read/Edit/Write/Bash 均基于新目录），无需手动 `cd`。

然后安装依赖：

```bash
{PACKAGE_MANAGER} install
```

`{PACKAGE_MANAGER}` 从配置的 `package_manager` 参数读取。

### 2.4 注意事项

- 会话期间所有文件操作（Read/Edit/Write）自动在 worktree 中执行
- 流程结束后（Stage 12 DELIVER），调用 `ExitWorktree` 退出并可选择清理 worktree

### Gate

- ✅ 通过：worktree 创建成功，EnterWorktree 切换成功，`git branch` 显示正确分支，`{PACKAGE_MANAGER} install` 成功
- ❌ 阻塞：worktree 已存在同名目录、分支名冲突、目标分支不存在、EnterWorktree 切换失败、install 失败

---

## Stage 3: RFC GENERATION（RFC 生成/定位）

### 3.1 判断文档来源

检查用户提供的文档路径：

- **在 `docs/rfcs/inbox/` 中** → 进入 3.2，调用 rfc-author 生成 RFC
- **在 `docs/rfcs/draft/` 中** → 跳过 3.2，直接进入 Stage 4

### 3.2 调用 rfc-author 生成 RFC

使用 Skill 工具调用 `rfc-author` skill，传入 inbox 中文档的主题。

自行完成以下步骤（遵循 rfc-author skill 的规范）：

1. 读取 inbox 文档，提取核心需求
2. 读取 `docs/rfcs/README.md` 确定系列前缀和下一个可用序号
3. 按 RFC 模板撰写完整 RFC，写入 `docs/rfcs/draft/{SERIES}-{NNN}-{slug}.md`
4. 必填章节：Goals、Background、Design、Implementation、Acceptance Criteria、Notes

### Gate

- ✅ 通过：RFC 文件存在于 `docs/rfcs/draft/`，包含全部必填章节，无 TBD/TODO 占位符
- ❌ 阻塞：RFC 生成失败、必填章节缺失

---

## Stage 4: RFC REVIEW（RFC 评审）

### 4.1 召集 3 个评审 Agent

使用 Agent 工具并行派发 3 位评审专家，评审 `docs/rfcs/draft/` 中的目标 RFC：

**Agent 1 — 架构评审：**
```
你是架构评审专家。请评审以下 RFC：
文件：[rfc_path]

审查维度：
1. 方案架构是否合理？有无更优解？
2. 技术选型是否恰当？有无过时或过度复杂？
3. 边界是否清晰（Goals/Non-Goals）？

输出格式：按 1-10 分给总体评分，然后按 Critical/High/Medium/Low 列出问题。
```

**Agent 2 — 实现可行性评审：**
```
你是实现可行性评审专家。请评审以下 RFC：
文件：[rfc_path]

审查维度：
1. 实现任务是否具体可执行？
2. 验收标准是否可量化/可测试？
3. 风险识别是否完整？回滚方案是否可行？

输出格式：按 1-10 分给总体评分，然后按 Critical/High/Medium/Low 列出问题。
```

**Agent 3 — 内容完整性评审：**
```
你是内容完整性评审专家。请评审以下 RFC：
文件：[rfc_path]

审查维度：
1. 背景动机是否充分？是否解释了"为什么现在做"？
2. 备选方案是否真实考虑过？驳回理由是否合理？
3. 是否有遗漏的边界条件或场景？

输出格式：按 1-10 分给总体评分，然后按 Critical/High/Medium/Low 列出问题。
```

### 4.2 汇总与迭代

从评审结果中汇总问题，按 Critical > High > Medium > Low 排序。

**迭代规则：**
- 有 Critical 或 High 问题 → 修复 RFC → 重新评审（最多 `{MAX_REVIEW_ROUNDS}` 轮）
- 评分均 ≥ `{REVIEW_SCORE_THRESHOLD}` 分且无 Critical/High 问题 → 通过
- `{MAX_REVIEW_ROUNDS}` 轮迭代后仍有评分 < `{REVIEW_SCORE_THRESHOLD}` 或存在 Critical 问题 → 产出 blocked 事件

### Gate

- ✅ 通过：3 位评审评分均 ≥ `{REVIEW_SCORE_THRESHOLD}` 分
- ❌ 阻塞：超过 `{MAX_REVIEW_ROUNDS}` 轮迭代仍未达标

---

## Stage 5: RFC APPROVAL（RFC 审批）

### 5.1 调用 mgv-rfc-approve

使用 Skill 工具调用 `mgv-rfc-approve` skill，传入 RFC ID。

该 skill 会：
1. 定位 `docs/rfcs/draft/` 中的 RFC
2. 检查 5 维度完整性（Goals/Background/Design/Implementation/Acceptance Criteria）
3. 审批通过后 `git mv` 到 `docs/rfcs/approved/`，更新 frontmatter 和 README

### 5.2 处理审批结果

- 审批通过 → 进入 Stage 6
- 审批阻塞 → 检查缺失维度，修复后重新审批（最多 2 次）

### Gate

- ✅ 通过：RFC 已移入 `docs/rfcs/approved/`，frontmatter `status: Approved`
- ❌ 阻塞：2 次修复后审批仍未通过

---

## Stage 6: EXTRACTION（提取验收标准）

### 6.1 读取审批通过的 RFC

使用 Read 工具读取 `docs/rfcs/approved/` 中的 RFC 文件。

### 6.2 提取关键信息

从 RFC 中提取：
- **Goals**（Goals 章节）
- **Background**（Background / Motivation 章节）
- **Design**（Design 章节）
- **Acceptance Criteria**（Acceptance Criteria 章节）
- **Implementation**（Implementation 章节）

### 6.3 判定是否需要 Stage 7

判断标准：

| 情形 | 是否进入 Stage 7 |
|------|-----------------|
| 验收标准完整且可执行，实现任务具象 | ✅ 进入 Stage 7 |
| 验收标准为纯文档/流程变更（无代码） | ❌ 跳到 Stage 11: ARCHIVE（直接归档） |
| 验收标准为主观描述（如"代码更清晰"）无法量化 | ❌ blocked：验收标准不可执行 |
| RFC 标记状态为 Superseded/Deferred | ❌ blocked：RFC 不适用 |

总结判定理由（一句话）。

---

## Stage 7: PLAN（生成实现计划）

### 7.1 调用 writing-plans

使用 Skill 工具调用 `superpowers:writing-plans`。

核心要求：
- Plan 写入 `docs/superpowers/plans/YYYY-MM-DD-{topic}.md`
- 每步 2-5 分钟粒度
- 包含 Goal、Architecture、Tech Stack header
- 每个 Task 有精确文件路径和 5 步 checkbox（写测试→跑失败→实现→跑通过→commit）
- 禁止 TBD/TODO 占位符

### 7.2 Self-Review

完成 Plan 后自检：
1. 验收标准覆盖：每项验收标准都有对应 Task
2. 占位符扫描：无 TBD/TODO
3. 文件路径精确性：所有 Create/Modify/Test 路径存在或合理

### Gate

- ✅ 通过：Plan 文件存在且自检通过
- ❌ 阻塞：自检失败且无法修复

---

## Stage 8: EXECUTE（子任务实现）

### 8.1 调用 subagent-driven-development

使用 Skill 工具调用 `superpowers:subagent-driven-development`。

遵循该 skill 的核心原则：
- 每个 Task 派 fresh subagent（隔离上下文）
- 两阶段 review：spec compliance → code quality
- 连续执行，不询问"是否继续"
- 单 task 最多 `{MAX_FIX_ROUNDS}` 次修复（超过则 blocked）

### 8.2 监控执行

每个 Task 完成后检查：
- `{PACKAGE_MANAGER} check` 是否通过
- Spec reviewer 是否确认符合 spec
- Code quality reviewer 是否通过

### Gate

- ✅ 通过：所有 Task 完成，`{PACKAGE_MANAGER} check` 全绿，tests 全绿
- ❌ 阻塞：某个 Task `{MAX_FIX_ROUNDS}` 次修复后仍不通过

---

## Stage 9: REVIEW（多专家并行审查）

### 9.1 调用 requesting-code-review

使用 Skill 工具调用 `superpowers:requesting-code-review`。

审查范围：`HEAD` vs `origin/{TARGET_BRANCH}` 的完整 diff。

### 9.2 Adversarial Verify（P0/P1 发现时）

如果审查发现 P0 或 P1 级别问题，对每个问题进行 adversarial verify：

对每个 P0/P1：
1. 尝试构造反例证明修复方案不充分
2. 如果修复方案确实不够 → 补充修复
3. 如果反例验证通过 → 问题确认并记录

以 JSON 输出：
```json
{"event":"review_finding","severity":"P0|P1","issue":"...","adversarial_result":"confirmed|fixed|mitigated","action":"..."}
```

### Gate

- ✅ 通过：P0 清零（或已确认并记录），P1 已处理
- ❌ 阻塞：P0 未清零

---

## Stage 10: FIX（修复 P0/P1）

### 10.1 按文件分组修复

按文件分组所有 P0/P1 问题，每组一次修复。

**修复约束：**
- 每组只修一个文件
- 每文件只修它自己的 P0/P1
- 修复后立即 `{PACKAGE_MANAGER} check` 验证
- 不引入新文件级别的修改

### 10.2 Gate 验证

修复完成后：
1. `{PACKAGE_MANAGER} check` 必须全绿
2. 所有 P0 必须清零
3. 所有 P1 必须有处理结论（fixed / known-issue / will-fix-in-followup）

### Gate

- ✅ 通过：P0 清零 + `{PACKAGE_MANAGER} check` 全绿
- ❌ 阻塞：P0 未清零或 check 不通过

---

## Stage 11: ARCHIVE（RFC 归档）

### 11.1 归档 RFC

将审批通过的 RFC 从 `approved/` 移入 `completed/`：

```bash
git mv docs/rfcs/approved/{rfc_file} docs/rfcs/completed/{rfc_file}
# 更新 README 索引
# 更新 frontmatter: Approved → Completed
git add docs/rfcs/completed/ docs/rfcs/README.md
git commit -m "docs: complete {rfc_id} - archive to completed/"
git push
```

输出成功事件：

```json
{"event":"archived","rfc_id":"...","archived_to":"docs/rfcs/completed/..."}
```

### Gate

- ✅ 通过：RFC 已移入 `docs/rfcs/completed/`，frontmatter `status: Completed`
- ❌ 阻塞：git mv 失败、push 失败

---

## Stage 12: DELIVER（交付）

### 12.1 门禁验证

```bash
{PACKAGE_MANAGER} check
```

不通过 → blocked。

### 12.2 WIP Squash

保持干净线性历史：

```bash
# 查看 commit 历史
git log --oneline origin/{TARGET_BRANCH}..HEAD

# 非 WIP 提交保留
# WIP 提交（含 "WIP" / "wip" / "tmp" / "fixup" 前缀或关键字）自动 fixup squash
```

原则：每个 commit 应该是 Bisectable 的独立单元。

### 12.3 Commit & Push

使用 Skill 工具调用 `commit` skill（如存在），或手动执行：

```bash
git add -A
git commit -m "<type>: <description>"
git push -u origin HEAD
```

### 12.4 创建 MR

使用 Skill 工具调用 `glab-mr` skill，合入 `{TARGET_BRANCH}`。

### Gate

- ✅ 通过：push 成功 + MR 已创建
- ❌ 阻塞：push 失败、MR 创建失败、或 check 不通过

---

## 阶段流转图

```
RESEARCH ──→ WORKTREE ──→ RFC_GENERATION ──→ RFC_REVIEW ──→ RFC_APPROVAL
                                                    │
                                                    ▼
                                             EXTRACTION
                                                    │
                                            ┌───────┴───────┐
                                            │ 需要实现？     │
                                            └───────┬───────┘
                                            yes │         │ no/不可执行
                                                ▼         ▼
                                             PLAN     BLOCKED/归档
                                                │
                                                ▼
                                            EXECUTE
                                                │
                                                ▼
                                            REVIEW
                                                │
                                                ▼
                                               FIX
                                                │
                                                ▼
                                            ARCHIVE
                                                │
                                                ▼
                                           DELIVER
                                                │
                                                ▼
                                          COMPLETED
```

---

## 使用方式

```
/rfc-driven-dev docs/rfcs/inbox/xxx.md
```

或指定已有 draft RFC：

```
/rfc-driven-dev COACH-005
```

或自然语言触发：
- "RFC 驱动开发"
- "处理 RFC"
- "开始 RFC 流程"
- "RFC 全流程"
