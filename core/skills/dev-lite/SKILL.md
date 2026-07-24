---
name: dev-lite
description: >
  轻量开发工作流编排器。9 阶段闭环：BRAINSTORM → BRANCH → RESEARCH → PLAN → EXECUTE → REVIEW → FIX → SHIP → DEPLOY。
  适用于 bugfix、小功能、重构等常规简单需求。通过调用现有 skill/command（superpowers:brainstorming、
  /dev-branch、superpowers:writing-plans、superpowers:subagent-driven-development、
  superpowers:requesting-code-review、/ship、/sync-push）实现，保留调研+多专家评审 panel+TDD 核心抓手，
  砍掉 worktree 隔离、RFC 文档生命周期、MR 自动化等重型环节。SHIP 只到 push 为止，
  不自动合主分支；DEPLOY 阶段生成本次上线步骤并询问是否合 test 分支做人工验证。
  触发词：dev-lite、轻量开发、快速开发、小需求、快速修复、bugfix 流程。
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
  - Skill
---

# Dev-Lite：轻量开发工作流

常规简单需求（bugfix / 小功能 / 重构）的 9 阶段闭环流水线。**每个 Stage 调用现成 skill/command**，不重复造轮子（同 rfc-driven-dev 的做法）。相比 rfc-driven-dev 的 12 阶段重型流程，砍掉文档生命周期、worktree 隔离、MR 自动化，但**保留调研、多专家评审 panel、TDD 三个核心抓手**。

## 工具链映射（核心设计）

| Stage | 调用的 skill/command | 凭什么复用 |
|-------|---------------------|-----------|
| 1 BRAINSTORM | `superpowers:brainstorming` | 该 skill 已实现一问一答的需求澄清方法论 |
| 2 BRANCH | `/dev-branch` | 已实现"拉主分支 + 创建 feat/fix 分支 + 日期后缀"，**替代 rfc-driven-dev 的 worktree** |
| 3 RESEARCH | Agent 工具并行派 2 个 | 同 rfc-driven-dev Stage 1 |
| 4 PLAN | `superpowers:writing-plans`（**产出 specs 文档到 `docs/superpowers/plans/`**） | 已实现 plan 生成 + 5 步 checkbox 规范 |
| 5 EXECUTE | `superpowers:subagent-driven-development` + `superpowers:test-driven-development`（bugfix） | 已实现 subagent 隔离 + TDD 流程 |
| 6 REVIEW | `superpowers:requesting-code-review`（**多专家 panel**，3+ agent 并行） | 已实现多专家并行评审 + adversarial verify |
| 7 FIX | 按文件分组修 P0/P1 | 同 rfc-driven-dev Stage 10 |
| 8 SHIP | `/ship`（全量验证 + commit + push，**不创 MR**） | 已实现全量验证 + 提交 + 推送 |
| 9 DEPLOY | 生成上线步骤清单 + `AskUserQuestion` 询问是否 `/sync-push test` | 闭环到人工验证 |

## 核心哲学

1. **需求先聊清**：BRAINSTORM 前置，一问一答厘清边界，禁止"边做边猜需求"
2. **调研不瞎猜**：并行派 agent 调研代码现状 + 历史类似问题，禁止"拍脑袋实现"
3. **评审无盲区**：多专家并行审查，禁止"写完就提交"
4. **bug 必复现**：bugfix 强制 TDD（先写复现测试再修），禁止"修了但不知道修对没"
5. **Gate 软门禁**：每阶段有准出条件，但阈值宽松（≥7 分通过，不追求完美）

## 适用判定

| 场景 | 用 dev-lite | 用 rfc-driven-dev |
|------|------------|------------------|
| Bug 修复（含 hotfix） | ✅ | ❌ 太重 |
| 小功能（1-3 个文件） | ✅ | ❌ 太重 |
| 重构（无行为变更） | ✅ | ❌ 太重 |
| 跨模块大型功能 | ❌ 该用 RFC | ✅ |
| 架构变更 | ❌ 该用 RFC | ✅ |
| 涉及多团队协作 | ❌ 该用 RFC | ✅ |

## 配置参数

通过 `CLAUDE.md` 的 `dev-lite` 配置段覆盖：

