---
name: mgv-rfc-approve
description: >
  RFC 审批器。5 维度完整性检查 + 状态流转（Draft → Approved）。
  审批通过后自动 git mv 到 approved/ 目录并更新索引。
  触发词：mgv-rfc-approve、审批 RFC、approve RFC、RFC 审批。
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Grep
  - Glob
---

# mgv-rfc-approve: RFC 审批器

检查 RFC 完整性，通过后执行状态流转。

## 输入

- **RFC ID**：如 `COACH-001`
- 或 **RFC 文件路径**：如 `docs/rfcs/draft/COACH-001-audio-pipeline.md`

## 处理流程

### Step 1: 定位 RFC

1. 在 `docs/rfcs/draft/` 中搜索匹配文件
2. 读取 RFC 内容
3. 如果找不到，输出 blocked 事件

### Step 2: 5 维度完整性检查

逐维度检查，每个维度给出 pass/fail + 理由：

| # | 维度 | 检查标准 | pass 条件 |
|---|------|---------|-----------|
| 1 | **Goals** | 是否清晰定义了要解决的问题和预期效果 | 目标具体、可验证，不是模糊描述 |
| 2 | **Background** | 是否解释了动机、现状、痛点 | 包含"为什么现在做"的理由 |
| 3 | **Design** | 是否有具体技术方案 | 方案可执行，不是空洞的原则性描述 |
| 4 | **Implementation** | 是否可拆分为可执行任务 | 任务清单具体，每项 ≤ 4 小时 |
| 5 | **Acceptance Criteria** | 是否可量化/可测试 | 每条 AC 能用测试或检查验证 |

### Step 3: 输出检查结果

```json
{
  "event": "approval_check",
  "rfc_id": "COACH-001",
  "checks": {
    "goals": {"status": "pass", "note": "..."},
    "background": {"status": "pass", "note": "..."},
    "design": {"status": "fail", "note": "缺少具体的 API 设计"},
    "implementation": {"status": "pass", "note": "..."},
    "acceptance_criteria": {"status": "pass", "note": "..."}
  },
  "overall": "blocked"
}
```

### Step 4: 状态流转（全部 pass 时）

如果 5 维度全部通过：

1. 更新 frontmatter：`status: Draft` → `status: Approved`，追加 `approved: {YYYY-MM-DD}`
2. 执行：`git mv docs/rfcs/draft/{file} docs/rfcs/approved/{file}`
3. 更新 `docs/rfcs/README.md` 索引：状态从 `Draft` 改为 `Approved`，路径更新
4. Stage 变更：`git add docs/rfcs/`

### Step 5: 输出审批结果

通过：
```json
{
  "event": "approved",
  "rfc_id": "COACH-001",
  "file": "docs/rfcs/approved/COACH-001-audio-pipeline.md"
}
```

阻塞：
```json
{
  "event": "blocked",
  "stage": "rfc_approval",
  "reason": "design dimension failed",
  "details": "缺少具体的 API 设计",
  "failed_dimensions": ["design"]
}
```

## Gate

- **通过**：5 维度全部 pass，RFC 已移入 `docs/rfcs/approved/`，frontmatter 状态为 Approved
- **阻塞**：任一维度 fail

## 注意事项

- 审批只做完整性检查，不做技术方案评审（技术评审由 rfc-driven-dev Stage 4 的 3 视角评审负责）
- 不修改 RFC 内容，只检查和移动文件
- 如果 RFC 的 frontmatter status 不是 `Draft`，直接 blocked（只能审批 Draft 状态的 RFC）
