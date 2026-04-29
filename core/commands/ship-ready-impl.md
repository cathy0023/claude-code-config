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
如果 FROM_STAGE <= 3，并行启动三个 agents：

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