| 参数 | 默认值 | 说明 |
|------|--------|------|
| `review_score_threshold` | `7` | 评审通过阈值（1-10） |
| `max_fix_rounds` | `1` | 单 Task 最大修复次数 |
| `max_brainstorm_rounds` | `5` | BRAINSTORM 最大提问轮数 |
| `auto_push` | `true` | EXECUTE 完自动 push |
| `require_tdd_for_bugfix` | `true` | bugfix 强制 TDD |
| `target_branch` | `develop` | 默认分支 |

```markdown
## dev-lite config
- review_score_threshold: 7
- max_fix_rounds: 1
- auto_push: true
- require_tdd_for_bugfix: true
```

## 包管理器自动检测

同 rfc-driven-dev：pnpm 优先 + npm 兜底，首次检测后复用，记为 `{PM}`。

---

## 输入

用户提出需求，可以是：
- 自然语言描述（"修复登录页在 Safari 崩溃"）
- 一个 issue 链接或截图
- 一段报错堆栈

---

## 全局 blocked 协议

任何阶段失败都输出：

```json
{"event":"blocked","stage":"<stage_name>","reason":"<具体原因>","details":"<额外信息>"}
```

并在当前阶段停止。

---

## Stage 1: BRAINSTORM（需求澄清）

> 🚨 **MANDATORY**：禁止跳过本阶段直接进入 RESEARCH。需求没聊清就开干是最大的浪费。
>
> 🚨 **HARD CONSTRAINT**：本阶段**必须实际调用 Skill 工具触发 `superpowers:brainstorming`**。**无论需求看起来多清楚**，都不允许跳过 Skill 工具调用直接写摘要——这是 dev-lite 最常被走捷径跳过的环节，必须堵死。

### 1.1 调用 superpowers:brainstorming（硬性前置）

**第一步（不可省略）：** 使用 Skill 工具调用 `superpowers:brainstorming`。

```
Skill(skill: "superpowers:brainstorming")
```

调用成功后，对话中会出现类似 `● Skill(superpowers:brainstorming)` `⎿ Successfully loaded skill` 的证据。

> **禁止的捷径**：
> - ❌ 直接基于用户原始消息产出"需求理解摘要"（即使需求清楚）
> - ❌ 把"用户需求已经清楚"当作跳过 Skill 调用的理由
> - ❌ 在脑内模拟一问一答然后直接出摘要
>
> **合法的简化**（仅此一项）：
> - ✅ 需求确实清楚时，brainstorming 可缩到 1 轮（问 1 个确认性问题 + 用户确认），但 **Skill 工具调用不可省**

**Skill 加载后**，将该 skill 的方法论完整应用：
- 一问一答，不一次问超过 2 个问题
- 聚焦需求边界、验收标准、Non-Goals、约束
- 给选项而非开放问题
- **最多 `{MAX_BRAINSTORM_ROUNDS}` 轮**（默认 5），避免小需求陷入过度讨论

### 1.2 汇总确认（必须先通过 1.1 验证）

> 🚨 **产出摘要前的硬验证**：必须确认上一轮已实际调用 Skill 工具，对话历史中有 `Skill(superpowers:brainstorming)` 的证据。若未调用，**立即回退到 1.1 执行**，不可带着跳过的心态写摘要。

brainstorming 结束后，输出 100 字以内的「需求理解摘要」：

```
📌 需求理解
- 类型：bugfix / feature / refactor / hotfix
- 目标：<一句话>
- 验收标准：<可量化的 1-3 条>
- Non-Goals：<明确不做的>
- 涉及范围：<预估文件数>
```

用户确认后进入 Stage 2。

### Gate

- ✅ 通过：① 对话中存在 `Skill(superpowers:brainstorming)` 调用证据 + ② 用户确认需求理解摘要
- ❌ 阻塞：未调用 Skill 工具就产出摘要（**视为流程违规，必须回退**）、`{MAX_BRAINSTORM_ROUNDS}` 轮后仍有歧义

---

## Stage 2: BRANCH（创建分支，替代 worktree）

> 设计哲学：rfc-driven-dev 用 worktree 隔离，dev-lite 直接用 `/dev-branch` 创建常规分支，更轻量。
>
> 🚨 **不再每次都问用户**：dev-lite 基于上下文智能分流，符合 fast-path 条件时**自动建分支**，避免把"能不能建分支"这种低风险决策频繁抛给用户。

### 2.1 智能分流：检测当前状态

先跑三条命令收集事实（**禁止跳过**）：

