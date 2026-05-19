# Ship Ready Implementation

执行完整的代码质量保证工作流。

## 执行流程

当用户调用 `/ship-ready` 时，按以下步骤执行：

### 步骤 1: 解析参数
```bash
MODE=${1:-full}  # full, quick, review-only
FROM_STAGE=${2:-1}
```

### 步骤 2: 阶段 1 - 基础验证
如果 FROM_STAGE <= 1，执行 `/verify` 命令：
- 调用 Skill tool: `verify`
- 检查输出中是否有 CRITICAL 或 HIGH 问题
- 如果有，停止并报告

### 步骤 3: 阶段 2 - 代码优化
如果 MODE != "quick" 且 FROM_STAGE <= 2，执行 `/simplify`：
- 调用 Skill tool: `simplify`
- 等待优化完成

### 步骤 4: 阶段 3 - 多方代码审查

如果 FROM_STAGE <= 3：

**步骤 4a：并行启动三个 agents（Agent tool）：**

**Agent 1: code-reviewer**
```
Agent tool:
  subagent_type: code-reviewer
  description: "Security and quality review"
  prompt: "Review all uncommitted changes for security issues, code quality, and best practices. Focus on:
    - Security vulnerabilities (CRITICAL)
    - Code quality issues (HIGH)
    - Best practices violations (MEDIUM)

  Report findings with severity levels and specific file:line locations."
```

**Agent 2: superpowers:code-reviewer**
```
Agent tool:
  subagent_type: superpowers:code-reviewer
  description: "Plan-based code review"
  prompt: "Review the implementation against the original plan and coding standards.

    Check for:
    - Requirements coverage
    - Architectural alignment
    - Code quality and maintainability

    Report with severity: CRITICAL, HIGH, MEDIUM, LOW"
```

**Agent 3: security-reviewer**
```
Agent tool:
  subagent_type: security-reviewer
  description: "Security vulnerability scan"
  prompt: "Scan for security vulnerabilities:
    - Hardcoded secrets
    - SQL injection
    - XSS vulnerabilities
    - Missing input validation
    - OWASP Top 10 issues

    Report CRITICAL and HIGH issues with specific locations."
```

**步骤 4b：等待上述三个 agents 完成后，串行调用 codex:review（Skill tool）：**

> 注意：`codex:review` 是 slash command（`disable-model-invocation: true`），不是 agent type，
> 不能通过 Agent tool 的 subagent_type 调用，必须使用 Skill tool。

```
Skill tool: codex:review
args: "--wait"
```

### 步骤 5: 阶段 4 - 综合评判与修复
1. 收集四个 review 的结果
2. 合并相同的问题（去重）
3. 按优先级排序：CRITICAL > HIGH > MEDIUM > LOW
4. 列出必须修复的问题（CRITICAL + HIGH）
5. 逐个修复，每修复一个运行相关测试验证

### 步骤 6: 阶段 5 - 接收审查反馈
调用 Skill tool: `superpowers:receiving-code-review`

### 步骤 7: 阶段 6 - 完成前验证
调用 Skill tool: `superpowers:verification-before-completion`

### 步骤 8: 阶段 7 - 人工确认
展示 SHIP READY REPORT，等待用户明确回复 YES。

### 步骤 9: 阶段 8 - Commit & Push
1. 运行 `git status` 和 `git diff --stat`
2. 生成符合规范的 commit message
3. 执行 `git commit`
4. 询问是否 push
5. 如果用户同意，执行 `git push`
