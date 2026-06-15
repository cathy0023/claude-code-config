# rfc-driven-dev Skill 分析与补齐设计

## 1. 概述

`rfc-driven-dev` 是一个 11 阶段全流程编排器，将 RFC 文档从原始需求一路推到代码交付。本 spec 记录分析结论和补齐计划。

## 2. Skill 哲学

| 理念 | 做法 | 意图 |
|------|------|------|
| 调研先行 | Stage 1 并行派 2 agent（项目现状 + 行业实践） | 不了解全貌不做决定 |
| Gate 机制 | 每阶段明确准入/准出条件 | 防止缺陷往后传递 |
| JSON 事件 | 阻塞时输出 `{"event":"blocked",...}` | 结构化状态，方便上层判断 |
| 有界迭代 | 评审 ≤3 轮、修复 ≤2 次 | 防止无限循环 |

## 3. 依赖分析

### 3.1 已存在（可直接使用）

| Skill | Stage | 来源 |
|-------|-------|------|
| `superpowers:writing-plans` | 7 (PLAN) | superpowers 插件 |
| `superpowers:subagent-driven-development` | 8 (EXECUTE) | superpowers 插件 |
| `superpowers:requesting-code-review` | 9 (REVIEW) | superpowers 插件 |

### 3.2 需要新建

| Skill | Stage | 复杂度 | 说明 |
|-------|-------|--------|------|
| `rfc-author` | 3 (RFC GENERATION) | 高 | RFC 生成器，含模板和命名规范 |
| `mgv-rfc-approve` | 5 (RFC APPROVAL) | 中 | RFC 审批器，5 维度检查 + 状态流转 |
| `glab-mr` | 12 (DELIVER) | 低 | GitLab MR 创建封装 |

### 3.3 基础设施依赖

| 依赖 | 状态 | 处理 |
|------|------|------|
| `glab` CLI | **未安装** | 需要安装并认证 |
| `docs/rfcs/` 目录结构 | **不存在** | 需要初始化 |
| Git worktree | 已支持 | git 内置功能 |
| pnpm | 按项目 | 参数化后无需全局要求 |

## 4. rfc-driven-dev 参数化设计

### 4.1 配置参数

将硬编码值提取为 skill 参数（通过 frontmatter 或用户配置文件）：

```yaml
# 用户可通过 .claude/rfc-config.yml 或 CLAUDE.md 定义
rfc:
  series_prefix: ""           # 按项目区分，如 "COACH"、"AGENT"
  start_number: 1             # 起始编号
  review_score_threshold: 8   # 评审通过阈值（原硬编码为 9）
  max_review_rounds: 3        # 最大评审轮数
  max_fix_rounds: 2           # 最大修复轮数
  branch_prefix: ""           # 分支名前缀（原硬编码为 "xxh-"）
  package_manager: "pnpm"     # 包管理器（pnpm/npm/yarn）
```

### 4.2 具体参数化位置

| 原始值 | 参数化后 | 文件位置 |
|--------|---------|---------|
| `pnpm install` / `pnpm check` | `{package_manager} install` / `{package_manager} check` | Stage 2, Stage 8, Stage 12 |
| `feat/xxh-audio-pipeline` | `{branch_type}/{branch_prefix}{branch_shortname}` | Stage 2 |
| `≥ 9 分` | `≥ {review_score_threshold} 分` | Stage 4 |
| `最多 3 轮` | `最多 {max_review_rounds} 轮` | Stage 4 |
| `最多 2 次` | `最多 {max_fix_rounds} 次` | Stage 8, Stage 10 |

## 5. 新建 Skill 设计

### 5.1 rfc-author

**职责**：从 `docs/rfcs/inbox/` 的原始文档生成规范 RFC 到 `docs/rfcs/draft/`。

**输入**：
- 原始文档路径（`docs/rfcs/inbox/xxx.md`）
- 项目 SERIES 前缀（如 "COACH"）
- 调研报告内容（可选，由 rfc-driven-dev Stage 1 产出）

