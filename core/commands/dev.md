---
allowed-tools: Bash(npm run *), Bash(npx *), Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git log:*), Glob, Grep, Read, Edit, Write, Agent
description: 完整开发流程 - 从规划到提交的一键式工作流
argument-hint: [需求描述]
---

# /dev - 完整开发流程

根据用户需求，执行端到端的开发流程。不要把这个任务放到后台执行，我需要在前台实时看到任务进度。

用户需求：$ARGUMENTS

## 执行策略

- 每个阶段完成后，向用户汇报进度，等待确认后再继续下一阶段
- 如果某个阶段发现问题，立即暂停并说明
- 全程遵循 `.claude/rules/` 中的项目规范

---

## 阶段 0：项目探测

在执行任何操作前，先探测项目结构：

```bash
# 找到 package.json 所在目录（可能是项目根目录，也可能是 web/ 子目录）
find . -maxdepth 2 -name "package.json" -not -path "*/node_modules/*"
```

确定 `PKG_DIR`（package.json 所在目录），后续所有 npm 命令都在该目录下执行：
- 如果 `package.json` 在根目录：`PKG_DIR=.`
- 如果 `package.json` 在子目录（如 `web/`）：`PKG_DIR=web`

同时检查 `package.json` 中可用的 scripts：
```bash
cat $PKG_DIR/package.json | grep -A 20 '"scripts"'
```

记录可用的命令名称（不同项目可能叫 `typecheck`、`type-check`、`check` 等）。

---

## 阶段 1：规划

### 1.1 需求分析
- 理解用户需求的核心目标
- 识别涉及的业务模块和功能范围

### 1.2 代码探索
- 使用 Glob/Grep/Read 探索相关现有代码
- 了解当前的代码结构和实现方式
- 识别需要修改的文件和需要新建的文件

### 1.3 输出计划
列出：
- 需要修改/新建的文件清单
- 每个文件的主要改动内容
- 实现步骤（按优先级排序）
- 潜在的风险点和注意事项

**→ 暂停，等待用户确认计划后再继续**

---

## 阶段 2：编码

### 2.1 逐步实现
- 按计划逐步修改/创建文件
- 遵循项目 `.claude/rules/` 中的所有规范

### 2.2 自动检查
- 每次编辑后 hooks 会自动执行格式化和检查（如果已配置）

### 2.3 里程碑汇报
- 完成关键文件后汇报进度
- 遇到问题立即说明

**→ 编码完成后进入验证阶段**

---

## 阶段 3：验证

根据阶段 0 探测到的 scripts，依次执行可用检查。任何失败都要修复后重新运行：

### 3.1 类型检查（如果有 type-check/typecheck/tsc script）
```bash
cd $PKG_DIR && npm run type-check
```
如果不存在该 script，跳过。

### 3.2 Lint 检查（如果有 lint/eslint script）
```bash
cd $PKG_DIR && npm run lint
```
如果不存在该 script，跳过。

### 3.3 构建验证（如果有 build script）
```bash
cd $PKG_DIR && npm run build
```
如果不存在该 script，跳过。

**→ 所有可用验证通过后进入审查阶段**

---

## 阶段 4：审查

### 4.1 代码审查
使用 code-reviewer agent 审查代码质量，重点关注：
- 注释完整性
- 代码规范
- 类型安全
- 命名规范
- 性能问题
- 错误处理

### 4.2 修复问题
- 修复所有 CRITICAL 级别问题
- 修复所有 HIGH 级别问题
- 尽可能修复 MEDIUM 级别问题

**→ 审查通过后进入提交阶段**

---

## 阶段 5：提交

### 5.1 查看变更
```bash
git status
git diff --staged
```

### 5.2 生成提交信息
- 分析变更内容
- 使用 conventional commits 格式生成提交信息
- 格式：`<type>: <描述>`

### 5.3 执行提交
```bash
git add <相关文件>
git commit -m "<提交信息>"
```

**→ 提交完成，输出总结报告**
