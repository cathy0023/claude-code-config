---
name: rfc-author
description: >
  RFC 生成器。从 docs/rfcs/inbox/ 中的原始文档生成规范 RFC 到 docs/rfcs/draft/。
  包含模板定义、命名规范、序号管理。
  触发词：rfc-author、生成 RFC、写 RFC、创建 RFC。
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

# rfc-author: RFC 生成器

从原始需求文档生成符合模板的 RFC。

## 前置条件

项目必须已初始化 RFC 目录结构：

```
docs/rfcs/
├── README.md
├── inbox/
├── draft/
├── approved/
└── completed/
```

如未初始化，提示用户先运行 `/rfc-init` 或手动创建。

## 配置

RFC 命名规范按项目区分，配置写在 `docs/rfcs/README.md` 的 Series Configuration 表格中：

```markdown
## Series Configuration

| Project | Series Prefix | Next Number |
|---------|--------------|-------------|
| coach-react | COACH | 1 |
| agent-platform | AGENT | 1 |
```

skill 会：
1. 读取 `docs/rfcs/README.md`
2. 根据当前 git 仓库名匹配 Series Prefix
3. 如果未匹配到，询问用户要用的前缀，并自动追加到配置表

## 输入

用户提供以下之一：
- **文档路径**：`docs/rfcs/inbox/xxx.md`
- **主题关键词**：自动在 `inbox/` 中搜索匹配文件
- **直接文本**：用户口述需求，skill 自行创建 inbox 文档再生成 RFC

## 处理流程

### Step 1: 读取原始文档

用 Read 工具读取 inbox 中的文档，提取：
- 核心主题（一句话概括）
- 涉及的技术栈
- 关键需求和约束
- 目标用户/场景

### Step 2: 确定命名

1. 读取 `docs/rfcs/README.md` 获取 Series Prefix 和 Next Number
2. 根据主题生成 kebab-case slug（如 `audio-pipeline`、`auth-refactor`）
3. 组合为文件名：`{SERIES}-{NNN}-{slug}.md`
   - 例：`COACH-001-audio-pipeline.md`

### Step 3: 生成 RFC

按以下模板生成完整 RFC：

```markdown
---
id: {SERIES}-{NNN}
title: {title}
status: Draft
created: {YYYY-MM-DD}
authors: [current-git-user]
---

# {title}

## Goals

<!-- 要解决什么问题，达成什么效果。必须是具体的、可验证的。 -->

## Background / Motivation

<!-- 为什么现在做：现状是什么，痛点是什么，不做会怎样。
     引用具体的数据、用户反馈、或技术指标。 -->

## Design

<!-- 具体技术方案。包含：
     - 架构概述
     - 核心组件/模块
     - 数据流（如涉及）
     - API 设计（如涉及）
     - 配置项（如涉及）
     画图用 Mermaid 或 ASCII。 -->

## Implementation

<!-- 可拆分的实现任务清单。每项任务应能在 2-4 小时内完成。
     格式：
     - [ ] Task 1: 描述...
     - [ ] Task 2: 描述... -->

## Acceptance Criteria

<!-- 可量化/可测试的验收条件。每条必须能用测试或检查验证。
     格式：
     - [ ] AC1: 具体条件...
     - [ ] AC2: 具体条件... -->

## Notes

<!-- 已知风险、外部依赖、回滚方案、性能考量等。 -->
```

### Step 4: 写入并更新索引

1. 将 RFC 写入 `docs/rfcs/draft/{filename}.md`
2. 更新 `docs/rfcs/README.md`：
   - 在 Series Configuration 表中 `Next Number` +1
   - 在 RFC Status 表中追加一行：`| {ID} | {title} | Draft | draft/{filename}.md |`

### Step 5: 自检

- 6 个必填章节全部存在（Goals, Background, Design, Implementation, Acceptance Criteria, Notes）
- 无 TBD/TODO 占位符
- frontmatter 包含 id, title, status, created
- 文件路径正确

## Gate

- **通过**：RFC 文件存在于 `docs/rfcs/draft/`，自检全部通过
- **阻塞**：模板章节缺失、存在 TBD/TODO、命名冲突

## 输出

成功时输出：
```json
{"event":"rfc_created","rfc_id":"COACH-001","file":"docs/rfcs/draft/COACH-001-audio-pipeline.md"}
```

阻塞时输出：
```json
{"event":"blocked","stage":"rfc_author","reason":"...","details":"..."}
```
