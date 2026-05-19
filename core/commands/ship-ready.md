# Ship Ready - 完整代码质量保证工作流

代码开发完成后的完整质量保证流程，从验证到提交的一站式工作流。

## 执行说明

当用户调用 `/ship-ready` 时，按以下步骤执行：

### 阶段 0: 确定审核范围 (Diff Scope)
1. 获取项目主分支名称：`git remote show origin | grep 'HEAD branch'` 或默认 `main`/`master`
2. 获取当前分支名称：`git branch --show-current`
3. 如果当前分支就是主分支，提示用户：`当前已在主分支上，无法确定审核范围。请先切换到功能分支再执行 ship-ready。` 并终止流程
4. 拉取主分支最新代码：`git fetch origin <main-branch>`
5. 生成 diff 范围：`git diff origin/<main-branch>...HEAD --stat`，展示变更文件和行数统计
6. 向用户确认审核范围：
   ```
   === SHIP READY - 审核范围 ===
   当前分支: <current-branch>
   对比基准: origin/<main-branch>
   变更文件: N 个
   新增行: +X  删除行: -Y

   变更文件列表:
   - path/to/file1.ts (+50/-10)
   - path/to/file2.ts (+20/-5)
   ...

   确认以上变更范围为审核对象？[YES/NO]
   ```
7. 用户确认后，将 `origin/<main-branch>...HEAD` 作为后续所有阶段的 diff 基准，传入各 review agent 的 prompt 中
8. 如果用户拒绝，询问是否需要切换基准分支或终止流程

### 阶段 1: 基础验证 (Verify)
1. 调用 Skill tool: `verify`
2. 检查输出是否有 CRITICAL/HIGH 问题
3. 如果有，停止并报告，等待修复

### 阶段 2: 代码优化 (Simplify)
1. 调用 Skill tool: `simplify`
2. 等待优化完成
3. 如果用户传入 `quick` 参数，跳过此阶段

### 阶段 3: 多方代码审查 (Multi-Review)

**步骤 3a：并行启动三个 review agents（使用 Agent tool 并行调用）：**

**Agent 1: code-reviewer**
```
Agent tool:
  subagent_type: code-reviewer
  description: "Security and quality review"
  prompt: "Review the diff between origin/<main-branch> and HEAD for:
    - Security vulnerabilities (CRITICAL)
    - Code quality issues (HIGH)
    - Best practices violations (MEDIUM)

    Use `git diff origin/<main-branch>...HEAD` to identify changed files.
    Report findings with severity levels and file:line locations."
```

**Agent 2: superpowers:code-reviewer**
```
Agent tool:
  subagent_type: superpowers:code-reviewer
  description: "Plan-based code review"
  prompt: "Review the diff between origin/<main-branch> and HEAD against the original plan and coding standards.

    Use `git diff origin/<main-branch>...HEAD` to identify changed files.
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
  prompt: "Scan the diff between origin/<main-branch> and HEAD for security vulnerabilities:
    - Hardcoded secrets
    - SQL injection
    - XSS vulnerabilities
    - Missing input validation
    - OWASP Top 10 issues

    Use `git diff origin/<main-branch>...HEAD` to identify changed files.
    Report CRITICAL and HIGH issues with specific locations."
```

**步骤 3b：等待上述三个 agents 完成后，串行调用 codex:review：**

> 注意：`codex:review` 是 slash command（`disable-model-invocation: true`），不是 agent type，
> 不能通过 Agent tool 的 subagent_type 调用，必须使用 Skill tool。

```
Skill tool: codex:review
args: "--wait --base origin/<main-branch>"
```

### 阶段 4: 综合评判与修复
1. 收集四个 agents 的审查结果
2. 合并相同的问题（去重）
3. 按优先级排序：CRITICAL > HIGH > MEDIUM > LOW
4. 列出必须修复的问题（CRITICAL + HIGH）
5. 逐个修复，每修复一个运行相关测试验证

### 阶段 5: 接收审查反馈
调用 Skill tool: `superpowers:receiving-code-review`
- 技术性评估反馈
- 验证建议的正确性
- 必要时技术性反驳
- 一次实施一项，逐个测试

### 阶段 6: 完成前验证
调用 Skill tool: `superpowers:verification-before-completion`
- 运行完整验证命令
- 确认所有测试通过
- 检查构建成功
- 验证覆盖率达标
- **必须有实际输出证据**

### 阶段 7: 人工确认
向用户展示：
```
=== SHIP READY REPORT ===

[验证结果]
✓ Build: OK
✓ Tests: X/Y passed, Z% coverage
✓ Linter: 0 errors

[修复的问题]
- CRITICAL: X 个已修复
- HIGH: Y 个已修复
- MEDIUM: Z 个已修复

[代码变更]
- 文件数: N
- 新增行: +X
- 删除行: -Y

Ready to commit and push? [YES/NO]
```

等待用户明确回复 YES 后继续。

### 阶段 8: Commit & Push
1. 运行 `git status` 和 `git diff --stat`
2. 生成符合规范的 commit message
3. 执行 `git commit`
4. 询问是否 push
5. 如果用户同意，执行 `git push`

## 使用方法

```bash
# 完整流程（默认）
/ship-ready

# 快速模式（跳过 simplify）
/ship-ready quick

# 仅审查模式（从阶段 3 开始）
/ship-ready review-only
```

## 参数说明

- 无参数：执行完整的 9 个阶段（含阶段 0 确定审核范围）
- `quick`：跳过阶段 2（代码优化）
- `review-only`：从阶段 3 开始（跳过 verify 和 simplify）

## 注意事项

1. **并行执行审查** - 三个 review agents 并行启动（Agent tool），codex:review 串行跟进（Skill tool）
2. **证据驱动** - 所有声明必须有命令输出支持
3. **人工把关** - 阶段 8 必须等待用户明确批准
4. **增量修复** - 修复一个问题后立即验证
5. **不跳过阶段** - 除非用户指定参数，否则按顺序执行所有阶段

## 相关命令

- `/verify` - 单独运行基础验证
- `/simplify` - 单独运行代码优化
- `/code-review` - 单独运行代码审查
- `superpowers:requesting-code-review` - 请求代码审查
- `superpowers:receiving-code-review` - 接收审查反馈
- `superpowers:verification-before-completion` - 完成前验证