```bash
git branch --show-current        # 当前分支
git status --porcelain           # 未提交变更
git rev-parse --abbrev-ref HEAD  # 兜底确认
```

根据结果走以下三条路径之一：

#### 路径 A：已在 feature 分支上（current ≠ master/main/develop）

**无需建分支**，直接跳到 Stage 3。输出：

```
✓ 已在 feature 分支：<current>，跳过 BRANCH 阶段
```

#### 路径 B：在 master/main/develop 上 + 工作区有未提交改动 + 改动文件命中需求摘要的"涉及范围"

**走 fast-path，跳过用户确认**。这是常见的"开发者已经在 master 上铺了一些铺垫代码"场景。

**B.1 命中检测**（dev-lite 自行判断，不问用户）：

1. `git status --porcelain` 输出非空
2. 列出变更文件，和 Stage 1 摘要的「涉及范围」字段对比
3. **至少 1 个变更文件出现在摘要涉及范围内** -> 命中

**B.2 执行 fast-path**：

```bash
# 从当前 HEAD 直接建分支，把未提交改动带过去
git switch -c <type>/<slug>-<YYYYMMDD>
```

**禁止做的事**：
- ❌ `git switch main` + `git pull`（会和未提交改动冲突）
- ❌ 展示分支名让用户确认（fast-path 定义就是不再问）
- ❌ `git stash` + 切主分支 + pull + 切回 + pop（绕远路）

**B.3 分支命名**：dev-lite 自行按 `/dev-branch` 规则生成（类型从摘要语义判断 + slug + 日期），不调用 `/dev-branch` 指令本身（避免触发其 pull+确认逻辑）。

**B.4 输出证据**：

```
✓ Fast-path 建分支
  原分支：<base>
  新分支：<type>/<slug>-<YYYYMMDD>
  带过未提交改动：<N> 个文件
  - <file1>
  - <file2>
  ...
  命中原因：变更文件 <fileX> 出现在需求摘要涉及范围内
```

#### 路径 C：在 master/main/develop 上 + 工作区干净（或变更和需求无关）

**调用 `/dev-branch` 走标准流程**（含用户确认）：

使用 Skill 工具调用 `/dev-branch`，传入需求摘要中的核心描述。该指令会自动：

1. 从摘要语义判断分支类型（feat/fix/refactor/hotfix/...）
2. 生成简短英文 slug
3. 拼接日期后缀：`<type>/<slug>-<YYYYMMDD>`
4. 拉取最新主分支代码（`git pull origin main`）
5. 展示分支名给用户确认后创建

### 2.2 分支类型分流（影响后续 Stage）

| 需求类型 | 分支前缀 | 后续 EXECUTE 策略 | 后续 REVIEW 策略 |
|---------|---------|-----------------|-----------------|
| `bugfix` | `fix/` | 强制 TDD | + 回归测试审查 |
| `feature` | `feat/` | 实现+单测 | 标准 + 性能 |
| `refactor` | `refactor/` | 保持测试全绿 | + 行为等价性审查 |
| `hotfix` | `hotfix/` | 快速修复 | 跳过 REVIEW 直接 SHIP |

### Gate

- ✅ 通过：分支已创建并切换（`git branch --show-current` 输出新分支名）或已在 feature 分支
- ❌ 阻塞：路径 B 的 `git switch -c` 失败、路径 C 的 `/dev-branch` 执行失败

---

## Stage 3: RESEARCH（并行调研）

### 2.1 派发并行 agent

使用 Agent 工具同时派发 2 个调研 agent：

**Agent 1 — 代码现状调研：**
```
你是代码现状调研专家。请调研以下需求涉及的代码现状：
需求：[从 BRAINSTORM 摘要提取]
- 相关文件路径（精确到函数/组件）
- 当前的实现逻辑
- 上下游调用关系
- 相关近期 commit（git log 最近 10 条）
请给出结构化报告，不要执行任何代码修改。
```

**Agent 2 — 历史类似问题调研：**
```
你是历史问题调研专家。请调研以下需求是否有历史可参考：
需求：[从 BRAINSTORM 摘要提取]
- git log/blame 是否曾经修过类似问题（是否反复修复？）
- 项目内是否有可复用的工具/组件
- 是否有相关测试用例
请给出结构化报告，不要执行任何代码修改。
```

### 2.2 汇总

读取两份报告，产出：
- 200 字以内的「现状全貌」摘要
- 3 条候选方案（按推荐度排序，每条带优劣对比）

