---
allowed-tools: Bash(npm run *), Bash(npx *), Bash(git diff:*), Bash(git status:*), Bash(git log:*), Glob, Grep, Read, Agent
description: 代码审查 - 对当前变更进行全面质量审查
argument-hint: [--fix] [--security-only]
---

# /review - 代码审查

对当前所有代码变更进行全面审查，输出分级问题报告。不要把这个任务放到后台执行，我需要在前台实时看到任务进度。

参数：$ARGUMENTS

## 参数说明

- `--fix`: 自动修复可修复的问题
- `--security-only`: 只执行安全审查

---

## 步骤 0：项目探测

探测项目结构和可用工具：

```bash
# 找到 package.json 所在目录
find . -maxdepth 2 -name "package.json" -not -path "*/node_modules/*"
```

确定 `PKG_DIR`，检查可用的 scripts（type-check、lint、lint:fix 等）。

---

## 步骤 1：收集变更

### 1.1 获取变更范围
```bash
git diff --name-only
git diff --name-only --staged
```

### 1.2 查看变更详情
```bash
git diff
git diff --staged
```

如果没有变更，提示用户并结束。

---

## 步骤 2：代码质量审查

使用 code-reviewer agent 审查所有变更文件，重点检查：

### 2.1 代码规范
- [ ] 注释完整性
- [ ] 组件/函数设计合理性
- [ ] 类型安全（避免 `any`）
- [ ] 命名规范
- [ ] 目录结构

### 2.2 代码质量
- [ ] 函数长度（建议 <50 行）
- [ ] 文件长度（建议 <400 行）
- [ ] 错误处理
- [ ] 性能优化
- [ ] 状态管理

---

## 步骤 3：安全审查

使用 security-reviewer agent 审查安全问题：

- [ ] XSS / 注入漏洞
- [ ] 硬编码密钥
- [ ] 不安全的 API 调用
- [ ] 敏感数据处理

---

## 步骤 4：输出审查报告

### 问题分级标准

| 级别 | 说明 | 处理方式 |
|------|------|---------|
| CRITICAL | 安全漏洞、数据丢失风险 | 必须立即修复 |
| HIGH | 功能缺陷、规范严重违反 | 必须修复 |
| MEDIUM | 代码质量、性能问题 | 建议修复 |
| LOW | 代码风格、优化建议 | 可选修复 |

### 报告格式

```
## 审查报告

### 统计
- 审查文件数: X
- CRITICAL: X 个 | HIGH: X 个 | MEDIUM: X 个 | LOW: X 个

### CRITICAL 问题
1. [文件:行号] 问题描述
   - 原因：...
   - 修复建议：...
```

---

## 步骤 5：自动修复（如果指定 --fix）

对可自动修复的问题进行修复：
- 运行 lint:fix（如果有该 script）
- 修复简单的命名规范问题
- 补充缺失的注释

修复后重新运行验证：
```bash
cd $PKG_DIR && npm run type-check  # 如果存在
cd $PKG_DIR && npm run lint        # 如果存在
```

---

## 最终输出

1. 审查报告摘要
2. 需要手动处理的问题列表
3. 已自动修复的问题列表（如果有 --fix）
4. 后续建议
