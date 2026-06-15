---
name: rfc-brainstorm
description: >
  RFC 前置需求讨论器。在写 inbox 文档之前使用，通过一次一个问题的方式厘清需求边界、
  探索备选方案，产出结构化的 inbox 文档。不进入执行流水线，职责单一。
  触发词：rfc-brainstorm、讨论需求、brainstorm RFC、RFC 想法、需求讨论。
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
  - AskUserQuestion
---

# rfc-brainstorm: RFC 前置需求讨论器

把模糊想法变成结构化的 inbox 文档，**不进流水线**。

## 核心理念

1. **一次一个问题**：不要一次问 5 个，让用户能认真回答每一个
2. **探索项目现状**：先看代码再问问题，问得才有针对性
3. **提供选项而不是开放式**：能用多选题就不要用开放式提问
4. **不替用户决定方向**：方案选择权在用户，AI 只列 trade-offs
5. **结构化产出**：最后写出来的 inbox 文档要让 rfc-driven-dev 容易消费

## 输入

用户提供：
- **主题或想法**：可以是一句话（"我想给项目加暗黑模式"），也可以是一段粗略描述
- **可选：现有文档**：如果已经有部分笔记，可以传入作为起点

## 处理流程

### Step 1: 探索项目现状

用 Read / Glob / Grep 快速了解：
- 项目技术栈（读 package.json / go.mod / Cargo.toml 等）
- 相关代码目录结构
- 是否已有类似实现
- 最近的 commit history 中是否有相关线索

**不要修改任何代码**，只读不写。

### Step 2: 一次一个问题地厘清需求

**严格规则：每条消息只问一个问题**。

按以下顺序问（如果某个问题用户已经在主题描述中讲清楚了，跳过）：

**Q1 - 目标**：你想达成什么效果？给用户/业务带来什么价值？

**Q2 - 现状与痛点**：现在是怎么做的？为什么不行？

**Q3 - 范围边界**：哪些**不做**？这个比"做什么"更重要。

**Q4 - 约束**：有什么硬约束？（不能引入新依赖、不能破坏现有 API、性能要求、时间限制等）

**Q5 - 成功标准**：做完之后怎么验证成功？必须是可观察/可测量的。

**Q6 - 待解决问题**：有哪些你不确定、需要后续调研的？（这一步是给 rfc-driven-dev Stage 1 的 research agent 留作业）

> 用 AskUserQuestion 工具问，尽量给多选项。

### Step 3: 提出 2-3 种方案

基于前面的回答，提出 2-3 个不同的技术/产品方案。**不要只列一个"最优解"**，要真实地展示备选。

对每个方案：
- **核心思路**：一段话概括
- **优点**：3 条以内
- **缺点**：3 条以内
- **工作量预估**：粗略的小/中/大

然后用 AskUserQuestion 让用户选：
- 选项 A / B / C
- 每个选项的 description 写"优点 + 缺点 + 工作量"

### Step 4: 处理用户选择

用户选了某个方案后：
- 记录该方案为已选
- 把其他方案标记为"已讨论但未选"，附驳回理由
- 如果用户选了"Other"（自定义），确认理解后记录

### Step 5: 输出 inbox 文档

按以下模板写入 `docs/rfcs/inbox/{YYYY-MM-DD}-{slug}.md`：

```markdown
---
title: {title}
created: {YYYY-MM-DD}
source: brainstorm
status: inbox
---

# {title}

## 背景

- **来源**：{谁提的、什么时候、什么场景}
- **现状**：{代码现状、相关实现}
- **痛点**：{为什么现在做}

## 目标（用户视角）

<!-- 列出 3-5 条具体目标，每条以动词开头 -->

## 范围

### 在范围内（In Scope）
- ...

### 不在范围内（Non-Goals）
- ...

## 约束

- ...

## 已讨论的方案

### 方案 A：{名称}（已选 ✓）
- **核心思路**：...
- **优点**：...
- **缺点**：...

### 方案 B：{名称}
- **核心思路**：...
- **优点**：...
- **缺点**：...
- **驳回理由**：...

## 成功标准

<!-- 可观察/可测量的验收条件，每条都能用测试或检查验证 -->

## 待解决问题

<!-- rfc-driven-dev Stage 1 的 research agent 会针对这些做并行调研 -->

- ...
```

### Step 6: 提示用户检查

输出文档路径，并提示：

> inbox 文档已写入 `docs/rfcs/inbox/{filename}`。
> 请检查内容是否准确反映了你的意图。
> 确认无误后，运行 `/rfc-driven-dev docs/rfcs/inbox/{filename}` 启动全流程。
> 如需修改，直接编辑该文件即可。

## Gate

- **完成**：inbox 文档已生成，包含全部 6 个章节（背景、目标、范围、约束、方案、成功标准）
- **阻塞**：用户拒绝回答关键问题、项目根本不存在相关代码上下文

## 注意事项

- **不写 RFC**：不调用 rfc-author，不生成 RFC，不进入 draft 目录
- **不调研行业实践**：那是 rfc-driven-dev Stage 1 干的事，brainstorm 只看项目现状
- **不评估方案优劣**：只列 trade-offs，决定权在用户
- **不做技术选型决定**：用户没选之前不要默认任何一个
- **不做实现规划**：那是 rfc-driven-dev Stage 7 (PLAN) 干的事

## 输出

成功：
```json
{
  "event": "brainstorm_completed",
  "file": "docs/rfcs/inbox/2026-06-15-dark-mode.md",
  "selected_approach": "方案 A: Tailwind dark: variant",
  "next_action": "运行 /rfc-driven-dev docs/rfcs/inbox/2026-06-15-dark-mode.md"
}
```

阻塞：
```json
{
  "event": "blocked",
  "stage": "rfc_brainstorm",
  "reason": "...",
  "details": "..."
}
```

## 使用方式

```
/rfc-brainstorm 给项目加暗黑模式
```

或：

```
/rfc-brainstorm
主题：暗黑模式
```

或自然语言：
- "讨论个需求"
- "我想加个功能，帮我理一下"
- "brainstorm RFC"