### Gate

- ✅ 通过：两份报告有实质内容 + 3 条候选方案已产出
- ❌ 阻塞：调研 agent 返回空、相关代码完全找不到

---

## Stage 4: PLAN（生成 specs 文档）

> 🚨 **MANDATORY**：本阶段**必须实际调用 Skill 工具触发 `superpowers:writing-plans`**，产出真实的 plan/specs 文档到 `docs/superpowers/plans/`。**不允许 inline 模式**--plan 文档是后续 EXECUTE/REVIEW 的 spec 对照基准，是抓手不是负担。

### 4.1 调用 superpowers:writing-plans（硬性前置）

> 🚨 **HARD CONSTRAINT**：无论需求多简单、Task 看起来多清晰，都必须先调 Skill 工具。**禁止**基于 RESEARCH 汇总直接在对话里列 Task 清单。

**第一步（不可省略）：** 使用 Skill 工具调用 `superpowers:writing-plans`。

```
Skill(skill: "superpowers:writing-plans")
```

调用成功后，对话中会出现 `● Skill(superpowers:writing-plans)` `⎿ Successfully loaded skill` 的证据。

> **禁止的捷径**：
> - ❌ 基于 RESEARCH 汇总直接在对话里列 Task 1/2/3 然后问"OK 的话我直接开写"
> - ❌ 把"需求简单"当作跳过 Skill 调用的理由
> - ❌ 在脑内套用 writing-plans 方法论但不实际触发 Skill 工具
> - ❌ 调了 Skill 但不写文件（inline 模式已废弃）

**Skill 加载后**，按其规范产出完整 plan 文档：

- **文件路径**：`docs/superpowers/plans/YYYY-MM-DD-{topic-slug}.md`
- **必含 header**：Goal、Architecture、Tech Stack
- **Task 粒度**：每步 2-5 分钟，精确到文件路径
- **每个 Task 含 5 步 checkbox**：写测试 -> 跑失败 -> 实现 -> 跑通过 -> commit
- **禁止**：TBD/TODO 占位符

### 4.2 选择候选方案

从 Stage 3 的 3 条候选方案中选 1 条，说明选择理由（1 句话）。

### 4.3 Task 清单写入 plan 文档

按 `superpowers:writing-plans` 规范，把 Task 清单写入 plan 文件的 Task 章节。每个 Task 必须包含：精确文件路径（Create/Modify/Test）+ 5 步 checkbox（`写测试 -> 跑失败 -> 实现 -> 跑通过 -> commit`）+ 预计影响文件数。

**按需求类型分流的 Task 1 强制要求：**

| 类型 | Task 1 必须是 |
|------|-------------|
| bugfix | 「写复现测试」（先让它失败） |
| feature | 「写空测试骨架 + 接口签名」 |
| refactor | 「跑一遍现有测试确认全绿（基线）」 |

### 4.4 产出后硬验证

```bash
ls docs/superpowers/plans/YYYY-MM-DD-*.md
```

**硬验证条件（全部满足才通过，否则 blocked）：**
- ✅ plan 文件已创建在 `docs/superpowers/plans/`
- ✅ 文件包含 Goal / Architecture / Tech Stack header
- ✅ 每个 Task 有精确文件路径 + 5 步 checkbox
- ✅ 无 TBD/TODO 占位符
- ✅ Task 1 符合需求类型分流要求

**向用户展示 plan 摘要**（不是问"OK 的话我直接开写"，而是展示文档位置+核心 Task+涉及文件，让用户决定是否进 EXECUTE）：

```
📋 Plan 已生成

   📄 文档：docs/superpowers/plans/2026-07-24-<topic>.md
   🎯 Goal：<一句话>
   🏗 Architecture：<选中的候选方案 + 理由>
   🛠 Tech Stack：<涉及的技术栈>

   Task 清单（共 N 个）：
   [Task 1] <描述> - <文件路径>
   [Task 2] <描述> - <文件路径>
   ...

   下一步：进入 Stage 5 EXECUTE（调 superpowers:subagent-driven-development 按 plan 执行）
```

### Gate

- ✅ 通过：① 对话中存在 `Skill(superpowers:writing-plans)` 调用证据 + ② plan 文件已创建 + ③ 硬验证全通过
- ❌ 阻塞：未调 Skill 工具就列 Task（**视为流程违规，必须回退**）、plan 文件未创建、必填章节缺失

