---
allowed-tools: Bash(npm run *), Bash(npx *), Bash(git add:*), Bash(git status:*), Bash(git diff:*), Bash(git commit:*), Bash(git push:*), Bash(git log:*), Bash(git fetch:*), Bash(git pull:*), Bash(git branch:*), Bash(git rev-parse:*)
description: 发版流程 - 全量验证后安全提交推送
argument-hint: [提交信息] [--no-push]
---

# /ship - 发版流程

完整的提交流程：全量验证 → 提交代码 → 推送远程。确保只有通过所有验证的代码才能提交。不要把这个任务放到后台执行，我需要在前台实时看到任务进度。

参数：$ARGUMENTS

## 参数说明

- **提交信息**: 可选，如未提供则基于变更内容自动生成
- `--no-push`: 只提交不推送

---

## 阶段 0：项目探测

```bash
# 找到 package.json 所在目录
find . -maxdepth 2 -name "package.json" -not -path "*/node_modules/*"
```

确定 `PKG_DIR`（package.json 所在目录），后续 npm 命令在此执行。

检查可用 scripts：
```bash
cat $PKG_DIR/package.json | grep -A 20 '"scripts"'
```

---

## 阶段 1：全量验证

根据探测到的 scripts，依次执行可用检查。任何失败都立即停止。

### 1.1 类型检查（如果有）
```bash
cd $PKG_DIR && npm run type-check
```

### 1.2 Lint 检查（如果有）
```bash
cd $PKG_DIR && npm run lint
```

### 1.3 构建验证（如果有）
```bash
cd $PKG_DIR && npm run build
```

跳过不存在的 script，但至少执行一个验证。如果全部不存在，直接进入提交阶段。

**→ 所有可用验证通过后继续**

---

## 阶段 2：提交代码

### 2.1 查看变更状态
```bash
git status
git diff --stat
```

### 2.2 查看变更详情
```bash
git diff
git diff --staged
```

### 2.3 暂存策略
- 如果没有已暂存的文件：自动暂存所有修改和新增文件
- 如果已有暂存文件：仅提交已暂存的文件
- 排除不应提交的文件（`.env`、`node_modules` 等）

### 2.4 生成提交信息

分析变更内容，生成 conventional commits 格式的提交信息：

- `feat: 新功能`
- `fix: 错误修复`
- `refactor: 代码重构`
- `style: 样式调整`
- `docs: 文档更新`
- `perf: 性能优化`
- `test: 测试相关`
- `chore: 构建工具/辅助工具变动`

**→ 向用户展示提交信息，等待确认**

### 2.5 执行提交
```bash
git commit -m "<提交信息>"
```

---

## 阶段 3：推送到远程（除非 --no-push）

### 3.1 检查当前分支
```bash
git branch --show-current
```

### 3.2 获取远程状态
```bash
git fetch origin
```

### 3.3 推送
- 首次推送：`git push -u origin <branch-name>`
- 常规推送：`git push`

### 3.4 推送失败处理
- 如果远程有新提交，先 `git pull --rebase` 再推送
- 如果有冲突，中止流程并提示手动解决

---

## 最终输出

1. 验证结果（哪些检查通过 / 跳过）
2. 提交的 commit hash 和信息
3. 推送状态（如果推送了）
4. 当前分支和远程分支状态
