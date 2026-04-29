---
description: 基于 main/master 创建符合飞书需求关联规范的新分支，从自然语言描述中提取信息，需求ID必填
allowed-tools: Bash
argument-hint: <自然语言描述，包含需求ID>
# examples:
#   - /git-branch 新需求: 共享屏幕演讲融合到陪练项目, ID 235
#   - /git-branch 修复登录页面崩溃问题 #233
#   - /git-branch 重构认证模块 需求235
---

# git-branch

从自然语言描述中提取信息，基于 main/master 创建符合飞书需求关联规范的新分支。

## 分支命名规范

格式：`<类型>/<简短英文描述>-<需求ID>`

合法示例：`feat/shared-screen-speaking-235`、`bugfix/fix-login-crash-233`

## 执行逻辑

### 第一步：提取需求ID

从输入中查找纯数字 ID，支持以下常见写法：
- `ID 235`、`#235`、`需求235`、`235` 等

**如果找不到纯数字 ID，立即停止，不做任何 git 操作：**

```
错误：未找到需求ID。请在描述中包含需求ID，例如：
  /git-branch 共享屏幕演讲融合到陪练项目 ID 235
```

### 第二步：判断分支类型

根据描述语义判断类型：

| 关键词 | 类型 |
|--------|------|
| 新需求、新功能、新增、feature、feat | feat |
| 修复、fix、bug、崩溃、异常、报错 | bugfix |
| 紧急、hotfix、线上 | hotfix |
| 重构、refactor、优化结构 | refactor |
| 文档、docs | docs |
| 配置、依赖、chore、杂项 | chore |

无法判断时默认使用 `feat`。

### 第三步：生成简短英文描述

将中文描述转为简短英文 slug：
- 提取核心语义，忽略"新需求:"、"ID 235"等前缀/后缀
- 全部小写，单词间用 `-` 连接
- 控制在 2~4 个单词，保持可读性

示例：`共享屏幕演讲融合到陪练项目` → `shared-screen-speaking`

### 第四步：构造并确认分支名

组合为：`<type>/<slug>-<id>`，**展示给用户确认后再执行**：

```
将创建分支：feat/shared-screen-speaking-235
基于：main

确认？[Y/n]
```

用户输入 `Y`、`y` 或直接回车则继续；输入 `n` 则取消。

### 第五步：确定基础分支

优先 `main`，其次 `master`，两者都不存在则报错退出。

### 第六步：检查分支是否已存在

若已存在：
```
错误：分支 feat/shared-screen-speaking-235 已存在。
```

### 第七步：创建并切换分支

```bash
git switch -c <branch-name> <base-branch>
```

### 第八步：输出结果

```
✓ 已从 main 创建并切换到：feat/shared-screen-speaking-235
```