---

## Stage 5: EXECUTE（实现）

### 5.1 调用 superpowers:subagent-driven-development

使用 Skill 工具调用 `superpowers:subagent-driven-development`：
- 每个 Task 派 fresh subagent（隔离上下文）
- 两阶段 review：spec compliance → code quality
- 连续执行，不询问"是否继续"
- 单 Task 最多 `{MAX_FIX_ROUNDS}` 次修复

### 5.2 bugfix 场景追加调用 superpowers:test-driven-development

若需求类型为 `bugfix` 且 `require_tdd_for_bugfix: true`，在 subagent 执行 Task 1 前强制：
- 调用 `superpowers:test-driven-development`
- Task 1（复现测试）必须先跑测试看它失败（贴出失败输出作为证据）
- 修复 Task 完成后，复现测试必须转绿（贴出通过输出作为证据）
- 修复后复现测试仍失败 → 回到 Stage 4 PLAN 重选方案

### 5.3 每个 Task 完成后

```bash
{PM} run check
```

### Gate

- ✅ 通过：所有 Task 完成 + `{PM} run check` 全绿
- ❌ 阻塞：某 Task `{MAX_FIX_ROUNDS}` 次后仍失败

---

## Stage 6: REVIEW（多专家并行 panel 审查）

> 🚨 **MANDATORY**：必须是**多专家 panel**，禁止单一 reviewer。最少 3 个 agent 并行评审，分歧时召集第 4 个仲裁 agent。

### 6.1 确定审查范围

```bash
git diff origin/{TARGET_BRANCH}...HEAD --stat
```

审查目标：当前分支相对 target 分支的完整 diff。

### 6.2 调用 superpowers:requesting-code-review（作为方法论底座）

使用 Skill 工具调用 `superpowers:requesting-code-review`，获取其多专家评审方法论和 adversarial verify 协议。

> 该 skill 本身已是多专家模式，但 dev-lite 在此基础上**显式扩展 panel 成员**，按需求类型追加专属 reviewer，确保覆盖度。

### 6.3 派发并行评审 panel（最少 3 个 agent）

使用 Agent 工具并行派发以下评审专家。**所有 agent 同时派发，不可顺序执行**：

**Reviewer 1 — 代码质量 + Spec 符合度（必选）：**
```
你是代码质量审查专家。请审查以下变更：
分支：<branch>，diff 范围：origin/{TARGET_BRANCH}..HEAD

审查维度：
1. 实现是否符合 BRAINSTORM 阶段确认的需求摘要（逐条对照验收标准）
2. 代码是否可读、无冗余、无过度工程
3. 函数长度（<50 行）、文件长度（<400 行）、嵌套深度（<4 层）
4. 错误处理是否完整（边界、null、空数组、并发）
5. 命名规范、目录结构合理性

输出格式：
- 总分：1-10
- 问题列表：按 Critical / High / Medium / Low 分级
- 每个问题：文件:行号 + 描述 + 修复建议
```

**Reviewer 2 — 安全 + 边界（必选）：**
```
你是安全审查专家。请审查以下变更：
分支：<branch>，diff 范围：origin/{TARGET_BRANCH}..HEAD

审查维度（OWASP Top 10 视角）：
1. 注入风险（SQL/Command/XSS）
2. 认证授权漏洞、越权访问
3. 敏感信息泄漏（密钥、token、PII 日志）
4. 输入验证是否在系统边界处完成
5. CSRF、SSRF、路径穿越
6. 密码学误用

输出格式：
- 总分：1-10
- 问题列表：按 Critical / High / Medium / Low 分级
```

**Reviewer 3 — 按需求类型触发（必选其一）：**

| 需求类型 | Reviewer 3 审查重点 |
|---------|------------------|
| `bugfix` | **回归测试覆盖度**：原 bug 场景是否覆盖、相邻/边界场景是否考虑、是否会引入新 bug |
| `feature` | **性能 + 可维护性**：N+1 查询、复杂度、内存占用、命名表达力、未来扩展成本 |
| `refactor` | **行为等价性**：输入输出是否完全一致、对外契约未变更、性能未退化 |
| `hotfix` | （跳过本阶段，直接 SHIP） |

Reviewer 3 prompt 模板：
```
你是<{TYPE}>专项审查专家。请审查以下变更：
分支：<branch>，diff 范围：origin/{TARGET_BRANCH}..HEAD

审查重点：
<{按上表展开}>

输出格式：
- 总分：1-10
- 问题列表：按 Critical / High / Medium / Low 分级
```