**输出**：
- RFC 文件：`docs/rfcs/draft/{SERIES}-{NNN}-{slug}.md`

**处理流程**：
1. 读取 inbox 文档，提取核心需求
2. 读取 `docs/rfcs/README.md` 获取系列前缀和下一个可用序号
3. 按 RFC 模板生成完整 RFC
4. 写入 `docs/rfcs/draft/`
5. 更新 `docs/rfcs/README.md` 索引

**RFC 模板**（6 个必填章节）：

```markdown
---
id: {SERIES}-{NNN}
title: {title}
status: Draft
created: {YYYY-MM-DD}
authors: [{author}]
---

# {title}

## Goals（目标）
<!-- 要解决什么问题，达成什么效果 -->

## Background / Motivation（背景）
<!-- 为什么现在做，现状是什么，痛点是什么 -->

## Design（方案）
<!-- 具体技术方案，包含架构图/流程图（如需要） -->

## Implementation（实现要点）
<!-- 可拆分的实现任务清单 -->

## Acceptance Criteria（验收标准）
<!-- 可量化/可测试的验收条件 -->

## Notes（注意事项）
<!-- 已知风险、依赖、回滚方案等 -->
```

**Gate**：
- RFC 文件存在且包含全部 6 个必填章节
- 无 TBD/TODO 占位符

### 5.2 mgv-rfc-approve

**职责**：检查 RFC 完整性 → 通过后状态流转。

**输入**：
- RFC ID（如 "COACH-005"）

**处理流程**：
1. 定位 `docs/rfcs/draft/{RFC_ID}*.md`
2. 5 维度完整性检查：
   - Goals：是否清晰定义了要解决的问题
   - Background：是否解释了动机和现状
   - Design：是否有具体技术方案
   - Implementation：是否可拆分为可执行任务
   - Acceptance Criteria：是否可量化/可测试
3. 通过 → `git mv` 到 `docs/rfcs/approved/`
4. 更新 frontmatter：`status: Draft` → `status: Approved`
5. 更新 `docs/rfcs/README.md` 索引

**输出**：
- 审批结果 JSON：`{"event":"approved"|"blocked","rfc_id":"...","check_results":{...}}`

**Gate**：
- 5 维度全部通过 → Approved
- 任一维度不通过 → 阻塞并报告缺失内容

### 5.3 glab-mr

**职责**：封装 GitLab MR 创建流程。

**前置条件**：
- `glab` CLI 已安装并认证
- 当前分支有未合并的 commits

**处理流程**：
1. 收集 MR 信息：
   - 标题：从 RFC title 提取
   - 描述：从 RFC Goals + Acceptance Criteria 生成
   - 目标分支：`develop`（可配置）
2. 执行：`glab mr create --title "..." --description "..." --target-branch develop`
3. 输出 MR URL

**Gate**：
- MR 创建成功 → 返回 URL
- 创建失败 → blocked

## 6. RFC 目录结构初始化

首次使用前需要初始化：

```
docs/rfcs/
├── README.md              # RFC 索引（含系列前缀配置）
├── inbox/                 # 原始需求文档
├── draft/                 # RFC 草稿
├── approved/              # 审批通过
└── completed/             # 已完成
```

`README.md` 模板：

```markdown
# RFC Index

## Series Configuration

| Project | Series Prefix | Next Number |
|---------|--------------|-------------|
| coach-react | COACH | 1 |

## RFC Status

| ID | Title | Status | File |
|----|-------|--------|------|
```

## 7. 前置安装

```bash
# 安装 glab CLI
brew install glab

# 认证
glab auth login

# 验证
glab --version
glab repo view
```

## 8. 补齐执行顺序

1. **安装 glab** + 认证
2. **创建 `rfc-author` skill**（含 RFC 模板）
3. **创建 `mgv-rfc-approve` skill**
4. **创建 `glab-mr` skill**
5. **参数化 `rfc-driven-dev`**（替换硬编码值）
6. **初始化 `docs/rfcs/` 目录结构**（按项目）
7. **端到端测试**：用一个简单的 RFC 文档跑完整个流水线