### 6.4 Adversarial Verify（P0/P1 发现时）

对每个 Critical/High 问题，尝试构造反例证明修复方案不充分：
1. 构造反例输入/场景
2. 若反例成立 → 修复确实不够 → 标记 confirmed
3. 若反例被驳倒 → 问题降级

```json
{"event":"review_finding","severity":"P0|P1","issue":"...","adversarial_result":"confirmed|fixed|mitigated","action":"..."}
```

### 6.5 分歧仲裁（评分争议时）

若任两 Reviewer 评分差 ≥3 分，召集 **Reviewer 4（仲裁 agent）**：
```
你是仲裁专家。以下三位专家对同一变更有评分分歧：
R1: <score> — <核心理由>
R2: <score> — <核心理由>
R3: <score> — <核心理由>
请独立审查后给出最终评分和处置建议（采纳哪一方/折中/驳回）。
```

### 6.6 汇总 Gate

- ✅ 通过：**所有** Reviewer 评分 ≥ `{REVIEW_SCORE_THRESHOLD}` + 无 Critical
- ❌ 阻塞：有 Critical 或任一 Reviewer < 阈值 → 进入 Stage 7 FIX

> **禁止**：用单一 reviewer 结论代替 panel；用平均分掩盖低分 reviewer 的反对意见。

---

## Stage 7: FIX（修复）

### 7.1 按文件分组修复

按文件分组所有 P0/P1（Critical/High），每组一次修复。

**修复约束：**
- 每组只修一个文件
- 修复后立即 `{PM} run check`
- 不引入新文件级修改（避免范围蔓延）

### 7.2 修复后复审

修完 P0 后，重新调 `superpowers:requesting-code-review` 复审（只看修改部分），确认 Critical 清零。

### Gate

- ✅ 通过：P0 清零 + `{PM} run check` 全绿
- ❌ 阻塞：P0 无法清零（回到 Stage 4 PLAN 重选方案）

---

## Stage 8: SHIP（全量验证 + 提交推送）

> hotfix 模式（Stage 2 判定为 `hotfix/`）可跳过 Stage 6/7，直接到本阶段。
>
> 🚨 **SHIP 边界**：只到 `git push` 为止。**不创建 MR 合入主分支**——是否合 main 由用户在 DEPLOY 阶段之后自行决定，dev-lite 不越俎代庖。

### 8.1 调用 /ship

使用 Skill 工具调用 `/ship`，该指令会自动完成（见 `core/commands/ship.md`）：

1. **项目探测** — 找到 package.json，检查可用 scripts
2. **全量验证** — 按 scripts 探测并依次执行：
   - `npm run type-check`（若存在）
   - `npm run lint`（若存在）
   - `npm run build`（若存在）
   - 任一失败立即中止
3. **提交** — 分析 diff，生成 conventional commits 信息，**展示给用户确认**后 `git commit`
4. **推送** — `git push -u origin <current-branch>`，远程有新提交则 `pull --rebase` 后重试

### 8.2 输出 SHIP 摘要

```
🚀 SHIP 完成

   🌿 分支：<current-branch>
   📦 变更：<N> 文件，<M> 行
   ✅ 验证：type-check ✓ | lint ✓ | build ✓
   📝 Commit：<hash> <message>
   🔼 Push：origin/<current-branch>
```

### Gate

- ✅ 通过：`/ship` 全量验证通过 + push 成功。**通过后自动进入 Stage 9 DEPLOY，不可停在 Stage 8。**
- ❌ 阻塞：`/ship` 的 type-check / lint / build 任一失败、push 失败
- 🚨 **禁止：在 SHIP 摘要输出后就结束流程**——Stage 8 通过后 Stage 9 是硬性后继，不存在"流程到 SHIP 就完成"的路径。

---

## Stage 9: DEPLOY（生成上线步骤 + 询问人工验证）

> 🚨 **MANDATORY**：本阶段不可跳过。SHIP 成功后**必须**产出上线步骤并询问用户是否合 test 分支。**不存在"到 SHIP 就结束"的路径。**

**Stage 8 Gate 通过后自动进入本阶段，无需等待用户指令。第一个动作是输出上线步骤清单。**

### 9.1 生成本次上线步骤

读取本次 dev-lite 全流程的产出（需求摘要 / 变更文件 / 测试情况 / 验收标准），生成结构化的上线步骤清单：

```
📋 上线步骤清单 — <分支名或需求标题>

【变更概述】
- 类型：bugfix / feature / refactor / hotfix
- 目标：<一句话目标>

【影响范围】
- 变更文件：<N> 个
- 关键模块：<列出核心文件/模块>
- 是否涉及数据库变更：是/否
- 是否涉及配置变更：是/否
- 是否涉及破坏性变更（API/契约/数据格式）：是/否

【依赖项检查】
- 新增依赖：<列表 或 "无">
- 移除依赖：<列表 或 "无">
- 依赖版本升级：<列表 或 "无">

【上线前准备】
- [ ] 数据库迁移（若涉及）：<迁移脚本路径或说明>
- [ ] 配置项新增/修改（若涉及）：<配置 key + 期望值 + 环境变量来源>
- [ ] 灰度/开关准备（若涉及）：<feature flag 名称>
- [ ] 回滚预案确认：<回滚步骤 或 "可直接 git revert">

【上线步骤】
1. 合并分支到目标环境分支（test/staging/prod）
2. 部署服务（CI 触发或手动）
3. 健康检查：<需要检查的端点/页面/指标>
4. 冒烟验证：
   - <冒烟用例 1（对应验收标准 1）>
   - <冒烟用例 2（对应验收标准 2）>
   - ...

【上线后验证（人工）】
- [ ] 核心流程跑通：<具体流程描述>
- [ ] 原 bug 未复现（bugfix）：<复现路径 + 预期结果>
- [ ] 监控指标正常：<关键指标 如 error rate / latency>
- [ ] 日志无异常：可调用 /tail-log（测试环境）或 /sls-log（生产）核对

【回滚方案】
- 回滚命令：`git revert <commit-hash>` + 重新部署
- 数据回滚：<若涉及 DB 变更需要数据回滚的说明，否则 "无需" >
- 配置回滚：<若涉及配置变更的还原步骤，否则 "无需" >
```

### 9.2 询问用户是否合 test 分支做人工验证

使用 `AskUserQuestion` 工具询问：

```
question: "是否现在合并到 test 分支（部署测试环境）做人工验证？"
header: "合 test 分支"
options:
  - label: "是，立即合 test"
    description: "调用 /sync-push test，提交当前分支 + 合并到 test + 推送 test，部署后你可以做人工冒烟验证"
  - label: "否，稍后手动"
    description: "本次 dev-lite 流程到此结束。上线步骤清单已生成，你可以稍后手动执行 /sync-push test"
  - label: "直接合主分支"
    description: "跳过 test，直接合 main/master（仅建议 hotfix 场景使用）"
```

### 9.3 根据用户选择执行

**选项 1（合 test）：**

使用 Skill 工具调用 `/sync-push test`。该指令会：
1. 提交当前分支（若还有未提交变更）
2. 推送当前分支到远程
3. 切到 test 分支，`git pull origin test`
4. `git merge <source-branch>`（冲突则中止并提示）
5. `git push origin test`
6. 切回原分支

**选项 2（稍后手动）：**

输出收尾提示：

```
📌 本次 dev-lite 流程结束

   上线步骤清单已生成在上方，请保存或归档。
   稍后可随时执行：
   - 合 test：/sync-push test
   - 查测试环境日志：/tail-log
   - 查生产日志：/sls-log
   - 合 main：手动创建 MR 或 /glab-mr（若可用）
```

**选项 3（直接合 main）：**

使用 Skill 工具调用 `/sync-push main`（或 `/sync-push master`，按项目实际）。

### Gate

- ✅ 通过：上线步骤清单已生成 + 用户已选择并执行对应动作
- ❌ 阻塞：用户拒绝所有选项且未明确后续计划

---

## 阶段流转图（含调用链）

```
[Stage 1] BRAINSTORM
    ↓ 调 superpowers:brainstorming
[Stage 2] BRANCH
    ↓ 调 /dev-branch              ← 替代 rfc-driven-dev 的 worktree
[Stage 3] RESEARCH
    ↓ Agent 并行派 2 个
[Stage 4] PLAN
    ↓ 调 superpowers:writing-plans -> 产出 docs/superpowers/plans/YYYY-MM-DD-<topic>.md
[Stage 5] EXECUTE
    ↓ 调 superpowers:subagent-driven-development (+ test-driven-development for bugfix)
[Stage 6] REVIEW  ← 多专家 panel（3+ agent 并行）
    ↓ 调 superpowers:requesting-code-review
    ↓ (hotfix 可跳过本阶段)
[Stage 7] FIX (条件触发)
    ↓ 按 P0/P1 分组修复
[Stage 8] SHIP  ← 只到 push 为止，不创 MR 合主分支
    ↓ 调 /ship (全量验证 + commit + push)
[Stage 9] DEPLOY  ← 生成上线步骤 + 询问人工验证
    ↓ 输出上线步骤清单
    ↓ AskUserQuestion: 是否 /sync-push test？
    ├─ 选项1: 调 /sync-push test (合 test 分支)
    ├─ 选项2: 流程结束，用户稍后手动
    └─ 选项3: 调 /sync-push main (直接合主分支)
```

## 智能分流（Stage 1 BRAINSTORM 判定 → 影响后续）

| 类型 | 分支前缀 | EXECUTE 策略 | REVIEW 触发 |
|------|---------|-------------|------------|
| `bugfix` | `fix/` | 强制 TDD（调 superpowers:test-driven-development） | + 回归测试审查 |
| `feature` | `feat/` | 实现 + 单测 | 标准 + 性能 |
| `refactor` | `refactor/` | 保持测试全绿 | + 行为等价性审查 |
| `hotfix` | `hotfix/` | 快速修复 | **跳过 REVIEW 直接 SHIP** |

---

## 使用方式

```
/dev-lite 修复登录页在 Safari 崩溃
/dev-lite 给用户列表加搜索功能
/dev-lite 重构 formatDate 工具函数
```

或自然语言触发：
- "快速修复 xxx"
- "小需求开发"
- "这个 bug 帮我走 dev-lite"

---

## 与 rfc-driven-dev 的边界

| 维度 | rfc-driven-dev | dev-lite |
|------|----------------|----------|
| 阶段数 | 12 | **9** |
| 适用 | 中大型需求、架构变更 | bugfix、小功能、重构 |
| 文档 | RFC 全生命周期（inbox→draft→approved→completed） | **无** |
| 隔离机制 | ✅ worktree（`git worktree add`） | ✅ **`/dev-branch` 常规分支** |
| 独立 Plan 文件 | ✅ | ✅ **调 superpowers:writing-plans 产出 specs 文档** |
| 调研 agent | 2（Agent 直接派） | **2**（同上） |
| EXECUTE 编排 | superpowers:subagent-driven-development | **同左** |
| bugfix TDD | PLAN checkbox 要求 | **调 superpowers:test-driven-development 强制** |
| 评审 panel | 3 agent（架构/可行性/完整性） | **3+ agent**（质量+spec / 安全+边界 / 按类型第 3 个 / 争议时第 4 仲裁） |
| 评审阈值 | ≥8 | **≥7** |
| WIP squash | ✅ | ❌ |
| 提交推送 | 手动 `git commit/push` + `glab-mr` | **调 `/ship`**（内置全量验证+commit+push） |
| MR 自动化 | ✅ 调 glab-mr 合入 target | ❌ **SHIP 只到 push，不合主分支** |
| 上线步骤 | ❌ | ✅ **Stage 9 DEPLOY 生成结构化上线清单** |
| 合 test 分支 | ❌ | ✅ **询问用户，同意后调 /sync-push test** |
| BRAINSTORM | ❌（RFC 文档本身就是产物） | **✅ 前置调 superpowers:brainstorming** |

## 复用的 skill/command 清单（一站式索引）

| Stage | Skill/Command | 源文件 |
|-------|---------------|--------|
| 1 | `superpowers:brainstorming` | plugin: superpowers |
| 2 | `/dev-branch` | `core/commands/dev-branch.md` |
| 3 | （Agent 工具直接派） | — |
| 4 | `superpowers:writing-plans` | plugin: superpowers |
| 5 | `superpowers:subagent-driven-development` | plugin: superpowers |
| 5 | `superpowers:test-driven-development`（bugfix） | plugin: superpowers |
| 6 | `superpowers:requesting-code-review`（+ Agent 工具派 panel） | plugin: superpowers |
| 8 | `/ship` | `core/commands/ship.md` |
| 9 | `/sync-push test`（用户同意后） | `core/commands/sync-push.md` |
